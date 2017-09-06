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
 * Web credentials preferences widget. This can be packed into the Unity
 * Control Center or used in a standalone application.
 */
public class Cc.Credentials.Preferences : Gtk.Notebook
{
    private AuthorizationPage authorization_page;
    private Ag.Manager accounts_manager;
    private LoginCapture login_capture;

    /* This must be a construct property so that is is called before the
     * construct block.
     */
    public uint account_details_id { get; construct; }
    public string application_id { get; construct; }

    /**
     * Select the desired page of @link Preferences to query the current
     * accounts and providers, or to authorize an account.
     *
     * @param ACCOUNTS select an account or provider in a two-pane view
     * @param AUTHORIZATION authorize an account in a full-size widget, such as
     * a WebKit view
     * @param ACCOUNT_OPTIONS set options on an account for either a specific
     * application or for the account globally
     */
    private enum PreferencesPage
    {
        ACCOUNTS = 0,
        AUTHORIZATION = 1,
        ACCOUNT_OPTIONS = 2,
    }

    public Preferences ()
    {
        Object ();
    }

    public Preferences.with_account_details (Ag.AccountId account_id)
    {
        Object (account_details_id: account_id);
    }

    public Preferences.with_application (string application)
    {
        Object (application_id: application);
    }

    construct
    {
        show_tabs = false;
        show_border = false;
        expand = true;
        border_width = 18;

        accounts_manager = new Ag.Manager ();

        /* invoke the update-accounts tool to enable any newly installed
         * services on the existing accounts.
         * We are doing this after initializing our own Ag.Manager in order to
         * avoid being slowed down due to any possible locking issues.
         */
        try
        {
            DesktopAppInfo appInfo =
                new DesktopAppInfo ("update-accounts.desktop");
            appInfo.launch (null, null);
        }
        catch (Error e)
        {
            warning ("Error launching update-accounts tool: %s", e.message);
        }

        AccountsPage accounts_page;

        if (account_details_id != 0)
        {
            accounts_page = new AccountsPage.with_account_details (account_details_id);
        }
        else if (application_id != null)
        {
            accounts_page = new AccountsPage.with_application (application_id);
        }
        else
        {
            accounts_page = new AccountsPage ();
        }

        accounts_page.new_account_request.connect (on_accounts_page_new_account_request);
        accounts_page.reauthenticate_account_request.connect (on_accounts_page_reauthenticate_account_request);
        accounts_page.account_options_request.connect (on_accounts_page_account_options_request);
        accounts_page.account_edit_options_request.connect (on_accounts_page_account_edit_options_request);

        this.append_page (accounts_page);

        authorization_page = new AuthorizationPage ();
        authorization_page.cancelled.connect (on_authorization_page_cancelled);

        this.append_page (authorization_page);

        set_current_page (PreferencesPage.ACCOUNTS);

        set_size_request (-1, 400);

        show ();

        login_capture = new LoginCapture ();
        login_capture.new_account_request.connect (
                                        on_login_capture_new_account_request);
    }

    /**
     * Handle the new-account-request signal from LoginCapture, switching
     * notebook page to the new account view.
     *
     * @param provider_name the name of the provider for which to add an
     * account.
     * @param username the user login name.
     * @param password the user password.
     * @param cookies a dictionary of cookies.
     */
    private void on_login_capture_new_account_request (string provider_name,
                                                       string username,
                                                       string? password,
                                           HashTable<string,string> cookies)
    {
        var account = accounts_manager.create_account (provider_name);
        authorization_page.account = account;
        authorization_page.set_login_data (username, password, cookies);
        set_current_page (PreferencesPage.AUTHORIZATION);
    }

    /**
     * Handle the new-account-request signal from AccountsPage (and in turn
     * ProvidersPage), switching notebook page to the new account view.
     *
     * @param provider_name the name of the provider for which to add an
     * account
     */
    private void on_accounts_page_new_account_request (string provider_name)
    {
        var account = accounts_manager.create_account (provider_name);
        authorization_page.account = account;
        set_current_page (PreferencesPage.AUTHORIZATION);
    }

    /**
     * Handle the reauthenticate-account-request signal from AccountsPage (and
     * in turn AccountDetailsPage), switching notebook page to the account
     * authentication view.
     *
     * @param account the account to authenticate
     */
    private void on_accounts_page_reauthenticate_account_request (Ag.Account account)
    {
        authorization_page.reauthenticate_account (account);
        set_current_page (PreferencesPage.AUTHORIZATION);
    }

    /**
     * Handle the authorization process for a new account being cancelled,
     * switching the current notebook page to the provider selection view.
     */
    private void on_authorization_page_cancelled ()
    {
        set_current_page (PreferencesPage.ACCOUNTS);
    }

    /**
     * Handle the account-options-request signal from AccountsPage (and in turn
     * AccountDetailsPage), switching notebook page to the application account
     * options view.
     *
     * @param application_row the AccountApplicationRow to show options for
     */
    private void on_accounts_page_account_options_request (AccountApplicationRow application_row)
    {
        assert (application_row.plugin_widget != null);

        this.append_page (application_row.plugin_widget);
        application_row.plugin.finished.connect (on_account_application_options_finished);

        set_current_page (PreferencesPage.ACCOUNT_OPTIONS);
    }

    /**
     * Handle the account options editing process finishing, and switch back to
     * the accounts view.
     *
     * @param plugin the plugin that emitted the finished signal
     */
    private void on_account_application_options_finished (Ap.ApplicationPlugin plugin)
    {
        var plugin_err = plugin.get_error ();
        if (plugin_err != null)
        {
            warning ("Error during account application options process: %s",
                     plugin_err.message);
        }

        this.remove_page (PreferencesPage.ACCOUNT_OPTIONS);
        set_current_page (PreferencesPage.ACCOUNTS);
    }

    /**
     * Handle the account-edit-options-request signal from AccountsPage (and ini
     * turn AccountDetailsPage), switching notebook page to the application
     * account options view.
     *
     * @param application_row the AccountApplicationRow to show options for
     */
    private void on_accounts_page_account_edit_options_request (Ap.Plugin plugin)
    {
        var widget = plugin.build_widget ();

        if (widget == null)
        {
            critical ("Error building configuration widget");
            return;
        }

        widget.show ();
        this.append_page (widget);
        plugin.finished.connect (on_account_edit_options_finished);

        set_current_page (PreferencesPage.ACCOUNT_OPTIONS);
    }

    /**
     * Handle the account options editing process finishing, and switch back to
     * the accounts view.
     *
     * @param plugin the plugin that emitted the finished signal
     */
    private void on_account_edit_options_finished (Ap.Plugin plugin)
    {
        var plugin_err = plugin.get_error ();
        if (plugin_err != null)
        {
            warning ("Error during account edit options process: %s",
                     plugin_err.message);
        }

        this.remove_page (PreferencesPage.ACCOUNT_OPTIONS);
        set_current_page (PreferencesPage.ACCOUNTS);
    }
}
