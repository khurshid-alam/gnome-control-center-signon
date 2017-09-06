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
 *      David King <david.king@canonical.com>
 */

namespace Cc.Credentials
{
    /**
     * An individual application associated with an account.
     *
     * @param name the name, as supplied to Ag.Manager.get_provider ()
     * @param icon the icon of the application
     * @param description the description of the application
     * @param plugin the plugin to configure account options, if any
     * @param plugin_widget the widget to show when configuring account options
     * @param service_name the service name, as supplied to
     * Ag.Manager.get_service ()
     */
    public struct AccountApplicationRow
    {
        public string name;
        public Icon icon;
        public string description;
        public Ap.ApplicationPlugin plugin;
        public Gtk.Widget plugin_widget;
        public string service_name;
    }
}

/**
 * Web credentials account applications model. Used to store details about
 * applications that can be integrated with an account, to be used in creating
 * widgets in a grid for describing the applications.
 */
public class Cc.Credentials.AccountApplicationsModel : Object
{
    private Ag.Manager manager;
    private Ag.Account current_account;
    public List<AccountApplicationRow?> application_rows;

    /**
     * Update the model when the current account changes.
     */
    public Ag.Account account
    {
        get
        {
            return current_account;
        }
        set
        {
            /* Skip clearing and repopulating the model if the account has not
             * changed.
             */
            if (value == current_account)
            {
                return;
            }

            current_account = value;

            // Empty the model and repopulate it.
            application_rows = new List <AccountApplicationRow?>();
            populate_model ();
        }
    }

    /**
     * Create a new model for storing applications that can be used with an
     * account.
     *
     * @param widget a Gtk.Widget to be used for looking up themed icons
     */
    public AccountApplicationsModel ()
    {
        manager = new Ag.Manager ();
    }

    /**
     * Populate the model with a list of applications that can use the services
     * of the current account.
     */
    private void populate_model ()
    {
        var services = current_account.list_services ();
        var service_application = new HashTable<string, Ag.Application?> (str_hash,
                                                                          null);
        foreach (var service in services)
        {
            var applications = manager.list_applications_by_service (service);
            foreach (var application in applications)
            {
                service_application.insert (service.get_name (), application);
            }
        }

        service_application.foreach (add_application);

        // Reverse the list, as it was prepended to for efficiency.
        application_rows.reverse ();
    }

    /**
     * Add a single application to the model.
     *
     * @param service_name the name of the Ag.Service
     * @param application the Ag.Application to add to the model
     */
    private void add_application (string service_name,
                                  Ag.Application? application)
    {
        var desktop_info = application.get_desktop_app_info ();
        if (desktop_info == null)
        {
            message ("No desktop app info found for application name: %s",
                     application.get_name ());
            return;
        }

        // Load a themed application icon.
        var app_icon = desktop_info.get_icon ();

        var service = manager.get_service (service_name);

        var app_description = dgettext (application.get_i18n_domain (),
                                        application.get_description ());
        var app_service_usage = dgettext (application.get_i18n_domain (),
                                          application.get_service_usage (service));
        var description_markup = app_description
                                 + "\n<small>"
                                 + app_service_usage
                                 + "</small>";

        var app_plugin = Ap.client_load_application_plugin (application,
                                                            current_account);
        Gtk.Widget app_plugin_widget = null;
        if (app_plugin == null)
        {
            /* There might not be a plugin (for OAuth accounts, or if there are
             * no settings).
             */
            message ("No valid plugin found for application '%s' with account '%u'",
                     application.get_name (),
                     current_account.id);
        }
        else
        {
            app_plugin_widget = app_plugin.build_widget ();
        }

        var application_row = AccountApplicationRow ()
        {
            name = application.get_name (),
            icon = app_icon,
            description = description_markup,
            plugin = app_plugin,
            plugin_widget = app_plugin_widget,
            service_name = service_name
        };

        application_rows.prepend (application_row);
    }
}
