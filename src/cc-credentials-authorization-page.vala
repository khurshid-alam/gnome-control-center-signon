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
 * Web credentials authorization page. This is designed to take the full width
 * of the parent widget, for display of an authorization widget, such as a
 * WebKit view.
 */
public class Cc.Credentials.AuthorizationPage : Gtk.Grid
{
    private Ap.Plugin plugin;
    private weak Gtk.Widget widget;
    private Ag.Account current_account;
    private WebcredentialsIndicator indicator;
    private bool needs_reauthentication = false;

    /**
     * Emitted when the authorization process was cancelled.
     */
    public signal void cancelled ();

    /**
     * Keep the UI state consistent when the account is changed.
     */
    public Ag.Account account
    {
        get
        {
            return current_account;
        }
        set
        {
            current_account = value;

            plugin = Ap.client_load_plugin (account);
            if (plugin == null)
            {
                critical ("No valid plugin found for provider %s",
                          value.get_provider_name ());
                return;
            }

            plugin.finished.connect (on_plugin_finished);

            if (needs_reauthentication)
            {
                plugin.need_authentication = true;
            }

            var plugin_widget = plugin.build_widget ();

            if (plugin_widget != null)
            {
                set_plugin_widget (plugin.build_widget ());
            }
            else
            {
                critical ("Plugin failed to build widget for account ID: %u",
                          value.id);
                return;
            }
        }
    }

    public AuthorizationPage ()
    {
        Object ();
    }

    construct
    {
        expand = true;
        orientation = Gtk.Orientation.VERTICAL;

        try
        {
            indicator = Bus.get_proxy_sync (BusType.SESSION,
                                            "com.canonical.indicators.webcredentials",
                                            "/com/canonical/indicators/webcredentials");
        }
        catch (IOError err)
        {
            warning ("Error initializing indicator proxy: %s\nAccount attention notifications will not function", err.message);
        }

        show ();
    }

    /**
     * Trigger a re-authentication with the supplied account.
     *
     * @param account the account to re-authenticate
     */
    public void reauthenticate_account (Ag.Account account)
    {
        needs_reauthentication = true;
        this.account = account;
    }

    /**
     * Set the login data that the plugin might use while performing the
     * authentication.
     *
     * @param username the user login name.
     * @param password the user password.
     * @param cookies a dictionary of cookies.
     */
    public void set_login_data (string username,
                                string? password,
                                HashTable<string,string>? cookies)
    {
        plugin.set_credentials (username, password);
        if (cookies != null)
        {
            plugin.set_cookies (cookies);
        }
    }

    /**
     * Set a plugin widget and show it, removing the old widget if necessary.
     *
     * @param plugin_widget the Gtk.Widget to set as the new plugin widget
     */
    private void set_plugin_widget (Gtk.Widget plugin_widget)
    {
        remove_plugin_widget ();

        widget = plugin_widget;

        widget.show ();
        this.add (widget);
    }

    /**
     * Remove the plugin widget.
     */
    private void remove_plugin_widget ()
    {
        if (widget != null)
        {
            this.remove (widget);
            widget = null;
        }
    }

    /**
     * Handle the "finished" signal from the plugin. 
     */
    private void on_plugin_finished ()
    {
        var user_cancelled = plugin.get_user_cancelled ();
        var plugin_err = plugin.get_error ();
        remove_plugin_widget ();
        plugin = null;

        if (user_cancelled)
        {
            cancelled ();
        }
        else
        {
            /* TODO handle normal termination and improve handling of
             * termination with error */
            if (plugin_err != null)
            {
                critical ("Error completing auth session process: %s",
                          plugin_err.message);
            }
            else
            {
                // TODO: Can this be called unconditionally?
                indicator.remove_failures ( {current_account.id} );
                indicator.clear_error_status ();
            }

            cancelled ();
        }
    }
}
