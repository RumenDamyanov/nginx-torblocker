#ifndef _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_
#define _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#if (NGX_HTTP_SSL)
#include <ngx_event_openssl.h>
#endif

/* Torblock mode values */
#define NGX_HTTP_TORBLOCKER_OFF   0  /* Allow all traffic (default) */
#define NGX_HTTP_TORBLOCKER_ON    1  /* Block Tor traffic */
#define NGX_HTTP_TORBLOCKER_ONLY  2  /* Allow ONLY Tor traffic (block clearnet) */

/* Module configuration structure */
typedef struct {
    ngx_uint_t   mode;              /* Blocking mode (off/on/only) */
} ngx_http_torblocker_loc_conf_t;

/* Main configuration for shared state */
typedef struct {
    ngx_array_t        *ip_list;        /* Array of blocked IP strings */
    ngx_hash_t          ip_hash;        /* Hash table of blocked IPs */
    ngx_pool_t         *pool;           /* Memory pool for hash */
    ngx_str_t           list_url;       /* URL to fetch Tor exit list */
    ngx_msec_t          update_interval;/* Update interval */
    time_t              last_update;    /* Last time list was updated */
    ngx_uint_t          ip_count;       /* Number of IPs loaded */
    ngx_event_t         update_event;   /* Timer event for updates */
    ngx_log_t          *log;            /* Log for events */
    ngx_resolver_t     *resolver;       /* DNS resolver reference */
    unsigned            initialized:1;  /* Whether hash is initialized */
    unsigned            updating:1;     /* Whether update is in progress */
#if (NGX_HTTP_SSL)
    ngx_ssl_t          *ssl;            /* SSL context for HTTPS */
#endif
} ngx_http_torblocker_main_conf_t;

/* Connection context for HTTP fetch */
typedef struct {
    ngx_http_torblocker_main_conf_t *mcf;
    ngx_pool_t                      *pool;
    ngx_peer_connection_t            peer;
    ngx_buf_t                       *request;
    ngx_buf_t                       *response;
    ngx_str_t                        host;
    ngx_str_t                        uri;
    in_port_t                        port;
    unsigned                         ssl:1;
    unsigned                         ssl_handshake_done:1;
#if (NGX_HTTP_SSL)
    ngx_ssl_connection_t            *ssl_conn;
#endif
} ngx_http_torblocker_fetch_ctx_t;

/* Exported module */
extern ngx_module_t ngx_http_torblocker_module;

#endif /* _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_ */
