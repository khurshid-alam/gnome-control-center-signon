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

#ifndef _AP_APPLICATION_PLUGIN_H_
#define _AP_APPLICATION_PLUGIN_H_

#include <glib-object.h>
#include <gtk/gtk.h>
#include <libaccounts-glib/ag-account.h>
#include <libaccounts-glib/ag-application.h>

G_BEGIN_DECLS

#define AP_TYPE_APPLICATION_PLUGIN             (ap_application_plugin_get_type ())
#define AP_APPLICATION_PLUGIN(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), AP_TYPE_APPLICATION_PLUGIN, ApApplicationPlugin))
#define AP_APPLICATION_PLUGIN_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), AP_TYPE_APPLICATION_PLUGIN, ApApplicationPluginClass))
#define AP_IS_APPLICATION_PLUGIN(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), AP_TYPE_APPLICATION_PLUGIN))
#define AP_IS_APPLICATION_PLUGIN_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), AP_TYPE_APPLICATION_PLUGIN))
#define AP_APPLICATION_PLUGIN_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), AP_TYPE_APPLICATION_PLUGIN, ApApplicationPluginClass))

typedef struct _ApApplicationPluginClass ApApplicationPluginClass;
typedef struct _ApApplicationPluginPrivate ApApplicationPluginPrivate;
typedef struct _ApApplicationPlugin ApApplicationPlugin;

/**
 * ApApplicationPluginClass:
 *
 * Base class for account application_plugins.
 */
struct _ApApplicationPluginClass
{
    GObjectClass parent_class;
    GtkWidget *(*build_widget) (ApApplicationPlugin *self);
    void (*_ap_reserved2) (void);
    void (*_ap_reserved3) (void);
    void (*_ap_reserved4) (void);
    void (*_ap_reserved5) (void);
    void (*_ap_reserved6) (void);
    void (*_ap_reserved7) (void);
};

/**
 * ApApplicationPlugin:
 *
 * Use the accessor functions below.
 */
struct _ApApplicationPlugin
{
    GObject parent_instance;

    /*< private >*/
    ApApplicationPluginPrivate *priv;
};

GType ap_application_plugin_get_type (void) G_GNUC_CONST;

AgAccount *ap_application_plugin_get_account (ApApplicationPlugin *self);
AgApplication *
ap_application_plugin_get_application (ApApplicationPlugin *self);

void ap_application_plugin_emit_finished (ApApplicationPlugin *self);

void ap_application_plugin_set_error (ApApplicationPlugin *self, const GError *error);
const GError *ap_application_plugin_get_error (ApApplicationPlugin *self);

GtkWidget *ap_application_plugin_build_widget (ApApplicationPlugin *self);

G_END_DECLS

#endif /* _AP_APPLICATION_PLUGIN_H_ */
