#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ngx_http_torblocker_module.h"

static void *ngx_http_torblocker_create_conf(ngx_conf_t *cf);
static char *ngx_http_torblocker_merge_conf(ngx_conf_t *cf, void *parent, void *child);

// Add cleanup handler
static void
ngx_http_torblocker_cleanup(void *data)
{
    ngx_http_torblocker_conf_t *conf;

    conf = (ngx_http_torblocker_conf_t *)data;
    if (conf == NULL) {
        return;
    }

    // Cleanup resources
    if (conf->url.data != NULL) {
        ngx_pfree(conf->pool, conf->url.data);
        conf->url.data = NULL;
        conf->url.len = 0;
    }
}

static ngx_command_t ngx_http_torblocker_commands[] = {
    { ngx_string("torblock"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
      ngx_conf_set_flag_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_torblocker_conf_t, enabled),
      NULL },

    { ngx_string("torblock_list_url"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_str_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_torblocker_conf_t, url),
      NULL },

    { ngx_string("torblock_update_interval"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_torblocker_conf_t, update_interval),
      NULL },

    ngx_null_command
};

static ngx_http_module_t ngx_http_torblocker_module_ctx = {
    NULL,                                  /* preconfiguration */
    NULL,                                  /* postconfiguration */
    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */
    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */
    ngx_http_torblocker_create_conf,       /* create location configuration */
    ngx_http_torblocker_merge_conf         /* merge location configuration */
};

ngx_module_t ngx_http_torblocker_module = {
    NGX_MODULE_V1,
    &ngx_http_torblocker_module_ctx,      /* module context */
    ngx_http_torblocker_commands,         /* module directives */
    NGX_HTTP_MODULE,                      /* module type */
    NULL,                                 /* init master */
    NULL,                                 /* init module */
    NULL,                                 /* init process */
    NULL,                                 /* init thread */
    NULL,                                 /* exit thread */
    NULL,                                 /* exit process */
    NULL,                                 /* exit master */
    NGX_MODULE_V1_PADDING
};

static void *ngx_http_torblocker_create_conf(ngx_conf_t *cf) {
    ngx_http_torblocker_conf_t *conf;
    ngx_pool_cleanup_t *cln;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_torblocker_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    // Register cleanup handler
    cln = ngx_pool_cleanup_add(cf->pool, 0);
    if (cln == NULL) {
        return NULL;
    }
    cln->handler = ngx_http_torblocker_cleanup;
    cln->data = conf;

    conf->pool = cf->pool;
    conf->update_interval = NGX_CONF_UNSET_MSEC;
    conf->enabled = NGX_CONF_UNSET;

    return conf;
}

/* Function to get server's IP address */
static ngx_str_t get_server_ip(ngx_pool_t *pool) {
    struct ifaddrs *ifaddr, *ifa;
    int family;
    char host[NI_MAXHOST];

    if (getifaddrs(&ifaddr) == -1) {
        ngx_str_t empty = ngx_string("");
        return empty;
    }

    ngx_str_t server_ip = ngx_null_string;

    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) continue;

        family = ifa->ifa_addr->sa_family;
        if (family == AF_INET) { // IPv4 only
            getnameinfo(ifa->ifa_addr, sizeof(struct sockaddr_in), host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);

            server_ip.len = ngx_strlen(host);
            server_ip.data = ngx_pnalloc(pool, server_ip.len);
            ngx_memcpy(server_ip.data, host, server_ip.len);

            break; // Use first IPv4 address found
        }
    }

    freeifaddrs(ifaddr);
    return server_ip;
}

/* Merge function to apply defaults */
static char *ngx_http_torblocker_merge_conf(ngx_conf_t *cf, void *parent, void *child) {
    ngx_http_torblocker_conf_t *prev = parent;
    ngx_http_torblocker_conf_t *conf = child;

    ngx_conf_merge_msec_value(conf->update_interval, prev->update_interval, 3600000); // Default: 1 hour
    ngx_conf_merge_value(conf->enabled, prev->enabled, 1); // Default: enabled

    if (conf->url.len == 0) {
        ngx_str_t server_ip = get_server_ip(cf->pool);
        if (server_ip.len > 0) {
            u_char *default_url = ngx_pnalloc(cf->pool, sizeof("https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=") + server_ip.len);
            ngx_sprintf(default_url, "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=%V", &server_ip);
            conf->url.len = ngx_strlen(default_url);
            conf->url.data = default_url;
        }
    }

    return NGX_CONF_OK;
}
