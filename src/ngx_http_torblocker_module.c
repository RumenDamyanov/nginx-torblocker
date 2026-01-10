/*
 * nginx-torblocker module
 * Blocks or exclusively allows access from Tor exit nodes
 * Automatically fetches and updates the Tor exit node list from URL (HTTP/HTTPS)
 *
 * Copyright (c) 2025 Rumen Damyanov
 * Licensed under BSD License
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <ngx_event.h>
#include <ngx_event_connect.h>
#include "ngx_http_torblocker_module.h"

/* Default values */
#define NGX_HTTP_TORBLOCKER_DEFAULT_URL      "https://check.torproject.org/torbulkexitlist"
#define NGX_HTTP_TORBLOCKER_DEFAULT_INTERVAL 3600000  /* 1 hour in ms */
#define NGX_HTTP_TORBLOCKER_RESPONSE_SIZE    1048576  /* 1MB max response */

/* Forward declarations */
static ngx_int_t ngx_http_torblocker_init(ngx_conf_t *cf);
static ngx_int_t ngx_http_torblocker_init_process(ngx_cycle_t *cycle);
static void *ngx_http_torblocker_create_main_conf(ngx_conf_t *cf);
static char *ngx_http_torblocker_init_main_conf(ngx_conf_t *cf, void *conf);
static void *ngx_http_torblocker_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_torblocker_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child);
static char *ngx_http_torblocker_set_mode(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);
static ngx_int_t ngx_http_torblocker_handler(ngx_http_request_t *r);
static ngx_int_t ngx_http_torblocker_check_ip(ngx_http_torblocker_main_conf_t *mcf, ngx_str_t *ip);
static void ngx_http_torblocker_update_handler(ngx_event_t *ev);
static ngx_int_t ngx_http_torblocker_parse_list(ngx_http_torblocker_main_conf_t *mcf,
    u_char *data, size_t len, ngx_log_t *log);
static void ngx_http_torblocker_read_handler(ngx_event_t *rev);
static void ngx_http_torblocker_write_handler(ngx_event_t *wev);
static void ngx_http_torblocker_send_request(ngx_http_torblocker_fetch_ctx_t *ctx);
static void ngx_http_torblocker_process_response(ngx_http_torblocker_fetch_ctx_t *ctx);
static void ngx_http_torblocker_close_connection(ngx_http_torblocker_fetch_ctx_t *ctx);
static void ngx_http_torblocker_schedule_retry(ngx_http_torblocker_main_conf_t *mcf);

#if (NGX_HTTP_SSL)
static void ngx_http_torblocker_ssl_handshake_handler(ngx_connection_t *c);
static ngx_int_t ngx_http_torblocker_ssl_init(ngx_http_torblocker_main_conf_t *mcf, ngx_conf_t *cf);
#endif

/* Global reference for process init */
static ngx_http_torblocker_main_conf_t *ngx_http_torblocker_main_conf;

/* Module directives */
static ngx_command_t ngx_http_torblocker_commands[] = {

    { ngx_string("torblock"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_http_torblocker_set_mode,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("torblock_list_url"),
      NGX_HTTP_MAIN_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_str_slot,
      NGX_HTTP_MAIN_CONF_OFFSET,
      offsetof(ngx_http_torblocker_main_conf_t, list_url),
      NULL },

    { ngx_string("torblock_update_interval"),
      NGX_HTTP_MAIN_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_MAIN_CONF_OFFSET,
      offsetof(ngx_http_torblocker_main_conf_t, update_interval),
      NULL },

    ngx_null_command
};

/* Module context */
static ngx_http_module_t ngx_http_torblocker_module_ctx = {
    NULL,                                    /* preconfiguration */
    ngx_http_torblocker_init,                /* postconfiguration */
    ngx_http_torblocker_create_main_conf,    /* create main configuration */
    ngx_http_torblocker_init_main_conf,      /* init main configuration */
    NULL,                                    /* create server configuration */
    NULL,                                    /* merge server configuration */
    ngx_http_torblocker_create_loc_conf,     /* create location configuration */
    ngx_http_torblocker_merge_loc_conf       /* merge location configuration */
};

/* Module definition */
ngx_module_t ngx_http_torblocker_module = {
    NGX_MODULE_V1,
    &ngx_http_torblocker_module_ctx,    /* module context */
    ngx_http_torblocker_commands,       /* module directives */
    NGX_HTTP_MODULE,                    /* module type */
    NULL,                               /* init master */
    NULL,                               /* init module */
    ngx_http_torblocker_init_process,   /* init process */
    NULL,                               /* init thread */
    NULL,                               /* exit thread */
    NULL,                               /* exit process */
    NULL,                               /* exit master */
    NGX_MODULE_V1_PADDING
};

/*
 * Set torblock mode from configuration
 * Supports: off, on, only
 */
static char *
ngx_http_torblocker_set_mode(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_torblocker_loc_conf_t *lcf = conf;
    ngx_str_t                      *value;

    if (lcf->mode != NGX_CONF_UNSET_UINT) {
        return "is duplicate";
    }

    value = cf->args->elts;

    if (ngx_strcasecmp(value[1].data, (u_char *) "off") == 0) {
        lcf->mode = NGX_HTTP_TORBLOCKER_OFF;

    } else if (ngx_strcasecmp(value[1].data, (u_char *) "on") == 0) {
        lcf->mode = NGX_HTTP_TORBLOCKER_ON;

    } else if (ngx_strcasecmp(value[1].data, (u_char *) "only") == 0) {
        lcf->mode = NGX_HTTP_TORBLOCKER_ONLY;

    } else {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "invalid value \"%V\" in \"%V\" directive, "
                           "it must be \"off\", \"on\", or \"only\"",
                           &value[1], &cmd->name);
        return NGX_CONF_ERROR;
    }

    return NGX_CONF_OK;
}

/*
 * Create main configuration
 */
static void *
ngx_http_torblocker_create_main_conf(ngx_conf_t *cf)
{
    ngx_http_torblocker_main_conf_t *mcf;

    mcf = ngx_pcalloc(cf->pool, sizeof(ngx_http_torblocker_main_conf_t));
    if (mcf == NULL) {
        return NULL;
    }

    mcf->update_interval = NGX_CONF_UNSET_MSEC;
    mcf->pool = NULL;
    mcf->last_update = 0;
    mcf->ip_count = 0;
    mcf->initialized = 0;
    mcf->updating = 0;
    mcf->log = cf->log;
#if (NGX_HTTP_SSL)
    mcf->ssl = NULL;
#endif

    return mcf;
}

/*
 * Initialize main configuration
 */
static char *
ngx_http_torblocker_init_main_conf(ngx_conf_t *cf, void *conf)
{
    ngx_http_torblocker_main_conf_t *mcf = conf;

    /* Set defaults */
    if (mcf->list_url.len == 0) {
        ngx_str_set(&mcf->list_url, NGX_HTTP_TORBLOCKER_DEFAULT_URL);
    }

    ngx_conf_init_msec_value(mcf->update_interval, NGX_HTTP_TORBLOCKER_DEFAULT_INTERVAL);

    /* Store global reference for process init */
    ngx_http_torblocker_main_conf = mcf;

#if (NGX_HTTP_SSL)
    /* Initialize SSL context if URL is HTTPS */
    if (ngx_strncasecmp(mcf->list_url.data, (u_char *) "https://", 8) == 0) {
        if (ngx_http_torblocker_ssl_init(mcf, cf) != NGX_OK) {
            return NGX_CONF_ERROR;
        }
    }
#endif

    return NGX_CONF_OK;
}

#if (NGX_HTTP_SSL)
/*
 * Initialize SSL context for HTTPS fetching
 */
static ngx_int_t
ngx_http_torblocker_ssl_init(ngx_http_torblocker_main_conf_t *mcf, ngx_conf_t *cf)
{
    mcf->ssl = ngx_pcalloc(cf->pool, sizeof(ngx_ssl_t));
    if (mcf->ssl == NULL) {
        return NGX_ERROR;
    }

    mcf->ssl->log = cf->log;

    if (ngx_ssl_create(mcf->ssl,
                       NGX_SSL_SSLv2|NGX_SSL_SSLv3|NGX_SSL_TLSv1
                       |NGX_SSL_TLSv1_1|NGX_SSL_TLSv1_2|NGX_SSL_TLSv1_3,
                       NULL) != NGX_OK)
    {
        return NGX_ERROR;
    }

    ngx_log_error(NGX_LOG_INFO, cf->log, 0,
                  "torblocker: SSL context initialized for HTTPS fetching");

    return NGX_OK;
}
#endif

/*
 * Create location configuration
 */
static void *
ngx_http_torblocker_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_torblocker_loc_conf_t *lcf;

    lcf = ngx_pcalloc(cf->pool, sizeof(ngx_http_torblocker_loc_conf_t));
    if (lcf == NULL) {
        return NULL;
    }

    lcf->mode = NGX_CONF_UNSET_UINT;

    return lcf;
}

/*
 * Merge location configuration
 */
static char *
ngx_http_torblocker_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_torblocker_loc_conf_t *prev = parent;
    ngx_http_torblocker_loc_conf_t *conf = child;

    ngx_conf_merge_uint_value(conf->mode, prev->mode, NGX_HTTP_TORBLOCKER_OFF);

    return NGX_CONF_OK;
}

/*
 * Initialize module - register access phase handler
 */
static ngx_int_t
ngx_http_torblocker_init(ngx_conf_t *cf)
{
    ngx_http_handler_pt        *h;
    ngx_http_core_main_conf_t  *cmcf;

    cmcf = ngx_http_conf_get_module_main_conf(cf, ngx_http_core_module);

    /* Register access phase handler */
    h = ngx_array_push(&cmcf->phases[NGX_HTTP_ACCESS_PHASE].handlers);
    if (h == NULL) {
        return NGX_ERROR;
    }

    *h = ngx_http_torblocker_handler;

    return NGX_OK;
}

/*
 * Process initialization - start the update timer
 */
static ngx_int_t
ngx_http_torblocker_init_process(ngx_cycle_t *cycle)
{
    ngx_http_torblocker_main_conf_t *mcf;

    mcf = ngx_http_torblocker_main_conf;
    if (mcf == NULL) {
        return NGX_OK;
    }

    mcf->log = cycle->log;

    /* Initialize the update event */
    ngx_memzero(&mcf->update_event, sizeof(ngx_event_t));
    mcf->update_event.handler = ngx_http_torblocker_update_handler;
    mcf->update_event.data = mcf;
    mcf->update_event.log = cycle->log;

    /* Trigger initial update after 1 second (let nginx fully start) */
    ngx_add_timer(&mcf->update_event, 1000);

    ngx_log_error(NGX_LOG_NOTICE, cycle->log, 0,
                  "torblocker: initialized, will fetch list from \"%V\"",
                  &mcf->list_url);

    return NGX_OK;
}

/*
 * Parse an IP address line from the Tor exit list
 */
static ngx_int_t
ngx_http_torblocker_parse_ip_line(u_char *line, ngx_uint_t len, ngx_str_t *ip)
{
    u_char *p, *end;
    ngx_uint_t dots, digits;

    if (len == 0 || len > 15) {
        return 0;
    }

    p = line;
    end = line + len;

    while (p < end && (*p == ' ' || *p == '\t')) {
        p++;
    }

    if (p >= end || *p == '#' || *p == '\n' || *p == '\r') {
        return 0;
    }

    ip->data = p;
    dots = 0;
    digits = 0;

    while (p < end && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') {
        if (*p == '.') {
            dots++;
            digits = 0;
        } else if (*p >= '0' && *p <= '9') {
            digits++;
            if (digits > 3) {
                return 0;
            }
        } else {
            return 0;
        }
        p++;
    }

    ip->len = p - ip->data;

    if (dots != 3 || ip->len < 7) {
        return 0;
    }

    return 1;
}

/*
 * Parse the Tor exit list and build hash table
 */
static ngx_int_t
ngx_http_torblocker_parse_list(ngx_http_torblocker_main_conf_t *mcf,
    u_char *data, size_t len, ngx_log_t *log)
{
    u_char              *p, *end, *line_start;
    ngx_pool_t          *pool;
    ngx_hash_init_t      hash_init;
    ngx_hash_key_t      *hk;
    ngx_array_t         *keys;
    ngx_str_t            ip;
    ngx_uint_t           count;
    static ngx_uint_t    marker = 1;

    pool = ngx_create_pool(NGX_DEFAULT_POOL_SIZE, log);
    if (pool == NULL) {
        return NGX_ERROR;
    }

    keys = ngx_array_create(pool, 2048, sizeof(ngx_hash_key_t));
    if (keys == NULL) {
        ngx_destroy_pool(pool);
        return NGX_ERROR;
    }

    p = data;
    end = data + len;
    count = 0;

    while (p < end) {
        line_start = p;

        while (p < end && *p != '\n') {
            p++;
        }

        if (ngx_http_torblocker_parse_ip_line(line_start, p - line_start, &ip)) {
            hk = ngx_array_push(keys);
            if (hk == NULL) {
                ngx_destroy_pool(pool);
                return NGX_ERROR;
            }

            hk->key.data = ngx_pstrdup(pool, &ip);
            if (hk->key.data == NULL) {
                ngx_destroy_pool(pool);
                return NGX_ERROR;
            }
            hk->key.len = ip.len;
            hk->key_hash = ngx_hash_key_lc(hk->key.data, hk->key.len);
            hk->value = &marker;

            count++;
        }

        if (p < end) {
            p++;
        }
    }

    if (count == 0) {
        ngx_log_error(NGX_LOG_WARN, log, 0,
                      "torblocker: no valid IPs found in response");
        ngx_destroy_pool(pool);
        return NGX_OK;
    }

    hash_init.hash = &mcf->ip_hash;
    hash_init.key = ngx_hash_key_lc;
    hash_init.max_size = 10000;
    hash_init.bucket_size = ngx_align(64, ngx_cacheline_size);
    hash_init.name = "torblocker_ip_hash";
    hash_init.pool = pool;
    hash_init.temp_pool = pool;

    if (ngx_hash_init(&hash_init, keys->elts, keys->nelts) != NGX_OK) {
        ngx_log_error(NGX_LOG_ERR, log, 0,
                      "torblocker: failed to initialize IP hash");
        ngx_destroy_pool(pool);
        return NGX_ERROR;
    }

    if (mcf->pool != NULL) {
        ngx_destroy_pool(mcf->pool);
    }

    mcf->pool = pool;
    mcf->ip_count = count;
    mcf->last_update = ngx_time();
    mcf->initialized = 1;

    ngx_log_error(NGX_LOG_NOTICE, log, 0,
                  "torblocker: loaded %ui Tor exit nodes",
                  count);

    return NGX_OK;
}

/*
 * Close connection and cleanup
 */
static void
ngx_http_torblocker_close_connection(ngx_http_torblocker_fetch_ctx_t *ctx)
{
    if (ctx->peer.connection) {
#if (NGX_HTTP_SSL)
        if (ctx->peer.connection->ssl) {
            ngx_ssl_shutdown(ctx->peer.connection);
        }
#endif
        ngx_close_connection(ctx->peer.connection);
    }

    ctx->mcf->updating = 0;
    ngx_destroy_pool(ctx->pool);
}

/*
 * Schedule retry after interval
 */
static void
ngx_http_torblocker_schedule_retry(ngx_http_torblocker_main_conf_t *mcf)
{
    if (mcf->update_interval > 0) {
        ngx_add_timer(&mcf->update_event, mcf->update_interval);
    }
}

/*
 * Process the HTTP response
 */
static void
ngx_http_torblocker_process_response(ngx_http_torblocker_fetch_ctx_t *ctx)
{
    u_char *p, *body;
    size_t body_len;

    /* Find body (after \r\n\r\n) */
    body = NULL;
    for (p = ctx->response->pos; p < ctx->response->last - 3; p++) {
        if (p[0] == '\r' && p[1] == '\n' && p[2] == '\r' && p[3] == '\n') {
            body = p + 4;
            break;
        }
    }

    if (body == NULL) {
        ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                      "torblocker: invalid HTTP response (no body found)");
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
        return;
    }

    body_len = ctx->response->last - body;

    /* Check for HTTP 200 OK */
    if (ngx_strncmp(ctx->response->pos, "HTTP/1.1 200", 12) != 0 &&
        ngx_strncmp(ctx->response->pos, "HTTP/1.0 200", 12) != 0) {
        ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                      "torblocker: HTTP request failed (non-200 response)");
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
        return;
    }

    if (ngx_http_torblocker_parse_list(ctx->mcf, body, body_len, ctx->mcf->log) != NGX_OK) {
        ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                      "torblocker: failed to parse Tor exit list");
    }

    ngx_http_torblocker_close_connection(ctx);
    ngx_http_torblocker_schedule_retry(ctx->mcf);
}

/*
 * Read handler
 */
static void
ngx_http_torblocker_read_handler(ngx_event_t *rev)
{
    ngx_http_torblocker_fetch_ctx_t *ctx;
    ngx_connection_t                *c;
    ssize_t                          n;

    c = rev->data;
    ctx = c->data;

#if (NGX_HTTP_SSL)
    if (ctx->ssl && c->ssl) {
        n = ngx_ssl_recv(c, ctx->response->last,
                         ctx->response->end - ctx->response->last);
    } else {
        n = ngx_recv(c, ctx->response->last,
                     ctx->response->end - ctx->response->last);
    }
#else
    n = ngx_recv(c, ctx->response->last,
                 ctx->response->end - ctx->response->last);
#endif

    if (n == NGX_AGAIN) {
        if (ngx_handle_read_event(rev, 0) != NGX_OK) {
            ngx_http_torblocker_close_connection(ctx);
            ngx_http_torblocker_schedule_retry(ctx->mcf);
        }
        return;
    }

    if (n == NGX_ERROR || n == 0) {
        /* Connection closed - process what we have */
        ngx_http_torblocker_process_response(ctx);
        return;
    }

    ctx->response->last += n;

    if (ctx->response->last >= ctx->response->end) {
        ngx_http_torblocker_process_response(ctx);
        return;
    }

    if (ngx_handle_read_event(rev, 0) != NGX_OK) {
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
    }
}

/*
 * Send HTTP request
 */
static void
ngx_http_torblocker_send_request(ngx_http_torblocker_fetch_ctx_t *ctx)
{
    ngx_connection_t *c;
    ssize_t           n;

    c = ctx->peer.connection;

#if (NGX_HTTP_SSL)
    if (ctx->ssl && c->ssl) {
        n = ngx_ssl_send(c, ctx->request->pos,
                         ctx->request->last - ctx->request->pos);
    } else {
        n = ngx_send(c, ctx->request->pos,
                     ctx->request->last - ctx->request->pos);
    }
#else
    n = ngx_send(c, ctx->request->pos,
                 ctx->request->last - ctx->request->pos);
#endif

    if (n == NGX_ERROR) {
        ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                      "torblocker: failed to send HTTP request");
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
        return;
    }

    if (n == NGX_AGAIN) {
        if (ngx_handle_write_event(c->write, 0) != NGX_OK) {
            ngx_http_torblocker_close_connection(ctx);
            ngx_http_torblocker_schedule_retry(ctx->mcf);
        }
        return;
    }

    ctx->request->pos += n;

    if (ctx->request->pos < ctx->request->last) {
        if (ngx_handle_write_event(c->write, 0) != NGX_OK) {
            ngx_http_torblocker_close_connection(ctx);
            ngx_http_torblocker_schedule_retry(ctx->mcf);
        }
        return;
    }

    /* Request sent, wait for response */
    c->read->handler = ngx_http_torblocker_read_handler;

    if (ngx_handle_read_event(c->read, 0) != NGX_OK) {
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
    }
}

/*
 * Write handler
 */
static void
ngx_http_torblocker_write_handler(ngx_event_t *wev)
{
    ngx_http_torblocker_fetch_ctx_t *ctx;
    ngx_connection_t                *c;

    c = wev->data;
    ctx = c->data;

    ngx_http_torblocker_send_request(ctx);
}

#if (NGX_HTTP_SSL)
/*
 * SSL handshake handler
 */
static void
ngx_http_torblocker_ssl_handshake_handler(ngx_connection_t *c)
{
    ngx_http_torblocker_fetch_ctx_t *ctx;

    ctx = c->data;

    if (c->ssl->handshaked) {
        ngx_log_error(NGX_LOG_INFO, ctx->mcf->log, 0,
                      "torblocker: SSL handshake completed");

        ctx->ssl_handshake_done = 1;

        c->read->handler = ngx_http_torblocker_read_handler;
        c->write->handler = ngx_http_torblocker_write_handler;

        /* Send the HTTP request */
        ngx_http_torblocker_send_request(ctx);
        return;
    }

    ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                  "torblocker: SSL handshake failed");

    ngx_http_torblocker_close_connection(ctx);
    ngx_http_torblocker_schedule_retry(ctx->mcf);
}
#endif

/*
 * Connection established handler
 */
static void
ngx_http_torblocker_connect_handler(ngx_event_t *wev)
{
    ngx_http_torblocker_fetch_ctx_t *ctx;
    ngx_connection_t                *c;
    int                              err;
    socklen_t                        len;
#if (NGX_HTTP_SSL)
    ngx_int_t                        rc;
#endif

    c = wev->data;
    ctx = c->data;

    err = 0;
    len = sizeof(int);

    if (getsockopt(c->fd, SOL_SOCKET, SO_ERROR, (void *) &err, &len) == -1) {
        err = ngx_socket_errno;
    }

    if (err) {
        ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, err,
                      "torblocker: connect() failed");
        ngx_http_torblocker_close_connection(ctx);
        ngx_http_torblocker_schedule_retry(ctx->mcf);
        return;
    }

    ngx_log_error(NGX_LOG_INFO, ctx->mcf->log, 0,
                  "torblocker: connected to %V:%d",
                  &ctx->host, ctx->port);

#if (NGX_HTTP_SSL)
    if (ctx->ssl && ctx->mcf->ssl) {
        /* Start SSL handshake */
        rc = ngx_ssl_create_connection(ctx->mcf->ssl, c,
                                       NGX_SSL_BUFFER|NGX_SSL_CLIENT);
        if (rc != NGX_OK) {
            ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                          "torblocker: SSL connection creation failed");
            ngx_http_torblocker_close_connection(ctx);
            ngx_http_torblocker_schedule_retry(ctx->mcf);
            return;
        }

        /* Set SNI hostname */
        if (ngx_ssl_set_session(c, NULL) != NGX_OK) {
            ngx_log_error(NGX_LOG_WARN, ctx->mcf->log, 0,
                          "torblocker: failed to set SSL session");
        }

#ifdef SSL_set_tlsext_host_name
        SSL_set_tlsext_host_name(c->ssl->connection, (char *) ctx->host.data);
#endif

        c->sendfile = 0;

        rc = ngx_ssl_handshake(c);

        if (rc == NGX_AGAIN) {
            c->ssl->handler = ngx_http_torblocker_ssl_handshake_handler;
            return;
        }

        if (rc == NGX_ERROR) {
            ngx_log_error(NGX_LOG_ERR, ctx->mcf->log, 0,
                          "torblocker: SSL handshake failed");
            ngx_http_torblocker_close_connection(ctx);
            ngx_http_torblocker_schedule_retry(ctx->mcf);
            return;
        }

        /* Handshake completed immediately */
        ctx->ssl_handshake_done = 1;
    }
#endif

    /* Send HTTP request */
    c->write->handler = ngx_http_torblocker_write_handler;
    ngx_http_torblocker_send_request(ctx);
}

/*
 * DNS resolve handler
 */
static void
ngx_http_torblocker_resolve_handler(ngx_resolver_ctx_t *rctx)
{
    ngx_http_torblocker_fetch_ctx_t *ctx;
    ngx_http_torblocker_main_conf_t *mcf;
    ngx_connection_t                *c;
    ngx_int_t                        rc;
    struct sockaddr_in              *sin;
    u_char                          *p;

    ctx = rctx->data;
    mcf = ctx->mcf;

    if (rctx->state) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: DNS resolve failed for \"%V\": %s",
                      &ctx->host, ngx_resolver_strerror(rctx->state));
        mcf->updating = 0;
        ngx_resolve_name_done(rctx);
        ngx_destroy_pool(ctx->pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    ngx_log_error(NGX_LOG_INFO, mcf->log, 0,
                  "torblocker: resolved %V to %ud.%ud.%ud.%ud",
                  &ctx->host,
                  (rctx->addrs[0] >> 0) & 0xff,
                  (rctx->addrs[0] >> 8) & 0xff,
                  (rctx->addrs[0] >> 16) & 0xff,
                  (rctx->addrs[0] >> 24) & 0xff);

    /* Set up peer connection */
    ctx->peer.sockaddr = ngx_pcalloc(ctx->pool, sizeof(struct sockaddr_in));
    if (ctx->peer.sockaddr == NULL) {
        mcf->updating = 0;
        ngx_resolve_name_done(rctx);
        ngx_destroy_pool(ctx->pool);
        return;
    }

    sin = (struct sockaddr_in *) ctx->peer.sockaddr;
    sin->sin_family = AF_INET;
    sin->sin_port = htons(ctx->port);
    sin->sin_addr.s_addr = rctx->addrs[0];

    ctx->peer.socklen = sizeof(struct sockaddr_in);
    ctx->peer.name = &ctx->host;
    ctx->peer.get = ngx_event_get_peer;
    ctx->peer.log = mcf->log;
    ctx->peer.log_error = NGX_ERROR_ERR;

    ngx_resolve_name_done(rctx);

    /* Build HTTP request */
    ctx->request = ngx_create_temp_buf(ctx->pool, 1024);
    if (ctx->request == NULL) {
        mcf->updating = 0;
        ngx_destroy_pool(ctx->pool);
        return;
    }

    p = ctx->request->last;
    p = ngx_sprintf(p, "GET %V HTTP/1.1\r\n", &ctx->uri);
    p = ngx_sprintf(p, "Host: %V\r\n", &ctx->host);
    p = ngx_sprintf(p, "User-Agent: nginx-torblocker/2.1\r\n");
    p = ngx_sprintf(p, "Accept: */*\r\n");
    p = ngx_sprintf(p, "Connection: close\r\n");
    p = ngx_sprintf(p, "\r\n");
    ctx->request->last = p;

    /* Allocate response buffer */
    ctx->response = ngx_create_temp_buf(ctx->pool, NGX_HTTP_TORBLOCKER_RESPONSE_SIZE);
    if (ctx->response == NULL) {
        mcf->updating = 0;
        ngx_destroy_pool(ctx->pool);
        return;
    }

    /* Connect to server */
    rc = ngx_event_connect_peer(&ctx->peer);

    if (rc == NGX_ERROR || rc == NGX_DECLINED) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: connect failed");
        mcf->updating = 0;
        ngx_destroy_pool(ctx->pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    c = ctx->peer.connection;
    c->data = ctx;
    c->read->handler = ngx_http_torblocker_read_handler;
    c->write->handler = ngx_http_torblocker_connect_handler;

    if (rc == NGX_OK) {
        ngx_http_torblocker_connect_handler(c->write);
        return;
    }

    if (ngx_handle_write_event(c->write, 0) != NGX_OK) {
        mcf->updating = 0;
        ngx_close_connection(c);
        ngx_destroy_pool(ctx->pool);
    }
}

/*
 * Timer handler for list updates
 */
static void
ngx_http_torblocker_update_handler(ngx_event_t *ev)
{
    ngx_http_torblocker_main_conf_t *mcf;
    ngx_http_torblocker_fetch_ctx_t *ctx;
    ngx_pool_t                      *pool;
    ngx_resolver_ctx_t              *rctx;
    ngx_http_core_loc_conf_t        *clcf;
    ngx_http_core_main_conf_t       *cmcf;
    u_char                          *p, *host_start, *uri_start;
    size_t                           len;

    mcf = ev->data;

    if (mcf->updating) {
        ngx_log_error(NGX_LOG_WARN, mcf->log, 0,
                      "torblocker: update already in progress, skipping");
        return;
    }

    ngx_log_error(NGX_LOG_INFO, mcf->log, 0,
                  "torblocker: fetching Tor exit list from \"%V\"",
                  &mcf->list_url);

    mcf->updating = 1;

    pool = ngx_create_pool(4096, mcf->log);
    if (pool == NULL) {
        mcf->updating = 0;
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    ctx = ngx_pcalloc(pool, sizeof(ngx_http_torblocker_fetch_ctx_t));
    if (ctx == NULL) {
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    ctx->mcf = mcf;
    ctx->pool = pool;

    /* Parse URL */
    p = mcf->list_url.data;
    len = mcf->list_url.len;

    if (ngx_strncasecmp(p, (u_char *) "https://", 8) == 0) {
        ctx->ssl = 1;
        ctx->port = 443;
        p += 8;
        len -= 8;
    } else if (ngx_strncasecmp(p, (u_char *) "http://", 7) == 0) {
        ctx->ssl = 0;
        ctx->port = 80;
        p += 7;
        len -= 7;
    } else {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: invalid URL scheme in \"%V\"",
                      &mcf->list_url);
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        return;
    }

#if !(NGX_HTTP_SSL)
    if (ctx->ssl) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: HTTPS requires nginx with SSL support. "
                      "Use HTTP URL or rebuild nginx with --with-http_ssl_module");
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        return;
    }
#endif

    /* Extract host */
    host_start = p;
    while (len > 0 && *p != '/' && *p != ':') {
        p++;
        len--;
    }

    ctx->host.len = p - host_start;
    ctx->host.data = ngx_pnalloc(pool, ctx->host.len + 1);
    if (ctx->host.data == NULL) {
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        return;
    }
    ngx_memcpy(ctx->host.data, host_start, ctx->host.len);
    ctx->host.data[ctx->host.len] = '\0';

    /* Extract URI */
    if (len > 0 && *p == '/') {
        uri_start = p;
        ctx->uri.data = ngx_pnalloc(pool, len + 1);
        if (ctx->uri.data == NULL) {
            mcf->updating = 0;
            ngx_destroy_pool(pool);
            return;
        }
        ngx_memcpy(ctx->uri.data, uri_start, len);
        ctx->uri.len = len;
        ctx->uri.data[len] = '\0';
    } else {
        ngx_str_set(&ctx->uri, "/");
    }

    if (ctx->host.len == 0) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: no host in URL \"%V\"",
                      &mcf->list_url);
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        return;
    }

    /* Get resolver */
    cmcf = ngx_http_cycle_get_module_main_conf(ngx_cycle, ngx_http_core_module);
    if (cmcf == NULL) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: cannot get http core main conf");
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    clcf = cmcf->phase_engine.handlers->conf;
    if (clcf == NULL || clcf->resolver == NULL) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: no resolver configured. "
                      "Add 'resolver 1.1.1.1;' or 'resolver 127.0.0.53;' to http block");
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    rctx = ngx_resolve_start(clcf->resolver, NULL);
    if (rctx == NULL) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: failed to start DNS resolve");
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    if (rctx == NGX_NO_RESOLVER) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: no resolver defined. "
                      "Add 'resolver 1.1.1.1;' or 'resolver 127.0.0.53;' to http block");
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }

    rctx->name = ctx->host;
    rctx->handler = ngx_http_torblocker_resolve_handler;
    rctx->data = ctx;
    rctx->timeout = 10000;

    if (ngx_resolve_name(rctx) != NGX_OK) {
        ngx_log_error(NGX_LOG_ERR, mcf->log, 0,
                      "torblocker: failed to resolve \"%V\"",
                      &ctx->host);
        mcf->updating = 0;
        ngx_destroy_pool(pool);
        ngx_http_torblocker_schedule_retry(mcf);
        return;
    }
}

/*
 * Check if an IP is in the Tor exit node list
 */
static ngx_int_t
ngx_http_torblocker_check_ip(ngx_http_torblocker_main_conf_t *mcf, ngx_str_t *ip)
{
    void *value;

    if (!mcf->initialized || mcf->ip_count == 0) {
        return 0;
    }

    value = ngx_hash_find(&mcf->ip_hash,
                          ngx_hash_key_lc(ip->data, ip->len),
                          ip->data, ip->len);

    return (value != NULL) ? 1 : 0;
}

/*
 * Access phase handler
 *
 * Mode behaviors:
 *   - OFF:  Allow all traffic (no blocking)
 *   - ON:   Block Tor exit nodes
 *   - ONLY: Allow ONLY Tor exit nodes (block clearnet)
 */
static ngx_int_t
ngx_http_torblocker_handler(ngx_http_request_t *r)
{
    ngx_http_torblocker_loc_conf_t  *lcf;
    ngx_http_torblocker_main_conf_t *mcf;
    ngx_str_t                        ip;
    struct sockaddr_in              *sin;
#if (NGX_HAVE_INET6)
    struct sockaddr_in6             *sin6;
#endif
    u_char                           addr[NGX_INET6_ADDRSTRLEN];
    ngx_int_t                        is_tor;

    lcf = ngx_http_get_module_loc_conf(r, ngx_http_torblocker_module);

    /* If mode is OFF, allow all traffic */
    if (lcf->mode == NGX_HTTP_TORBLOCKER_OFF) {
        return NGX_DECLINED;
    }

    mcf = ngx_http_get_module_main_conf(r, ngx_http_torblocker_module);

    /* Get client IP address */
    switch (r->connection->sockaddr->sa_family) {
    case AF_INET:
        sin = (struct sockaddr_in *) r->connection->sockaddr;
        ip.data = addr;
        ip.len = ngx_inet_ntop(AF_INET, &sin->sin_addr, addr, NGX_INET_ADDRSTRLEN);
        break;

#if (NGX_HAVE_INET6)
    case AF_INET6:
        sin6 = (struct sockaddr_in6 *) r->connection->sockaddr;

        if (IN6_IS_ADDR_V4MAPPED(&sin6->sin6_addr)) {
            ip.data = addr;
            ip.len = ngx_inet_ntop(AF_INET,
                                   &sin6->sin6_addr.s6_addr[12],
                                   addr, NGX_INET_ADDRSTRLEN);
        } else {
            /* Pure IPv6 - not in Tor exit list (IPv4 only) */
            if (lcf->mode == NGX_HTTP_TORBLOCKER_ONLY) {
                /* In "only" mode, block non-Tor (IPv6) traffic */
                ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                              "torblocker: blocking non-Tor IPv6 client (mode=only)");
                return NGX_HTTP_FORBIDDEN;
            }
            return NGX_DECLINED;
        }
        break;
#endif

    default:
        /* Unknown address family */
        if (lcf->mode == NGX_HTTP_TORBLOCKER_ONLY) {
            return NGX_HTTP_FORBIDDEN;
        }
        return NGX_DECLINED;
    }

    /* Check if the IP is a Tor exit node */
    is_tor = ngx_http_torblocker_check_ip(mcf, &ip);

    switch (lcf->mode) {
    case NGX_HTTP_TORBLOCKER_ON:
        /* Block Tor traffic */
        if (is_tor) {
            ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                          "torblocker: blocking Tor exit node %V", &ip);
            return NGX_HTTP_FORBIDDEN;
        }
        break;

    case NGX_HTTP_TORBLOCKER_ONLY:
        /* Allow ONLY Tor traffic (block clearnet) */
        if (!is_tor) {
            /*
             * Note: If list is not initialized yet, we fail-open
             * (allow traffic) to avoid blocking legitimate users
             * during startup/list refresh failures.
             */
            if (mcf->initialized && mcf->ip_count > 0) {
                ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                              "torblocker: blocking non-Tor client %V (mode=only)", &ip);
                return NGX_HTTP_FORBIDDEN;
            }
        }
        break;

    default:
        /* OFF or unknown - allow */
        break;
    }

    return NGX_DECLINED;
}
