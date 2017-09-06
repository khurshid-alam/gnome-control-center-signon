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

#ifndef _AP_PLUGIN_H_
#define _AP_PLUGIN_H_

#include <glib-object.h>
#include <gtk/gtk.h>
#include <libaccounts-glib/ag-account.h>
#include <libaccounts-glib/ag-provider.h>

G_BEGIN_DECLS

#define AP_TYPE_PLUGIN             (ap_plugin_get_type ())
#define AP_PLUGIN(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), AP_TYPE_PLUGIN, ApPlugin))
#define AP_PLUGIN_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), AP_TYPE_PLUGIN, ApPluginClass))
#define AP_IS_PLUGIN(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), AP_TYPE_PLUGIN))
#define AP_IS_PLUGIN_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), AP_TYPE_PLUGIN))
#define AP_PLUGIN_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), AP_TYPE_PLUGIN, ApPluginClass))

typedef struct _ApPluginClass ApPluginClass;
typedef struct _ApPluginPrivate ApPluginPrivate;
typedef struct _ApPlugin ApPlugin;

/**
 * ApPluginClass:
 *
 * Base class for account plugins.
 */
struct _ApPluginClass
{
    GObjectClass parent_class;
    GtkWidget *(*build_widget) (ApPlugin *self);
    void (*delete_account) (ApPlugin *self,
                            GAsyncReadyCallback callback,
                            gpointer user_data);
    void (*act_headless) (ApPlugin *self);
    void (*_ap_reserved4) (void);
    void (*_ap_reserved5) (void);
    void (*_ap_reserved6) (void);
    void (*_ap_reserved7) (void);
};

/**
 * ApPlugin:
 *
 * Use the accessor functions below.
 */
struct _ApPlugin
{
    GObject parent_instance;

    /*< private >*/
    ApPluginPrivate *priv;
};

GType ap_plugin_get_type (void) G_GNUC_CONST;

AgAccount *ap_plugin_get_account (ApPlugin *self);
AgProvider *ap_plugin_get_provider (ApPlugin *self);

void ap_plugin_emit_finished (ApPlugin *self);

void ap_plugin_set_need_authentication (ApPlugin *self,
                                        gboolean need_authentication);
gboolean ap_plugin_get_need_authentication (ApPlugin *self);

void ap_plugin_set_credentials (ApPlugin *self,
                                const gchar *username,
                                const gchar *password);
const gchar *ap_plugin_get_username (ApPlugin *self);
const gchar *ap_plugin_get_password (ApPlugin *self);

void ap_plugin_set_cookies (ApPlugin *self, GHashTable *cookies);
GHashTable *ap_plugin_get_cookies (ApPlugin *self);

void ap_plugin_set_ignore_cookies (ApPlugin *self, gboolean ignore_cookies);
gboolean ap_plugin_get_ignore_cookies (ApPlugin *self);

void ap_plugin_set_user_cancelled (ApPlugin *self, gboolean cancelled);
gboolean ap_plugin_get_user_cancelled (ApPlugin *self);

void ap_plugin_set_error (ApPlugin *self, const GError *error);
const GError *ap_plugin_get_error (ApPlugin *self);

GtkWidget *ap_plugin_build_widget (ApPlugin *self);

void ap_plugin_act_headless (ApPlugin *self);

void ap_plugin_delete_account (ApPlugin *self,
                               GAsyncReadyCallback callback,
                               gpointer user_data);

gboolean ap_plugin_delete_account_finish (ApPlugin *self,
                                          GAsyncResult *result,
                                          GError **error);

/**
 * AP_PLUGIN_CREDENTIALS_ID_FIELD:
 *
 * The field in the credentials database for storing the signon identity ID.
 */
#define AP_PLUGIN_CREDENTIALS_ID_FIELD "CredentialsId"

G_END_DECLS

#endif /* _AP_PLUGIN_H_ */
