/*
 * Copyright 2012 Canonical Ltd.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *      Alberto Mardegan <alberto.mardegan@canonical.com>
 */

#include <glib.h>
#include <libaccounts-glib/ag-account.h>
#include <libaccounts-glib/ag-manager.h>
#include <stdlib.h>

/* Check if new services have been installed for this account and, if so,
 * enable them. */
static void
update_account (AgAccount *account, GError **error)
{
    GList *service_list, *iter;
    gboolean account_changed = FALSE;

    service_list = ag_account_list_services (account);
    for (iter = service_list; iter != NULL; iter = g_list_next (iter))
    {
        AgService *service = iter->data;
        AgSettingSource from;

        ag_account_select_service (account, service);

        /* To determine whether the service is new, we retrieve the "enabled"
         * flag as a setting: if it comes from the account, then the service
         * has been previously used on this account; otherwise, it's a new
         * service and we should enable it. */
        ag_account_get_variant (account, "enabled", &from);
        if (from != AG_SETTING_SOURCE_ACCOUNT)
        {
            ag_account_set_enabled (account, TRUE);
            account_changed = TRUE;
        }
    }

    if (account_changed)
    {
        ag_account_store_blocking (account, error);
    }
}

int
main (int argc, char **argv)
{
    AgManager *manager;
    GList *account_list, *iter;

#if !GLIB_CHECK_VERSION (2, 35, 1)
    g_type_init ();
#endif

    manager = ag_manager_new ();
    account_list = ag_manager_list (manager);

    for (iter = account_list; iter != NULL; iter = g_list_next (iter))
    {
        AgAccountId account_id;
        AgAccount *account;
        GError *error = NULL;

        account_id = GPOINTER_TO_UINT (iter->data);
        account = ag_manager_load_account (manager, account_id, &error);
        if (G_UNLIKELY (error != NULL))
        {
            g_warning ("Could not load account %d: %s",
                       account_id, error->message);
            g_clear_error (&error);
            continue;
        }

        update_account (account, &error);
        if (G_UNLIKELY (error != NULL))
        {
            g_warning ("Could not update account %d: %s",
                       account_id, error->message);
            g_clear_error (&error);
            continue;
        }
    }

    ag_manager_list_free (account_list);
    g_object_unref (manager);

    return EXIT_SUCCESS;
}
