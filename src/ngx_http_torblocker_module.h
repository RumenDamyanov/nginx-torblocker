#ifndef _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_
#define _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

typedef struct {
    ngx_str_t   url;
    ngx_msec_t  update_interval;
    ngx_flag_t  enabled;
    ngx_pool_t *pool;      /* Add pool reference */
} ngx_http_torblocker_conf_t;

extern ngx_module_t ngx_http_torblocker_module;

#endif /* _NGX_HTTP_TORBLOCKER_MODULE_H_INCLUDED_ */
