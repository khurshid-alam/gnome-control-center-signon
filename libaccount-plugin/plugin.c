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
 * SECTION:ap-plugin
 * @short_description: Base class for account plugins.
 * @include: libaccount-plugin/plugin.h
 *
 * Account plugins for the credentials panel of the Unity control center need
 * to subclass #ApPlugin and implement its build_widget() virtual method.
 * This method will be called by the credentials panel when it needs to show a
 * UI to handle some operations on the account, such as creation, editing or
 * re-authentication.
 */

#include "plugin.h"

#include <libaccounts-glib/ag-manager.h>
#include <libaccounts-glib/ag-service.h>
#include <libsignon-glib/signon-identity.h>

enum
{
    PROP_0,

    PROP_ACCOUNT,
    PROP_NEED_AUTHENTICATION,
};

enum
{
    FINISHED,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL] = { 0 };

static const gchar signon_id[] = AP_PLUGIN_CREDENTIALS_ID_FIELD;

struct _ApPluginPrivate
{
    AgAccount *account;
    AgProvider *provider;
    GError *error;
    gchar *username;
    gchar *password;
    GHashTable *cookies;
    gboolean ignore_cookies;
    gboolean need_authentication;
    gboolean cancelled;
};

G_DEFINE_TYPE (ApPlugin, ap_plugin, G_TYPE_OBJECT);

#define AP_PLUGIN_PRIV(obj) (AP_PLUGIN(obj)->priv)

static void
account_removed_cb (GObject *source_object, GAsyncResult *res,
                    gpointer user_data)
{
    GSimpleAsyncResult *result = user_data;
    GError *error = NULL;

    ag_account_store_finish (AG_ACCOUNT (source_object), res, &error);
    if (G_UNLIKELY (error != NULL))
    {
        g_simple_async_result_set_op_res_gboolean (result, FALSE);
        g_simple_async_result_take_error (result, error);
    }
    else
    {
        g_simple_async_result_set_op_res_gboolean (result, TRUE);
    }

    g_simple_async_result_complete_in_idle (result);
    g_object_unref (result);
}

static void
delete_account_from_db (ApPlugin *self, GSimpleAsyncResult *result)
{
    ApPluginPrivate *priv = self->priv;

    ag_account_delete (priv->account);
    ag_account_store_async (priv->account, NULL, account_removed_cb, result);
}

static void
identity_removed_cb (SignonIdentity *identity, const GError *error,
                     gpointer user_data)
{
    GSimpleAsyncResult *result = user_data;
    GObject *plugin;

    if (G_UNLIKELY (error != NULL))
    {
        g_simple_async_result_set_op_res_gboolean (result, FALSE);
        g_simple_async_result_set_from_error (result, error);
        g_simple_async_result_complete_in_idle (result);
        g_object_unref (result);
        g_object_unref (identity);
        return;
    }

    g_object_unref (identity);

    plugin = g_async_result_get_source_object ((GAsyncResult *)result);
    delete_account_from_db (AP_PLUGIN (plugin), result);
}

static void
enable_account_and_services (AgAccount *account)
{
    GList *services, *list;

    services = ag_account_list_services (account);
    for (list = services; list != NULL; list = list->next)
    {
        AgService *service = list->data;
        ag_account_select_service (account, service);
        ag_account_set_enabled (account, TRUE);
    }
    ag_service_list_free (services);

    ag_account_select_service (account, NULL);
    ag_account_set_enabled (account, TRUE);
}

static void
ap_plugin_init (ApPlugin *plugin)
{
    plugin->priv = G_TYPE_INSTANCE_GET_PRIVATE (plugin, AP_TYPE_PLUGIN,
                                                ApPluginPrivate);
}

static void
ap_plugin_constructed (GObject *object)
{
    ApPluginPrivate *priv = AP_PLUGIN_PRIV (object);

    G_OBJECT_CLASS (ap_plugin_parent_class)->constructed (object);

    if (priv->account)
    {
        AgManager *manager;
        const gchar *provider_name;

        manager = ag_account_get_manager (priv->account);
        provider_name = ag_account_get_provider_name (priv->account);
        priv->provider = ag_manager_get_provider (manager, provider_name);

        /* if this is a newly created account, enable it and all of its
         * services */
        if (priv->account->id == 0)
            enable_account_and_services (priv->account);
    }

}

static void
ap_plugin_set_property (GObject *object, guint property_id,
                        const GValue *value, GParamSpec *pspec)
{
    ApPluginPrivate *priv = AP_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_ACCOUNT:
        g_assert (priv->account == NULL);
        priv->account = g_value_dup_object (value);
        break;
    case PROP_NEED_AUTHENTICATION:
        priv->need_authentication = g_value_get_boolean (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_plugin_get_property (GObject *object, guint property_id,
                        GValue *value, GParamSpec *pspec)
{
    ApPluginPrivate *priv = AP_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_ACCOUNT:
        g_value_set_object (value, priv->account);
        break;
    case PROP_NEED_AUTHENTICATION:
        g_value_set_boolean (value, priv->need_authentication);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_plugin_dispose (GObject *object)
{
    ApPluginPrivate *priv = AP_PLUGIN_PRIV (object);

    if (priv->account)
    {
        g_object_unref (priv->account);
        priv->account = NULL;
    }

    if (priv->provider)
    {
        ag_provider_unref (priv->provider);
        priv->provider = NULL;
    }

    G_OBJECT_CLASS (ap_plugin_parent_class)->dispose (object);
}

static void
ap_plugin_finalize (GObject *object)
{
    ApPluginPrivate *priv = AP_PLUGIN_PRIV (object);

    if (priv->error)
    {
        g_error_free (priv->error);
        priv->error = NULL;
    }

    g_free (priv->username);
    g_free (priv->password);

    if (priv->cookies != NULL)
    {
        g_hash_table_unref (priv->cookies);
        priv->cookies = NULL;
    }

    G_OBJECT_CLASS (ap_plugin_parent_class)->finalize (object);
}

static void
_ap_plugin_delete_account (ApPlugin *self,
                           GAsyncReadyCallback callback,
                           gpointer user_data)
{
    ApPluginPrivate *priv = self->priv;
    GVariant *v_id;
    GSimpleAsyncResult *result;
    gboolean deleting_identity = FALSE;

    result = g_simple_async_result_new ((GObject *)self,
                                        callback,
                                        user_data,
                                        ap_plugin_delete_account);

    /* delete the credentials from the SSO database */
    ag_account_select_service (priv->account, NULL);
    v_id = ag_account_get_variant (priv->account, signon_id, NULL);
    if (v_id != NULL)
    {
        SignonIdentity *identity =
            signon_identity_new_from_db (g_variant_get_uint32 (v_id));
        if (identity != NULL) {
            deleting_identity = TRUE;
            signon_identity_remove (identity,
                                    identity_removed_cb,
                                    result);
        }
    }

    /* delete the account; if the identity is being deleted, then this will
     * happen in the identity_removed_cb function */
    if (!deleting_identity)
        delete_account_from_db (self, result);
}

static void
ap_plugin_class_init (ApPluginClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);

    g_type_class_add_private (object_class, sizeof (ApPluginPrivate));

    object_class->constructed = ap_plugin_constructed;
    object_class->set_property = ap_plugin_set_property;
    object_class->get_property = ap_plugin_get_property;
    object_class->dispose = ap_plugin_dispose;
    object_class->finalize = ap_plugin_finalize;

    klass->delete_account = _ap_plugin_delete_account;

    /**
     * ApPlugin:account:
     *
     * The #AgAccount associated with the plugin.
     */
    g_object_class_install_property
        (object_class, PROP_ACCOUNT,
         g_param_spec_object ("account", "Account for this plugin",
                              "The AgAccount associated with the plugin",
                              AG_TYPE_ACCOUNT,
                              G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY |
                              G_PARAM_STATIC_STRINGS));

    /**
     * ApPlugin:need-authentication:
     *
     * Whether the plugin needs to be authenticated again.
     */
    g_object_class_install_property
        (object_class, PROP_NEED_AUTHENTICATION,
         g_param_spec_boolean ("need-authentication",
                               "Whether authentication is needed",
                               "Whether the plugin needs further authentication",
                               FALSE,
                               G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS));

    /**
     * ApPlugin::finished:
     * @plugin: the #ApPlugin.
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
 * ap_plugin_get_account:
 * @self: the #ApPlugin.
 *
 * Get the #AgAccount associated with this plugin instance.
 *
 * Returns: (transfer none): the #AgAccount, or %NULL.
 */
AgAccount *
ap_plugin_get_account (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->account;
}

/**
 * ap_plugin_get_provider:
 * @self: the #ApPlugin.
 *
 * Get the #AgProvider associated with this plugin instance.
 *
 * Returns: (transfer none): the #AgProvider, or %NULL.
 */
AgProvider *
ap_plugin_get_provider (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->provider;
}

/**
 * ap_plugin_emit_finished:
 * @self: the #ApPlugin.
 *
 * Emits the #ApPlugin::finished signal. This method is useful for subclasses
 * only.
 */
void
ap_plugin_emit_finished (ApPlugin *self)
{
    g_return_if_fail (AP_IS_PLUGIN (self));
    g_signal_emit (self, signals[FINISHED], 0);
}

/**
 * ap_plugin_set_need_authentication:
 * @self: the #ApPlugin.
 * @need_authentication: whether the plugin must perform the authentication.
 *
 * Tell the plugin that the #AgAccount associated with it needs to be
 * re-authenticated.
 */
void
ap_plugin_set_need_authentication (ApPlugin *self,
                                   gboolean need_authentication)
{
    g_return_if_fail (AP_IS_PLUGIN (self));
    self->priv->need_authentication = need_authentication;
}

/**
 * ap_plugin_get_need_authentication:
 * @self: the #ApPlugin.
 *
 * Get whether the #AgAccount associated with this plugin instance needs to be
 * re-authenticated.
 *
 * Returns: %TRUE if the account needs re-authentication, %FALSE otherwise.
 */
gboolean
ap_plugin_get_need_authentication (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), FALSE);
    return self->priv->need_authentication;
}

/**
 * ap_plugin_set_credentials:
 * @self: the #ApPlugin.
 * @username: login username.
 * @password: the user password, or %NULL.
 *
 * Set the user name and password. The plugin could use them for prefilling the
 * login form (or skip it altogether).
 */
void
ap_plugin_set_credentials (ApPlugin *self,
                           const gchar *username,
                           const gchar *password)
{
    ApPluginPrivate *priv;

    g_return_if_fail (AP_IS_PLUGIN (self));
    g_return_if_fail (username != NULL);
    priv = self->priv;

    g_free (priv->username);
    g_free (priv->password);
    priv->username = g_strdup (username);
    priv->password = g_strdup (password);
}

/**
 * ap_plugin_get_username:
 * @self: the #ApPlugin.
 *
 * Get the login username.
 *
 * Returns: the username, or %NULL.
 */
const gchar *
ap_plugin_get_username (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->username;
}

/**
 * ap_plugin_get_password:
 * @self: the #ApPlugin.
 *
 * Get the login password.
 *
 * Returns: the password, or %NULL.
 */
const gchar *
ap_plugin_get_password (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->password;
}

/**
 * ap_plugin_set_cookies:
 * @self: the #ApPlugin.
 * @cookies: (element-type utf8 utf8) (transfer none): a #GHashTable with
 * cookie name and value pairs.
 *
 * Set the HTTP cookies. The plugin may use them while performing a web-based
 * authentication.
 */
void ap_plugin_set_cookies (ApPlugin *self, GHashTable *cookies)
{
    ApPluginPrivate *priv;

    g_return_if_fail (AP_IS_PLUGIN (self));
    g_return_if_fail (cookies != NULL);
    priv = self->priv;

    if (priv->cookies != NULL)
    {
        g_hash_table_unref (priv->cookies);
    }
    priv->cookies = g_hash_table_ref (cookies);
}

/**
 * ap_plugin_get_cookies:
 * @self: the #ApPlugin.
 *
 * Get the HTTP cookies.
 *
 * Returns: (element-type utf8 utf8) (transfer none) (allow-none): a dictionary
 * with cookie name and value pairs, or %NULL.
 */
GHashTable *ap_plugin_get_cookies (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->cookies;
}

/**
 * ap_plugin_set_ignore_cookies:
 * @self: the #ApPlugin.
 * @ignore_cookies: whether provided cookies should be ignored.
 *
 * Tells the plugin implementation that all provided cookies should be ignored
 * when performing the authentication; an ApPlugin subclass might choose to
 * ignore cookies when the provided cookies are known not to be working.
 */
void
ap_plugin_set_ignore_cookies (ApPlugin *self, gboolean ignore_cookies)
{
    g_return_if_fail (AP_IS_PLUGIN (self));
    self->priv->ignore_cookies = ignore_cookies;
}

/**
 * ap_plugin_get_ignore_cookies:
 * @self: the #ApPlugin.
 *
 * Get whether the provided cookies should be ignored when performing the
 * authentication.
 *
 * Returns: whether provided cookies should be ignored.
 */
gboolean
ap_plugin_get_ignore_cookies (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), FALSE);
    return self->priv->ignore_cookies;
}

/**
 * ap_plugin_set_user_cancelled:
 * @self: the #ApPlugin.
 * @cancelled: whether the plugin operation was cancelled by the user.
 *
 * Tell the plugin that the requested operation was cancelled by the user. This
 * method should be called by #ApPlugin subclasses only.
 */
void
ap_plugin_set_user_cancelled (ApPlugin *self, gboolean cancelled)
{
    g_return_if_fail (AP_IS_PLUGIN (self));
    self->priv->cancelled = cancelled;
}

/**
 * ap_plugin_get_user_cancelled:
 * @self: the #ApPlugin.
 *
 * Get whether the requested operation was cancelled by the user.
 *
 * Returns: %TRUE if the operation was cancelled, %FALSE otherwise.
 */
gboolean
ap_plugin_get_user_cancelled (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), FALSE);
    return self->priv->cancelled;
}

/**
 * ap_plugin_set_error:
 * @self: the #ApPlugin.
 * @error: the #GError to set on the plugin.
 *
 * Tell the plugin that the requested operation ended in an error. This method
 * should be called by #ApPlugin subclasses only.
 */
void
ap_plugin_set_error (ApPlugin *self, const GError *error)
{
    ApPluginPrivate *priv;

    g_return_if_fail (AP_IS_PLUGIN (self));
    priv = self->priv;

    if (priv->error != NULL)
    {
        g_error_free (priv->error);
        priv->error = NULL;
    }

    if (error != NULL)
    {
        priv->error = g_error_copy (error);
    }
}

/**
 * ap_plugin_get_error:
 * @self: the #ApPlugin.
 *
 * Get whether the requested operation ended in an error.
 *
 * Returns: (transfer none): a #GError if an error occurred, %NULL otherwise.
 */
const GError *
ap_plugin_get_error (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return self->priv->error;
}

/**
 * ap_plugin_build_widget:
 * @self: the #ApPlugin.
 *
 * Build a UI widget to perform the needed operation on the #AgAccount
 * associated with this plugin:
 * - if the #AgAccount is a newly allocated instance (not stored on disk), then
 *   the plugin should proceed with the account creation. Otherwise,
 * - if the #ApPlugin:need-authentication property is set, the returned UI
 *   widget should provide a way for the user to reauthenticate the account;
 * - if none of the above conditions apply, the plugin should return a widget
 *   to allow editing the account global settings (that is, those settings
 *   which are common for all applications using the account).
 * The plugin will emit the #ApPlugin::finished signal once the widget has
 * completed its tasks and can be destroyed.
 *
 * Returns: (transfer floating): a #GtkWidget which till take care of
 * performing the needed tasks, or %NULL.
 */
GtkWidget *
ap_plugin_build_widget (ApPlugin *self)
{
    g_return_val_if_fail (AP_IS_PLUGIN (self), NULL);
    return AP_PLUGIN_GET_CLASS (self)->build_widget (self);
}

/**
 * ap_plugin_act_headless:
 * @self: the #ApPlugin.
 *
 * Perform the needed operation on the #AgAccount associated with this plugin.
 * This works similarly to the ap_plugin_build_widget() method, with the
 * difference that in this case there is no UI involved.
 * The plugin will emit the #ApPlugin::finished signal once it has
 * completed its tasks.
 */
void
ap_plugin_act_headless (ApPlugin *self)
{
    ApPluginPrivate *priv;

    g_return_if_fail (AP_IS_PLUGIN (self));
    priv = self->priv;

    if (priv->account->id == 0)
    {
        /* Disable the account; when acting headless, let the caller
         * decide when and whether the created account should be
         * enabled. */
        ag_account_select_service (priv->account, NULL);
        ag_account_set_enabled (priv->account, FALSE);
    }

    AP_PLUGIN_GET_CLASS (self)->act_headless (self);
}

/**
 * ap_plugin_delete_account:
 * @self: the #ApPlugin.
 * @callback: a callback which will be invoked when the operation has been
 * completed.
 * @user_data: user data to be passed to the callback.
 *
 * Delete the account. When the operation is finished, @callback will be
 * invoked; you can then call ap_plugin_delete_account_finish() to know if the
 * operation was successful.
 * This is a virtual method; the base implementation removes the account from
 * the accounts database and the accounts credentials from the Single Sign-On
 * database.
 */
void
ap_plugin_delete_account (ApPlugin *self,
                          GAsyncReadyCallback callback,
                          gpointer user_data)
{
    g_return_if_fail (AP_IS_PLUGIN (self));
    return AP_PLUGIN_GET_CLASS (self)->delete_account (self,
                                                       callback,
                                                       user_data);
}

/**
 * ap_plugin_delete_account_finish:
 * @self: the #ApPlugin.
 * @result: the #GAsyncResult obtained from the #GAsyncReadyCallback passed to
 * ap_plugin_delete_account().
 * @error: location for error, or %NULL.
 *
 * Finish the operation started with ap_plugin_delete_account().
 *
 * Returns: %TRUE if the operation succeeded, %FALSE otherwise.
 */
gboolean
ap_plugin_delete_account_finish (ApPlugin *self,
                                 GAsyncResult *result,
                                 GError **error)
{
    GSimpleAsyncResult *simple;
    gboolean ok;

    g_return_val_if_fail (AP_IS_PLUGIN (self), FALSE);
    g_return_val_if_fail (g_simple_async_result_is_valid (result,
                                                          (GObject *)self,
                                                          ap_plugin_delete_account),
                          FALSE);

    simple = (GSimpleAsyncResult *) result;

    ok = g_simple_async_result_get_op_res_gboolean (simple);
    if (!ok)
    {
        g_simple_async_result_propagate_error (simple, error);
    }

    return ok;
}
