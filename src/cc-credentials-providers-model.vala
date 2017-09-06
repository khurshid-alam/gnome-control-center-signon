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

/**
 * Web credentials providers Gtk.ListStore. Used as a model for the providers
 * managed by libaccounts-glib.
 */
public class Cc.Credentials.ProvidersModel : Gtk.ListStore
{
    private Ag.Manager manager;

    /**
     * Identifiers for columns in the providers model.
     *
     * @param APPLICATION_NAME the name of the application, for passing to
     * Ag.Manager.get_application ()
     * @param APPLICATION_ICON the icon of the application
     * @param APPLICATION_DESCRIPTION the description of the application
     * @param PROVIDER_NAME the name of the provider, for passing to
     * Ag.Manager.get_provider ()
     * @param PROVIDER_ICON the icon of the account provider
     * @param PROVIDER_DESCRIPTION the description of the provider
     * @param TOOLTIP the tooltip to show for the row
     * @param ROW_SORT the sort priority of the row, with more negative numbers
     * being sorted first
     */
    public enum ModelColumns
    {
        APPLICATION_NAME = 0,
        APPLICATION_ICON = 1,
        APPLICATION_DESCRIPTION = 2,
        PROVIDER_NAME = 3,
        PROVIDER_ICON = 4,
        PROVIDER_DESCRIPTION = 5,
        TOOLTIP = 6,
        ROW_SORT = 7
    }

    /**
     * Create a new data model for the list of providers.
     */
    public ProvidersModel ()
    {
        Object ();
    }

    construct
    {
        Type[] types = { typeof (string), typeof (Icon), typeof (string),
                         typeof (string), typeof (Icon), typeof (string),
                         typeof (string), typeof (int) };
        set_column_types (types);

        // TODO: Use the same Ag.Manager throughout.
        manager = new Ag.Manager ();

        populate_model ();

        set_sort_column_id (ModelColumns.ROW_SORT, Gtk.SortType.ASCENDING);
        // FIXME: No notification signals for adding new providers.
    }

    /**
     * Populate the model with the current list of providers and associated
     * application, by querying for available services and then listing the
     * applications available for each service.
     */
    private void populate_model ()
    {
        var services = manager.list_services ();
        var providers = manager.list_providers ();

        // Add list of providers with unfilled application fields.
        providers.foreach (add_provider);

        foreach (var service in services)
        {
            var applications = manager.list_applications_by_service (service);
            var provider_name = service.get_provider ();
            var provider = manager.get_provider (provider_name);
            if (provider == null) continue;

            foreach (var application in applications)
            {
                var desktop_info = application.get_desktop_app_info ();
                var application_name = application.get_name ();

                Icon app_icon = null;
                string application_description = "";

                if (desktop_info == null)
                {
                    message ("No desktop app info found for application name: %s",
                             application_name);
                }
                else
                {
                    // Load a themed application icon.
                    app_icon = desktop_info.get_icon ();

                    application_description = desktop_info.get_display_name ()
                                              + "\n<small>"
                                              + desktop_info.get_description ()
                                              + "</small>";
                }


                // Load a themed provider icon.
                Icon provider_icon = null;

                try
                {
                    provider_icon = Icon.new_for_string (provider.get_icon_name ());
                }
                catch (Error error)
                {
                    message ("Failed to load provider icon: %s",
                             error.message);
                }

                // Determine the sort order.
                int sort_order;

                if (application_name == "gwibber")
                    sort_order = determine_sort_order_gwibber (provider_name);
                else if (application_name == "empathy")
                    sort_order = determine_sort_order_empathy (provider_name);
                else if (application_name == "shotwell")
                    sort_order = determine_sort_order_shotwell (provider_name);
                else if (application_name == "thunderbird")
                    sort_order = determine_sort_order_thunderbird (provider_name);
                else
                    sort_order = determine_sort_order_dash (provider_name);

                insert_with_values (null, 0,
                                    ModelColumns.APPLICATION_NAME, application.get_name (),
                                    ModelColumns.APPLICATION_ICON, app_icon,
                                    ModelColumns.APPLICATION_DESCRIPTION, application_description,
                                    ModelColumns.PROVIDER_NAME, provider.get_name (),
                                    ModelColumns.PROVIDER_ICON, provider_icon,
                                    ModelColumns.PROVIDER_DESCRIPTION, format_provider_description (provider),
                                    ModelColumns.TOOLTIP, format_provider_tooltip (provider),
                                    ModelColumns.ROW_SORT, sort_order,
                                    -1);
            }
        }
    }

    /**
     * Add the supplied provider to the store of providers.
     *
     * This method is intended to be used with the foreach method of GLib
     * containers.
     *
     * @param provider an Ag.Provider to add to the list of providers
     */
    private void add_provider (Ag.Provider provider)
    {
        Icon provider_icon = null;

        if (!Ap.client_has_plugin (provider))
            return;

        try
        {
            provider_icon = Icon.new_for_string (provider.get_icon_name ());
        }
        catch (Error error)
        {
            message ("Failed to load provider icon: %s", error.message);
        }

        // Determine the sort order.
        var provider_name = provider.get_name ();
        var sort_order = determine_sort_order_dash (provider_name);

        insert_with_values (null, 0,
                            ModelColumns.APPLICATION_NAME, "all",
                            ModelColumns.PROVIDER_NAME, provider_name,
                            ModelColumns.PROVIDER_ICON, provider_icon,
                            ModelColumns.PROVIDER_DESCRIPTION, format_provider_description (provider),
                            ModelColumns.TOOLTIP, format_provider_tooltip (provider),
                            ModelColumns.ROW_SORT, sort_order,
                            -1);
    }

    /**
     * Determine the sort order for service providers for an unspecified
     * application, or the dash, given a provider name.
     *
     * @param provider_name the provider name
     * @return the sort order, with a more negative number coming before others
     */
    private int determine_sort_order_dash (string provider_name)
    {
        if (provider_name == "facebook")
            return -5;
        else if (provider_name == "flickr")
            return -4;
        else if (provider_name == "google")
            return -3;
        else if (provider_name == "twitter")
            return -2;
        else
            return 0;
    }

    /**
     * Determine the sort order for service providers for Gwibber, given a
     * provider name.
     *
     * @param provider_name the provider name
     * @return the sort order, with a more negative number coming before others
     */
    private int determine_sort_order_gwibber (string provider_name)
    {
        if (provider_name == "facebook")
            return -5;
        else if (provider_name == "google")
            return -4;
        else if (provider_name == "identica")
            return -3;
        else if (provider_name == "twitter")
            return -2;
        else
            return 0;
    }

    /**
     * Determine the sort order for service providers for Empathy, given a
     * provider name.
     *
     * @param provider_name the provider name
     * @return the sort order, with a more negative number coming before others
     */
    private int determine_sort_order_empathy (string provider_name)
    {
        if (provider_name == "salut")
            return -5;
        else if (provider_name == "facebook")
            return -4;
        else if (provider_name == "google")
            return -3;
        else
            return 0;
    }

    /**
     * Determine the sort order for service providers for Shotwell, given a
     * provider name.
     *
     * @param provider_name the provider name
     * @return the sort order, with a more negative number coming before others
     */
    private int determine_sort_order_shotwell (string provider_name)
    {
        if (provider_name == "facebook")
            return -5;
        else if (provider_name == "flickr")
            return -4;
        else if (provider_name == "google")
            return -3;
        else
            return 0;
    }

    /**
     * Determine the sort order for service providers for Thunderbird, given a
     * provider name.
     *
     * @param provider_name the provider name
     * @return the sort order, with a more negative number coming before others
     */
    private int determine_sort_order_thunderbird (string provider_name)
    {
        if (provider_name == "google")
            return -5;
        else if (provider_name == "yahoo")
            return -4;
        else
            return 0;
    }

    /**
     * Provide a Pango-markup description of the provider for adding to the
     * model.
     *
     * Add a second line of descriptive text if the provider supplies a
     * description.
     *
     * @param provider the provider to add
     * @return the description, with Pango markup
     */
    private string format_provider_description (Ag.Provider provider)
    {
        var description = provider.get_description ();
        string provider_description;
        if (description == null)
        {
            provider_description = dgettext (provider.get_i18n_domain (),
                                             provider.get_display_name ());
        }
        else
        {
            provider_description = dgettext (provider.get_i18n_domain (),
                                             provider.get_display_name ())
                                   + "\n"
                                   + "<small>"
                                   + dgettext (provider.get_i18n_domain (),
                                               description)
                                   + "</small>";
        }

        return provider_description;
    }

    /**
     * Provider a description for the tooltip for each provider, for display
     * when hovering over a row in the tree view.
     *
     * @param provider the provider for which to create tooltip text
     * @return the tooltip text
     */
    private string format_provider_tooltip (Ag.Provider provider)
    {
        return _("Select to configure a new %s account").printf (provider.get_display_name ());
    }
}
