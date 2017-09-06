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

/**
 * SECTION:ap-application-plugin
 * @short_description: Base class for application plugins.
 * @include: libaccount-plugin/application-plugin.h
 *
 * Application plugins for the credentials panel of the Unity control center
 * need to subclass #ApApplicationPlugin and implement its build_widget()
 * virtual method.
 * This method will be called by the credentials panel when it needs to show a
 * UI to edit the application-specific settings of the account.
 */

#include "application-plugin.h"

#include <libaccounts-glib/ag-manager.h>

enum
{
    PROP_0,

    PROP_APPLICATION,
    PROP_ACCOUNT,

    N_PROPERTIES
};

enum
{
    FINISHED,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL] = { 0 };
static GParamSpec *properties[N_PROPERTIES] = { NULL, };

struct _ApApplicationPluginPrivate
{
    AgAccount *account;
    AgApplication *application;
    GError *error;
};

G_DEFINE_TYPE (ApApplicationPlugin, ap_application_plugin, G_TYPE_OBJECT);

#define AP_APPLICATION_PLUGIN_PRIV(obj) (AP_APPLICATION_PLUGIN(obj)->priv)

static void
ap_application_plugin_init (ApApplicationPlugin *application_plugin)
{
    application_plugin->priv =
        G_TYPE_INSTANCE_GET_PRIVATE (application_plugin,
                                     AP_TYPE_APPLICATION_PLUGIN,
                                     ApApplicationPluginPrivate);
}

static void
ap_application_plugin_set_property (GObject *object, guint property_id,
                        const GValue *value, GParamSpec *pspec)
{
    ApApplicationPluginPrivate *priv = AP_APPLICATION_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_ACCOUNT:
        g_assert (priv->account == NULL);
        priv->account = g_value_dup_object (value);
        break;
    case PROP_APPLICATION:
        g_assert (priv->application == NULL);
        priv->application = g_value_dup_boxed (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_application_plugin_get_property (GObject *object, guint property_id,
                        GValue *value, GParamSpec *pspec)
{
    ApApplicationPluginPrivate *priv = AP_APPLICATION_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_ACCOUNT:
        g_value_set_object (value, priv->account);
        break;
    case PROP_APPLICATION:
        g_value_set_boxed (value, priv->application);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_application_plugin_dispose (GObject *object)
{
    ApApplicationPluginPrivate *priv = AP_APPLICATION_PLUGIN_PRIV (object);

    g_clear_object (&priv->account);

    if (priv->application)
    {
        ag_application_unref (priv->application);
        priv->application = NULL;
    }

    G_OBJECT_CLASS (ap_application_plugin_parent_class)->dispose (object);
}

static void
ap_application_plugin_finalize (GObject *object)
{
    ApApplicationPluginPrivate *priv = AP_APPLICATION_PLUGIN_PRIV (object);

    g_clear_error (&priv->error);

    G_OBJECT_CLASS (ap_application_plugin_parent_class)->finalize (object);
}

static void
ap_application_plugin_class_init (ApApplicationPluginClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);

    g_type_class_add_private (object_class,
                              sizeof (ApApplicationPluginPrivate));

    object_class->set_property = ap_application_plugin_set_property;
    object_class->get_property = ap_application_plugin_get_property;
    object_class->dispose = ap_application_plugin_dispose;
    object_class->finalize = ap_application_plugin_finalize;

    /**
     * ApApplicationPlugin:account:
     *
     * The #AgAccount associated with the plugin.
     */
    properties[PROP_ACCOUNT] =
        g_param_spec_object ("account", "Account for this plugin",
                             "The AgAccount associated with the plugin",
                             AG_TYPE_ACCOUNT,
                             G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY |
                             G_PARAM_STATIC_STRINGS);

    /**
     * ApApplicationPlugin:application:
     *
     * The #AgApplication associated with the plugin.
     */
    properties[PROP_APPLICATION] =
        g_param_spec_boxed ("application", "Application for this plugin",
                            "The AgApplication associated with the plugin",
                            ag_application_get_type(),
                            G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY |
                            G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties (object_class, N_PROPERTIES, properties);

    /**
     * ApApplicationPlugin::finished:
     * @self: the #ApApplicationPlugin.
     *
     * Emitted when the plugin UI has completed its task and can be dismissed.
     */
    signals[FINISHED] = g_signal_new ("finished",
        G_TYPE_FROM_CLASS (klass),
        G_SIGNAL_RUN_LAST,
        0,
        NULL, NULL,
        g_cclosure_marshal_VOID__VOID,
        G_TYPE_NONE,
        0);
}

/**
 * ap_application_plugin_get_account:
 * @self: the #ApApplicationPlugin.
 *
 * Get the #AgAccount associated with this application_plugin instance.
 *
 * Returns: (transfer none): the #AgAccount, or %NULL.
 */
AgAccount *
ap_application_plugin_get_account (ApApplicationPlugin *self)
{
    g_return_val_if_fail (AP_IS_APPLICATION_PLUGIN (self), NULL);
    return self->priv->account;
}

/**
 * ap_application_plugin_get_application:
 * @self: the #ApApplicationPlugin.
 *
 * Get the #AgApplication associated with this plugin instance.
 *
 * Returns: (transfer none): the #AgApplication, or %NULL.
 */
AgApplication *
ap_application_plugin_get_application (ApApplicationPlugin *self)
{
    g_return_val_if_fail (AP_IS_APPLICATION_PLUGIN (self), NULL);
    return self->priv->application;
}

/**
 * ap_application_plugin_emit_finished:
 * @self: the #ApApplicationPlugin.
 *
 * Emits the #ApApplicationPlugin::finished signal. This method is useful for
 * subclasses only.
 */
void
ap_application_plugin_emit_finished (ApApplicationPlugin *self)
{
    g_return_if_fail (AP_IS_APPLICATION_PLUGIN (self));
    g_signal_emit (self, signals[FINISHED], 0);
}

/**
 * ap_application_plugin_set_error:
 * @self: the #ApApplicationPlugin.
 * @error: the #GError to set on the plugin.
 *
 * Tell the application plugin that the requested operation ended in an error.
 * This method should be called by #ApApplicationPlugin subclasses only.
 */
void
ap_application_plugin_set_error (ApApplicationPlugin *self, const GError *error)
{
    ApApplicationPluginPrivate *priv;

    g_return_if_fail (AP_IS_APPLICATION_PLUGIN (self));
    priv = self->priv;

    g_clear_error (&priv->error);

    if (error != NULL)
    {
        priv->error = g_error_copy (error);
    }
}

/**
 * ap_application_plugin_get_error:
 * @self: the #ApApplicationPlugin.
 *
 * Get whether the requested operation ended in an error.
 *
 * Returns: (transfer none): a #GError if an error occurred, %NULL otherwise.
 */
const GError *
ap_application_plugin_get_error (ApApplicationPlugin *self)
{
    g_return_val_if_fail (AP_IS_APPLICATION_PLUGIN (self), NULL);
    return self->priv->error;
}

/**
 * ap_application_plugin_build_widget:
 * @self: the #ApApplicationPlugin.
 *
 * Build a UI widget to edit the application-specific account settings on the
 * #AgAccount associated with this plugin.
 * The plugin must emit the #ApApplicationPlugin::finished signal once the
 * widget has completed its tasks and can be destroyed.
 *
 * Returns: (transfer floating): a #GtkWidget which till take care of
 * performing the needed tasks, or %NULL.
 */
GtkWidget *
ap_application_plugin_build_widget (ApApplicationPlugin *self)
{
    g_return_val_if_fail (AP_IS_APPLICATION_PLUGIN (self), NULL);
    return AP_APPLICATION_PLUGIN_GET_CLASS (self)->build_widget (self);
}
