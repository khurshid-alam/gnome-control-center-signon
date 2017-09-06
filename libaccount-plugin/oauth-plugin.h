/* vi: set et sw=4 ts=4 cino=t0,(0: */
/* -*- Mode: C; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * This file is part of libaccount-plugin
 *
 * Copyright (C) 2012 Canonical Ltd.
 *
 * Contact: Alberto Mardegan <alberto.mardegan@canonical.com>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License version 3, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _AP_OAUTH_PLUGIN_H_
#define _AP_OAUTH_PLUGIN_H_

#include <libaccount-plugin/plugin.h>

G_BEGIN_DECLS

#define AP_TYPE_OAUTH_PLUGIN             (ap_oauth_plugin_get_type ())
#define AP_OAUTH_PLUGIN(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), AP_TYPE_OAUTH_PLUGIN, ApOAuthPlugin))
#define AP_OAUTH_PLUGIN_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), AP_TYPE_OAUTH_PLUGIN, ApOAuthPluginClass))
#define AP_IS_OAUTH_PLUGIN(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), AP_TYPE_OAUTH_PLUGIN))
#define AP_IS_OAUTH_PLUGIN_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), AP_TYPE_OAUTH_PLUGIN))
#define AP_OAUTH_PLUGIN_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), AP_TYPE_OAUTH_PLUGIN, ApOAuthPluginClass))

typedef struct _ApOAuthPluginClass ApOAuthPluginClass;
typedef struct _ApOAuthPluginPrivate ApOAuthPluginPrivate;
typedef struct _ApOAuthPlugin ApOAuthPlugin;

/**
 * ApOAuthPluginClass:
 *
 * Base class for account plugins.
 */
struct _ApOAuthPluginClass
{
    ApPluginClass parent_class;
    void (*query_username) (ApOAuthPlugin *self);
    void (*_ap_reserved2) (void);
    void (*_ap_reserved3) (void);
    void (*_ap_reserved4) (void);
    void (*_ap_reserved5) (void);
    void (*_ap_reserved6) (void);
    void (*_ap_reserved7) (void);
};

/**
 * ApOAuthPlugin:
 *
 * Use the accessor functions below.
 */
struct _ApOAuthPlugin
{
    ApPlugin parent_instance;

    /*< private >*/
    ApOAuthPluginPrivate *priv;
};

GType ap_oauth_plugin_get_type (void) G_GNUC_CONST;

void ap_oauth_plugin_set_oauth_parameters (ApOAuthPlugin *self,
                                           GHashTable *oauth_params);
void ap_oauth_plugin_set_account_oauth_parameters (ApOAuthPlugin *self,
                                                   GHashTable *oauth_params);
GVariant *ap_oauth_plugin_get_oauth_reply (ApOAuthPlugin *self);
void ap_oauth_plugin_store_account (ApOAuthPlugin *self);

/**
 * ApOAuthMechanism:
 * @AP_OAUTH_MECHANISM_USER_AGENT: OAuth 2.0, user-agent flow (default)
 * @AP_OAUTH_MECHANISM_WEB_SERVER: OAuth 2.0, web-server flow
 * @AP_OAUTH_MECHANISM_HMAC_SHA1: OAuth 1.0a, signing type: HMAC-SHA1
 * @AP_OAUTH_MECHANISM_PLAINTEXT: OAuth 1.0a, signing type: PLAINTEXT
 * @AP_OAUTH_MECHANISM_RSA_SHA1: OAuth 1.0a, signing type: RSA-SHA1
 *
 * The authentication mechanism to be used.
 */
typedef enum {
    AP_OAUTH_MECHANISM_USER_AGENT = 0,
    AP_OAUTH_MECHANISM_WEB_SERVER,
    AP_OAUTH_MECHANISM_HMAC_SHA1,
    AP_OAUTH_MECHANISM_PLAINTEXT,
    AP_OAUTH_MECHANISM_RSA_SHA1,
    /*< private >*/
    AP_OAUTH_MECHANISM_LAST
} ApOAuthMechanism;

void ap_oauth_plugin_set_mechanism (ApOAuthPlugin *self,
                                    ApOAuthMechanism mechanism);

G_END_DECLS

#endif /* _AP_OAUTH_PLUGIN_H_ */
