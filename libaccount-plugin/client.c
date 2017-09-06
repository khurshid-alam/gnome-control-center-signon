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
 * SECTION:ap-client
 * @short_description: Load account and application plugins.
 * @include: libaccount-plugin/client.h
 *
 * Load an #ApApplicationPlugin or #ApPlugin.
 */

#include "application-plugin.h"
#include "client.h"
#include "plugin.h"

#include <gmodule.h>
#include <libaccounts-glib/ag-manager.h>
#include <libaccounts-glib/ag-provider.h>

static gchar *
get_module_path (AgProvider *provider)
{
    const gchar *plugin_name;
    const gchar *plugin_dir;

    plugin_name = ag_provider_get_plugin_name (provider);
    if (plugin_name == NULL)
        plugin_name = ag_provider_get_name (provider);

    plugin_dir = g_getenv ("AP_PROVIDER_PLUGIN_DIR");
    if (plugin_dir == NULL)
        plugin_dir = LIBACCOUNT_PLUGIN_DIR "/providers";

    return g_module_build_path (plugin_dir, plugin_name);
}

/**
 * ap_client_load_plugin:
 * @account: the #AgAccount to be created/edited.
 *
 * Load the account plugin for @account.
 *
 * Returns: (transfer full): a new #ApPlugin if a valid plugin was found, %NULL
 * otherwise.
 */
ApPlugin *
ap_client_load_plugin (AgAccount *account)
{
    const gchar *provider_name;
    gchar *module_path;
    AgManager *manager;
    AgProvider *provider;
    GModule *module;
    ApPlugin *plugin = NULL;
    gboolean ok;
    GType (*ap_module_get_object_type) (void);
    GType object_type;

    g_return_val_if_fail (AG_IS_ACCOUNT (account), NULL);

    provider_name = ag_account_get_provider_name (account);
    if (G_UNLIKELY (provider_name == NULL))
    {
        g_warning ("%s: account has no provider!", G_STRFUNC);
        return NULL;
    }

    manager = ag_account_get_manager (account);
    g_return_val_if_fail (AG_IS_MANAGER (manager), NULL);

    provider = ag_manager_get_provider (manager, provider_name);
    g_return_val_if_fail (provider != NULL, NULL);

    module_path = get_module_path (provider);
    module = g_module_open (module_path, 0);
    if (G_UNLIKELY (module == NULL))
    {
        g_warning ("%s: module %s not found: %s", G_STRFUNC, module_path,
                   g_module_error ());
        goto error;
    }

    ok = g_module_symbol (module, "ap_module_get_object_type",
                          (gpointer *)&ap_module_get_object_type);
    if (G_UNLIKELY (!ok || ap_module_get_object_type == NULL))
    {
        g_critical ("%s: module %s does not export ap_module_get_object_type",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    object_type = ap_module_get_object_type ();
    if (G_UNLIKELY (!G_TYPE_IS_OBJECT (object_type)))
    {
        g_critical ("%s: module %s does not create a valid GObject",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    plugin = g_object_new (object_type,
                           "account", account,
                           NULL);
    if (G_UNLIKELY (!AP_IS_PLUGIN (plugin)))
    {
        g_critical ("%s: module %s did not create a valid ApPlugin",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    /* Make sure that the module is not unloaded: the GType system doesn't
     * support that. */
    g_module_make_resident (module);

error:
    ag_provider_unref (provider);
    g_free (module_path);
    return plugin;
}

/**
 * ap_client_has_plugin:
 * @provider: the account provider.
 *
 * Checks if there is a valid account plugin for creating accounts having
 * @provider as provider.
 *
 * Returns: %TRUE if a plugin is found, %FALSE otherwise.
 */
gboolean
ap_client_has_plugin (AgProvider *provider)
{
    gchar *module_path;
    gboolean exists;

    module_path = get_module_path (provider);
    if (!module_path)
        return FALSE;

    exists = g_file_test (module_path, G_FILE_TEST_EXISTS);
    g_free (module_path);
    return exists;
}

/**
 * ap_client_load_application_plugin:
 * @application: the #AgApplication.
 * @account: the #AgAccount to be edited.
 *
 * Load the application plugin for editing the @application specific settings
 * of @account.
 *
 * Returns: (transfer full): a new #ApApplicationPlugin if a valid plugin was
 * found, %NULL otherwise.
 */
ApApplicationPlugin *
ap_client_load_application_plugin (AgApplication *application,
                                   AgAccount *account)
{
    const gchar *application_name;
    const gchar *plugin_dir;
    gchar *module_path;
    GModule *module;
    ApApplicationPlugin *plugin = NULL;
    gboolean ok;
    GType (*ap_module_get_object_type) (void);
    GType object_type;

    g_return_val_if_fail (AG_IS_ACCOUNT (account), NULL);

    application_name = ag_application_get_name (application);
    if (G_UNLIKELY (application_name == NULL))
    {
        g_warning ("%s: application has no name!", G_STRFUNC);
        return NULL;
    }

    plugin_dir = g_getenv ("AP_APPLICATION_PLUGIN_DIR");
    if (plugin_dir == NULL)
        plugin_dir = LIBACCOUNT_PLUGIN_DIR "/applications";

    module_path = g_module_build_path (plugin_dir, application_name);
    module = g_module_open (module_path, 0);
    if (module == NULL)
    {
        /* The absence of an application plugin is not an exceptional
         * condition; therefore, do not emit any warning here, but just return
         * quietly. */
        goto finish;
    }

    ok = g_module_symbol (module, "ap_module_get_object_type",
                          (gpointer *)&ap_module_get_object_type);
    if (G_UNLIKELY (!ok || ap_module_get_object_type == NULL))
    {
        g_critical ("%s: module %s does not export ap_module_get_object_type",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    object_type = ap_module_get_object_type ();
    if (G_UNLIKELY (!G_TYPE_IS_OBJECT (object_type)))
    {
        g_critical ("%s: module %s does not create a valid GObject",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    plugin = g_object_new (object_type,
                           "application", application,
                           "account", account,
                           NULL);
    if (G_UNLIKELY (!AP_IS_APPLICATION_PLUGIN (plugin)))
    {
        g_critical ("%s: module %s did not create a valid ApApplicationPlugin",
                    G_STRFUNC, module_path);
        g_module_close (module);
        goto error;
    }

    /* Make sure that the module is not unloaded: the GType system doesn't
     * support that. */
    g_module_make_resident (module);

error:
finish:
    g_free (module_path);
    return plugin;
}
