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
 * SECTION:ap-oauth-plugin
 * @short_description: Base class for account plugins using OAuth
 * authentication.
 * @include: libaccount-plugin/oauth-plugin.h
 *
 * This class helps creating account plugins which use the OAuth authentication
 * method.
 */

#include "oauth-plugin.h"

#include <glib/gi18n-lib.h>
#include <gtk/gtkx.h>
#include <libaccounts-glib/ag-account-service.h>
#include <libaccounts-glib/ag-auth-data.h>
#include <libaccounts-glib/ag-manager.h>
#include <libaccounts-glib/ag-provider.h>
#include <libsignon-glib/signon-auth-session.h>
#include <libsignon-glib/signon-errors.h>
#include <libsignon-glib/signon-identity.h>

enum
{
    PROP_0,

    PROP_OAUTH_PARAMS,
};

struct _ApOAuthPluginPrivate
{
    const gchar *mechanism;
    GHashTable *oauth_params;
    GHashTable *account_oauth_params;
    GtkSocket *socket;
    AgAuthData *auth_data;
    SignonIdentity *identity;
    SignonAuthSession *auth_session;
    GDBusConnection *connection;
    GCancellable *cancellable;
    GVariant *oauth_reply;
    gboolean identity_stored;
    gboolean deleting_identity;
    gboolean authenticating;
    gboolean storing_account;
};

static const gchar signon_id[] = AP_PLUGIN_CREDENTIALS_ID_FIELD;
static const gchar oauth_method[] = "oauth2";
/* Keep these in sync with the ApOAuthMechanism enum */
static const gchar *oauth_mechanisms[] = {
    "user_agent",
    "web_server",
    "HMAC-SHA1",
    "PLAINTEXT",
    "RSA-SHA1",
};

G_DEFINE_TYPE (ApOAuthPlugin, ap_oauth_plugin, AP_TYPE_PLUGIN);

#define AP_OAUTH_PLUGIN_PRIV(obj) (AP_OAUTH_PLUGIN(obj)->priv)

static const gchar *
get_mechanism(ApOAuthPluginPrivate *priv)
{
    const gchar *mechanism = NULL;

    if (priv->mechanism != NULL)
        return priv->mechanism;

    if (priv->auth_data != NULL)
        mechanism = ag_auth_data_get_mechanism (priv->auth_data);

    if (mechanism == NULL)
        mechanism = oauth_mechanisms[AP_OAUTH_MECHANISM_USER_AGENT];

    return mechanism;
}

static GVariant *
value_to_variant (GValue *value)
{
    const GVariantType *type;

    switch (G_VALUE_TYPE (value))
    {
    case G_TYPE_STRING: type = G_VARIANT_TYPE_STRING; break;
    case G_TYPE_BOOLEAN: type = G_VARIANT_TYPE_BOOLEAN; break;
    case G_TYPE_UCHAR: type = G_VARIANT_TYPE_BYTE; break;
    case G_TYPE_INT: type = G_VARIANT_TYPE_INT32; break;
    case G_TYPE_UINT: type = G_VARIANT_TYPE_UINT32; break;
    case G_TYPE_INT64: type = G_VARIANT_TYPE_INT64; break;
    case G_TYPE_UINT64: type = G_VARIANT_TYPE_UINT64; break;
    case G_TYPE_DOUBLE: type = G_VARIANT_TYPE_DOUBLE; break;
    default:
        if (G_VALUE_TYPE (value) == G_TYPE_STRV)
        {
            type = G_VARIANT_TYPE_STRING_ARRAY;
            break;
        }
        g_warning ("Unsupported type %s", G_VALUE_TYPE_NAME (value));
        return NULL;
    }

    return g_dbus_gvalue_to_gvariant (value, type);
}

static gboolean
emit_finished (ApPlugin *plugin)
{
    ap_plugin_emit_finished (plugin);
    return FALSE;
}

static void
finish_if_ready (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;

    /* Check if some asynchronous operations are still running */
    if (priv->authenticating) return;
    if (priv->storing_account) return;
    if (priv->deleting_identity) return;

    g_idle_add ((GSourceFunc)emit_finished, self);
}

static void
identity_removed_cb (SignonIdentity *identity, const GError *error,
                     gpointer user_data)
{
    ApOAuthPlugin *self;

    if (G_UNLIKELY (error != NULL))
    {
        if (g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        {
            return;
        }
        g_critical ("Error removing identity: %s", error->message);
        /* No special handling, we are quitting anyways */
    }

    self = AP_OAUTH_PLUGIN (user_data);

    self->priv->deleting_identity = FALSE;
    self->priv->identity_stored = FALSE;
    finish_if_ready (self);
}

static void
finish_with_cleanup (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;

    if (priv->auth_session != NULL)
    {
        signon_auth_session_cancel (priv->auth_session);
    }

    if (priv->identity != NULL &&
        priv->identity_stored &&
        !priv->deleting_identity)
    {
        priv->deleting_identity = TRUE;
        signon_identity_remove (priv->identity, identity_removed_cb, self);
    }

    finish_if_ready (self);
}

static void
finish_with_error (ApOAuthPlugin *self, const GError *error)
{
    ap_plugin_set_error ((ApPlugin *)self, error);
    finish_with_cleanup (self);
}

static void
finish_with_cancellation (ApOAuthPlugin *self)
{
    ap_plugin_set_user_cancelled ((ApPlugin *)self, TRUE);
    finish_with_cleanup (self);
}

static void
account_store_cb (GObject *source_object, GAsyncResult *res,
                  gpointer user_data)
{
    ApOAuthPlugin *self;
    GError *error = NULL;

    ag_account_store_finish (AG_ACCOUNT (source_object), res, &error);
    if (g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
    {
        g_error_free (error);
        return;
    }

    self = AP_OAUTH_PLUGIN (user_data);
    self->priv->storing_account = FALSE;

    if (G_UNLIKELY (error != NULL))
    {
        g_critical ("Account write error: %s", error->message);
        finish_with_error (self, error);
        g_error_free (error);
        return;
    }

    /* Emit the "finished" signal in an idle callback, or this will cause the
     * destruction of our instance, and specifically of its priv->auth_session
     * member, which hasn't returned from its auth_session_process_cb()
     * callback. */
    g_idle_add ((GSourceFunc)emit_finished, self);
}

static void
unset_authentication_settings (AgAccount *account,
                               const gchar *method,
                               const gchar *mechanism)
{
    AgAccountSettingIter iter;
    const gchar *key;
    GVariant *variant;
    gchar *prefix, *full_key;

    prefix = g_strdup_printf ("auth/%s/%s/", method, mechanism);
    ag_account_settings_iter_init (account, &iter, prefix);
    while (ag_account_settings_iter_get_next (&iter, &key, &variant))
    {
        full_key = g_strconcat (prefix, key, NULL);
        ag_account_set_variant (account, full_key, NULL);
        g_free (full_key);
    }
    g_free (prefix);
}

static void
store_authentication_parameters (ApOAuthPlugin *self, AgAccount *account)
{
    ApOAuthPluginPrivate *priv = self->priv;
    GHashTableIter iter;
    gpointer key, value;
    gchar *full_key;
    const gchar *mechanism;

    mechanism = get_mechanism (priv);
    /* Delete any existing parameter (if the account is not new) */
    if (account->id != 0)
    {
        unset_authentication_settings (account,
                                       oauth_method, mechanism);
    }

    /* Add all the provider-specific OAuth parameters. */
    if (priv->account_oauth_params != NULL)
    {
        g_hash_table_iter_init (&iter, priv->account_oauth_params);
        while (g_hash_table_iter_next (&iter, &key, &value))
        {
            GVariant *variant = value_to_variant (value);
            full_key = g_strdup_printf ("auth/%s/%s/%s",
                                        oauth_method, mechanism,
                                        (gchar *)key);
            ag_account_set_variant (account, full_key, variant);
            g_variant_unref (variant);
            g_free (full_key);
        }
    }
}

/**
 * ap_oauth_plugin_store_account:
 * @self: the #ApOAuthPlugin.
 *
 * Store the account into the database. Subclasses which reimplemented the
 * query_username() method should call this protected method after they are
 * done.
 */
void
ap_oauth_plugin_store_account (ApOAuthPlugin *self)
{
    AgAccount *account;

    account = ap_plugin_get_account ((ApPlugin *)self);
    store_authentication_parameters (self, account);

    self->priv->storing_account = TRUE;
    ag_account_store_async (account, self->priv->cancellable,
                            account_store_cb, self);
}

static void
query_info_cb (SignonIdentity *identity,
               const SignonIdentityInfo *info,
               const GError *error,
               gpointer user_data)
{
    ApOAuthPlugin *self = AP_OAUTH_PLUGIN (user_data);
    AgAccount *account;

    if (G_UNLIKELY (error != NULL))
    {
        g_warning ("Couldn't read back identity information");
        // this is not a critical error; continue with the account creation
    }
    else
    {
        const gchar *username;
        username = signon_identity_info_get_username (info);
        if (username != NULL)
        {
            ap_plugin_set_credentials ((ApPlugin *)self, username, NULL);
            account = ap_plugin_get_account ((ApPlugin *)self);
            ag_account_set_display_name (account, username);
        }
    }

    ap_oauth_plugin_store_account (self);
}

static void
_ap_oauth_plugin_query_username (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;

    signon_identity_query_info (priv->identity, query_info_cb, self);
}

static void
auth_session_process_cb (GObject *source_object,
                         GAsyncResult *res,
                         gpointer user_data)
{
    ApOAuthPlugin *self;
    SignonAuthSession *auth_session = SIGNON_AUTH_SESSION (source_object);
    AgAccount *account;
    GVariant *oauth_reply;
    GError *error = NULL;

    oauth_reply = signon_auth_session_process_finish (auth_session,
                                                      res,
                                                      &error);

    if (g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
    {
        g_error_free (error);
        return;
    }

    self = AP_OAUTH_PLUGIN (user_data);
    self->priv->authenticating = FALSE;
    self->priv->oauth_reply = oauth_reply;

    if (G_UNLIKELY (error != NULL))
    {
        if (error->domain == SIGNON_ERROR &&
            error->code == SIGNON_ERROR_SESSION_CANCELED)
        {
            /* Don't report an error if the session has been cancelled by the
             * user */
            finish_with_cancellation (self);
        }
        else
        {
            g_warning ("AuthSession error: %s", error->message);
            finish_with_error (self, error);
        }
        g_error_free (error);
        return;
    }

    account = ap_plugin_get_account ((ApPlugin *)self);

    if (account->id == 0)
    {
        /* newly created account */
        AP_OAUTH_PLUGIN_GET_CLASS (self)->query_username (self);
    }
    else
    {
        /* re-authenticated account */
        ap_plugin_set_need_authentication ((ApPlugin *)self, FALSE);

        /* Store the authentication parameters, in case they have changed.
         * This might be removed or reviewed once the following is implemented:
         * http://code.google.com/p/accounts-sso/issues/detail?id=111
         */
        ap_oauth_plugin_store_account (self);
    }
}

static GVariant *
cookies_to_variant (GHashTable *cookies)
{
    GVariantBuilder builder;
    GHashTableIter iter;
    const gchar *key, *value;

    g_variant_builder_init (&builder, G_VARIANT_TYPE ("a{ss}"));
    g_hash_table_iter_init (&iter, cookies);
    while (g_hash_table_iter_next (&iter, (gpointer)&key, (gpointer)&value))
    {
        g_variant_builder_add (&builder, "{ss}", key, value);
    }

    return g_variant_builder_end (&builder);
}

static GVariant *
prepare_session_data (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;
    GVariant *session_data;
    GVariantBuilder builder;
    GHashTableIter iter;
    GHashTable *cookies;
    gpointer key, value;

    g_variant_builder_init (&builder, G_VARIANT_TYPE_VARDICT);
    if (priv->socket != NULL)
    {
        guint32 window_id = gtk_socket_get_id (priv->socket);

        g_variant_builder_add (&builder, "{sv}",
                               "WindowId",
                               g_variant_new_uint32 (window_id));
        g_variant_builder_add (&builder, "{sv}",
                               "Embedded",
                               g_variant_new_boolean (TRUE));
    }

    cookies = ap_plugin_get_cookies ((ApPlugin *)self);
    if (cookies != NULL &&
        !ap_plugin_get_ignore_cookies ((ApPlugin *)self))
    {
        g_variant_builder_add (&builder, "{sv}",
                               "Cookies",
                               cookies_to_variant (cookies));
    }

    /* Add all the provider-specific OAuth parameters. */
    if (priv->oauth_params != NULL)
    {
        g_hash_table_iter_init (&iter, priv->oauth_params);
        while (g_hash_table_iter_next (&iter, &key, &value))
        {
            GVariant *variant = value_to_variant (value);
            g_variant_builder_add (&builder, "{sv}", key, variant);
            g_variant_unref (variant);
        }
    }

    /* Merge the session parameters built so far with the provider's default
     * parameters */
    session_data = g_variant_builder_end (&builder);
    if (priv->auth_data != NULL)
    {
        session_data = ag_auth_data_get_login_parameters (priv->auth_data,
                                                          session_data);
    }
    return session_data;
}

static void
start_authentication_process (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;
    GVariant *session_data;
    GError *error = NULL;

    session_data = prepare_session_data (self);

    priv->auth_session = signon_identity_create_session (priv->identity,
                                                         oauth_method,
                                                         &error);
    if (G_UNLIKELY (!priv->auth_session))
    {
        g_critical ("Couldn't create AuthSession: %s", error->message);
        finish_with_error (self, error);
        g_clear_error (&error);
        return;
    }
    priv->authenticating = TRUE;
    signon_auth_session_process_async (priv->auth_session, session_data,
                                       get_mechanism (priv),
                                       priv->cancellable,
                                       auth_session_process_cb,
                                       self);
}

static void
identity_store_cb (SignonIdentity *identity, guint32 id,
                   const GError *error, gpointer user_data)
{
    ApOAuthPlugin *self = AP_OAUTH_PLUGIN (user_data);
    ApOAuthPluginPrivate *priv = self->priv;
    AgAccount *account;
    GVariant *v_id;

    if (G_UNLIKELY (error != NULL))
    {
        g_critical ("Couldn't store identity: %s", error->message);
        finish_with_error (self, error);
        return;
    }

    priv->identity_stored = TRUE;

    /* store the identity ID into the account settings */
    v_id = g_variant_new_uint32 (id);
    account = ap_plugin_get_account ((ApPlugin *)self);
    ag_account_set_variant (account, signon_id, v_id);

    if (priv->socket != NULL)
    {
        start_authentication_process (self);
    }
    else
    {
        /* operating headless: just store the account */
        ap_oauth_plugin_store_account (self);
    }
}

static void
setup_authentication (ApOAuthPlugin *self)
{
    SignonIdentityInfo *info;
    AgProvider *provider;
    const gchar *acl_all[] = { "*", NULL };
    const gchar *username;
    const gchar *secret;

    username = ap_plugin_get_username ((ApPlugin *)self);
    secret = ap_plugin_get_password ((ApPlugin *)self);
    if (secret == NULL) secret = "";

    info = signon_identity_info_new ();
    provider = ap_plugin_get_provider ((ApPlugin *)self);
    signon_identity_info_set_caption (info,
                                      ag_provider_get_display_name (provider));
    signon_identity_info_set_identity_type (info, SIGNON_IDENTITY_TYPE_APP);
    if (username != NULL)
        signon_identity_info_set_username (info, username);
    signon_identity_info_set_secret (info, secret, TRUE);
    signon_identity_info_set_access_control_list (info, acl_all);

    self->priv->identity = signon_identity_new ();
    signon_identity_store_credentials_with_info (self->priv->identity, info,
                                                 identity_store_cb, self);
    signon_identity_info_free (info);
}

static void
reauthenticate_account_cb (GDBusConnection *connection,
                           GAsyncResult *res,
                           ApOAuthPlugin *self)
{
    GVariant *result;
    GError *error = NULL;
    gboolean authenticated = FALSE;

    result = g_dbus_connection_call_finish (connection, res, &error);
    if (G_UNLIKELY (error != NULL))
    {
        if (error->domain == G_IO_ERROR &&
            error->code == G_IO_ERROR_CANCELLED)
        {
            finish_with_cancellation (self);
        }
        else
        {
            g_warning ("Reauthentication failed: %s", error->message);
            finish_with_error (self, error);
        }
        g_clear_error (&error);
        return;
    }

    g_assert (result != NULL);
    g_variant_get (result, "(b)", &authenticated);
    ap_plugin_set_need_authentication ((ApPlugin *)self, !authenticated);
    finish_with_cleanup (self);
}

static void
setup_reauthentication (ApOAuthPlugin *self)
{
    ApOAuthPluginPrivate *priv = self->priv;
    AgAccount *account;
    GVariantBuilder builder;
    GVariant *args;
    guint32 window_id;

    account = ap_plugin_get_account ((ApPlugin *)self);
    g_assert (account->id != 0);

    window_id = gtk_socket_get_id (priv->socket);

    g_variant_builder_init (&builder, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add (&builder, "{sv}",
                           "WindowId",
                           g_variant_new_uint32 (window_id));
    g_variant_builder_add (&builder, "{sv}",
                           "Embedded",
                           g_variant_new_boolean (TRUE));
    args = g_variant_new ("(u@a{sv})",
                          account->id,
                          g_variant_builder_end (&builder),
                          NULL);

    if (priv->connection == NULL)
    {
        GError *error = NULL;
        priv->connection = g_bus_get_sync (G_BUS_TYPE_SESSION, NULL, &error);
        if (G_UNLIKELY (error != NULL))
        {
            g_critical ("Couldn't connect to D-Bus session: %s",
                        error->message);
            g_clear_error (&error);
            return;
        }
    }

    g_dbus_connection_call (priv->connection,
                            "com.canonical.indicators.webcredentials",
                            "/com/canonical/indicators/webcredentials",
                            "com.canonical.indicators.webcredentials",
                            "ReauthenticateAccount",
                            args,
                            NULL,
                            G_DBUS_CALL_FLAGS_NONE,
                            G_MAXINT,
                            priv->cancellable,
                            (GAsyncReadyCallback)reauthenticate_account_cb,
                            self);
}

static void
on_infobar_response (GtkInfoBar *infobar, gint response_id,
                     ApOAuthPlugin *self)
{
    g_assert (response_id == GTK_RESPONSE_CANCEL);

    finish_with_cancellation (self);
}

static GtkWidget *
create_infobar (ApOAuthPlugin *self)
{
    GtkWidget *infobar;
    GtkWidget *infobar_label;
    GtkWidget *content_area;
    GtkCssProvider *css;
    GError *error;
    GtkStyleContext *context;
    AgProvider *provider;
    gchar *text;

    infobar = gtk_info_bar_new_with_buttons (GTK_STOCK_CANCEL,
                                             GTK_RESPONSE_CANCEL,
                                             NULL);
    gtk_widget_set_hexpand (infobar, TRUE);
    gtk_info_bar_set_message_type (GTK_INFO_BAR (infobar),
                                   GTK_MESSAGE_QUESTION);
    gtk_widget_set_name (infobar, "authorization-infobar");
    g_signal_connect (infobar, "response",
                      G_CALLBACK (on_infobar_response), self);

    provider = ap_plugin_get_provider ((ApPlugin *)self);
    text = g_strdup_printf (_("Please authorize Ubuntu to access "
                              "your %s account"),
                            ag_provider_get_display_name (provider));
    infobar_label = gtk_label_new (text);
    g_free (text);

    content_area = gtk_info_bar_get_content_area (GTK_INFO_BAR (infobar));
    gtk_container_add (GTK_CONTAINER (content_area), infobar_label);

    css = gtk_css_provider_new ();
    error = NULL;
    if (gtk_css_provider_load_from_data (css,
                                         "@define-color question_bg_color rgb (222, 222, 222); GtkInfoBar#authorization-infobar { color: @fg_color }",
                                         -1,
                                         &error))
    {
        context = gtk_widget_get_style_context (infobar);
        gtk_style_context_add_provider (context,
                                        GTK_STYLE_PROVIDER (css),
                                        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
    else
    {
        g_warning ("Error processing CSS theme override: %s", error->message);
    }

    gtk_widget_show_all (infobar);

    return infobar;
}

static gboolean
on_socket_plug_removed (GtkSocket *socket, ApOAuthPlugin *self)
{
    /* Do not destroy the socket when the plug is removed. */
    return TRUE;
}

static GtkWidget *
create_socket_frame (ApOAuthPlugin *self)
{
    GtkWidget *frame;
    GtkWidget *socket;

    frame = gtk_frame_new (NULL);

    socket = gtk_socket_new ();
    self->priv->socket = GTK_SOCKET(socket);
    gtk_widget_set_hexpand (socket, TRUE);
    gtk_widget_set_vexpand (socket, TRUE);
    gtk_widget_set_can_focus (socket, TRUE);
    gtk_widget_grab_focus (socket);
    g_signal_connect (socket, "plug-removed",
                      G_CALLBACK (on_socket_plug_removed), self);

    gtk_widget_show (socket);
    gtk_container_add (GTK_CONTAINER (frame), socket);
    gtk_widget_show (frame);

    return frame;
}

static GtkWidget *
create_legal_button ()
{
    GtkWidget *buttonbox;
    GtkWidget *link_button;

    buttonbox = gtk_button_box_new (GTK_ORIENTATION_HORIZONTAL);
    gtk_button_box_set_layout (GTK_BUTTON_BOX (buttonbox), GTK_BUTTONBOX_END);

    link_button = gtk_link_button_new_with_label ("help:web-credentials/legal-notice",
                                                  _("Legal notice"));

    gtk_container_add (GTK_CONTAINER (buttonbox), link_button);
    gtk_widget_show_all (buttonbox);

    return buttonbox;
}

static void
ap_oauth_plugin_init (ApOAuthPlugin *self)
{
    self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, AP_TYPE_OAUTH_PLUGIN,
                                              ApOAuthPluginPrivate);
    self->priv->mechanism = NULL;
    self->priv->cancellable = g_cancellable_new ();
    self->priv->oauth_reply = NULL;
}

static void
ap_oauth_plugin_constructed (GObject *object)
{
    ApOAuthPluginPrivate *priv = AP_OAUTH_PLUGIN_PRIV (object);
    AgAccount *account;
    AgAccountService *account_service;

    G_OBJECT_CLASS (ap_oauth_plugin_parent_class)->constructed (object);

    account = ap_plugin_get_account (AP_PLUGIN (object));
    if (account != NULL)
    {
        account_service = ag_account_service_new (account, NULL);
        priv->auth_data = ag_account_service_get_auth_data (account_service);
        g_object_unref (account_service);
    }
}

static void
ap_oauth_plugin_set_property (GObject *object, guint property_id,
                        const GValue *value, GParamSpec *pspec)
{
    ApOAuthPluginPrivate *priv = AP_OAUTH_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_OAUTH_PARAMS:
        g_assert (priv->oauth_params == NULL);
        priv->oauth_params = g_value_dup_boxed (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_oauth_plugin_get_property (GObject *object, guint property_id,
                        GValue *value, GParamSpec *pspec)
{
    ApOAuthPluginPrivate *priv = AP_OAUTH_PLUGIN_PRIV (object);

    switch (property_id)
    {
    case PROP_OAUTH_PARAMS:
        g_value_set_boxed (value, priv->oauth_params);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
ap_oauth_plugin_dispose (GObject *object)
{
    ApOAuthPluginPrivate *priv = AP_OAUTH_PLUGIN_PRIV (object);

    if (priv->account_oauth_params)
    {
        g_hash_table_unref (priv->account_oauth_params);
        priv->account_oauth_params = NULL;
    }

    if (priv->oauth_params)
    {
        g_hash_table_unref (priv->oauth_params);
        priv->oauth_params = NULL;
    }

    if (priv->auth_data)
    {
        ag_auth_data_unref (priv->auth_data);
        priv->auth_data = NULL;
    }

    if (priv->identity)
    {
        g_object_unref (priv->identity);
        priv->identity = NULL;
    }

    if (priv->auth_session)
    {
        g_object_unref (priv->auth_session);
        priv->auth_session = NULL;
    }

    if (priv->cancellable)
    {
        g_cancellable_cancel (priv->cancellable);
        g_object_unref (priv->cancellable);
        priv->cancellable = NULL;
    }

    if (priv->oauth_reply)
    {
        g_variant_unref (priv->oauth_reply);
        priv->oauth_reply = NULL;
    }

    g_clear_object (&priv->connection);

    G_OBJECT_CLASS (ap_oauth_plugin_parent_class)->dispose (object);
}

static GtkWidget *
build_widget_for_authentication (ApOAuthPlugin *self, gboolean new_account)
{
    GtkWidget *grid;
    GtkWidget *infobar;
    GtkWidget *socket_frame;
    GtkWidget *legal_button;

    grid = gtk_grid_new ();
    gtk_widget_set_hexpand (grid, TRUE);
    gtk_widget_set_vexpand (grid, TRUE);
    gtk_grid_set_row_spacing (GTK_GRID (grid), 12);
    gtk_orientable_set_orientation (GTK_ORIENTABLE (grid),
                                    GTK_ORIENTATION_VERTICAL);
    if (new_account)
    {
        g_signal_connect_swapped (grid, "map",
                                  G_CALLBACK (setup_authentication), self);
    }
    else
    {
        g_signal_connect_swapped (grid, "map",
                                  G_CALLBACK (setup_reauthentication), self);
    }

    infobar = create_infobar (self);
    gtk_container_add (GTK_CONTAINER (grid), infobar);

    socket_frame = create_socket_frame (self);
    gtk_container_add (GTK_CONTAINER (grid), socket_frame);

    legal_button = create_legal_button ();
    gtk_container_add (GTK_CONTAINER (grid), legal_button);

    return grid;
}

static GtkWidget *
ap_oauth_plugin_build_widget (ApPlugin *plugin)
{
    ApOAuthPlugin *self = AP_OAUTH_PLUGIN (plugin);
    AgAccount *account;

    account = ap_plugin_get_account (plugin);
    if (account->id == 0)
    {
        /* New account: provide UI to create it */
        return build_widget_for_authentication (self, TRUE);
    }
    else if (ap_plugin_get_need_authentication (plugin))
    {
        return build_widget_for_authentication (self, FALSE);
    }
    else
    {
        /* Editing an existing account: if the account needs some
         * configuration, it will be handled in the provider-specific subclass
         */
        return NULL;
    }
}

static void
ap_oauth_plugin_act_headless (ApPlugin *plugin)
{
    AgAccount *account;

    account = ap_plugin_get_account (plugin);
    if (account->id == 0)
    {
        /* New account: create it.
         * If the GtkSocket has not been prepared (and we don't prepare it, for
         * headless operations) then the authentication phase is skipped, and
         * we just store the settings into the account. */
        setup_authentication (AP_OAUTH_PLUGIN (plugin));
    }

    /* nothing to do for other operations */
}

static void
ap_oauth_plugin_class_init (ApOAuthPluginClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    ApPluginClass *plugin_class = AP_PLUGIN_CLASS (klass);

    g_type_class_add_private (object_class, sizeof (ApOAuthPluginPrivate));

    object_class->constructed = ap_oauth_plugin_constructed;
    object_class->set_property = ap_oauth_plugin_set_property;
    object_class->get_property = ap_oauth_plugin_get_property;
    object_class->dispose = ap_oauth_plugin_dispose;

    plugin_class->build_widget = ap_oauth_plugin_build_widget;
    plugin_class->act_headless = ap_oauth_plugin_act_headless;

    klass->query_username = _ap_oauth_plugin_query_username;
    /**
     * ApOAuthPlugin:oauth-params:
     *
     * A dictionary of OAuth parameters, to be used when authenticating an
     * account.
     */
    g_object_class_install_property
        (object_class, PROP_OAUTH_PARAMS,
         g_param_spec_boxed ("oauth-params", "Dictionary of OAuth parameters",
                             "A dictionary of OAuth parameters",
                             G_TYPE_HASH_TABLE,
                             G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY |
                             G_PARAM_STATIC_STRINGS));
}

/**
 * ap_oauth_plugin_set_oauth_parameters:
 * @self: the #ApOAuthPlugin.
 * @oauth_params: (element-type utf8 GValue): a dictionary of OAuth parameters.
 *
 * Sets the dictionary of OAuth parameters to be used when authenticating the
 * account. Note that these parameters are not stored in the account and will
 * be used only by the account plugin.
 * To set the authentication parameters used by applications, use
 * ap_oauth_plugin_set_account_oauth_parameters().
 */
void
ap_oauth_plugin_set_oauth_parameters (ApOAuthPlugin *self,
                                      GHashTable *oauth_params)
{
    g_return_if_fail (AP_IS_OAUTH_PLUGIN (self));
    g_return_if_fail (oauth_params != NULL);
    g_return_if_fail (self->priv->oauth_params == NULL);

    self->priv->oauth_params = g_hash_table_ref (oauth_params);
}

/**
 * ap_oauth_plugin_set_account_oauth_parameters:
 * @self: the #ApOAuthPlugin.
 * @oauth_params: (element-type utf8 GValue): a dictionary of OAuth parameters.
 *
 * Sets the dictionary of OAuth parameters to be used by client applications
 * when authenticating the account. These are the parameters which will be
 * stored into the account configuration (those used by the plugin itself when
 * authenticating are those set with ap_oauth_plugin_set_oauth_parameters()).
 */
void
ap_oauth_plugin_set_account_oauth_parameters (ApOAuthPlugin *self,
                                              GHashTable *oauth_params)
{
    g_return_if_fail (AP_IS_OAUTH_PLUGIN (self));
    g_return_if_fail (oauth_params != NULL);
    g_return_if_fail (self->priv->account_oauth_params == NULL);

    self->priv->account_oauth_params = g_hash_table_ref (oauth_params);
}

/**
 * ap_oauth_plugin_get_oauth_reply:
 * @self: the #ApOAuthPlugin.
 *
 * Get the authentication reply.
 *
 * Returns: (transfer none): the dictionary of OAuth reply parameters returned
 * by the authentication plugin.
 */
GVariant *
ap_oauth_plugin_get_oauth_reply (ApOAuthPlugin *self)
{
    g_return_val_if_fail (AP_IS_OAUTH_PLUGIN (self), NULL);

    return self->priv->oauth_reply;
}

/**
 * ap_oauth_plugin_set_mechanism:
 * @self: the #ApOAuthPlugin.
 * @mechanism: the desired OAuth mechanism.
 *
 * Set the OAuth mechanism to be used when authenticating the account.
 */
void ap_oauth_plugin_set_mechanism (ApOAuthPlugin *self,
                                    ApOAuthMechanism mechanism)
{
    g_return_if_fail (AP_IS_OAUTH_PLUGIN (self));
    g_return_if_fail (mechanism < AP_OAUTH_MECHANISM_LAST);
    self->priv->mechanism = oauth_mechanisms[mechanism];
}

#ifdef BUILDING_UNIT_TESTS
GVariant *prepare_session_data_test (ApOAuthPlugin *self);
GVariant *prepare_session_data_test (ApOAuthPlugin *self)
{
    return prepare_session_data (self);
}
#endif
