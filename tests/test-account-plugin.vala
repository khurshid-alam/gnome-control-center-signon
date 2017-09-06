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

extern GLib.Variant prepare_session_data_test (Ap.OAuthPlugin self);

public class TestPlugin : Ap.Plugin {
    public Gtk.Widget widget_to_build;

    public TestPlugin(Ag.Account account) {
        Object(account: account);
    }

    public override unowned Gtk.Widget build_widget () {
        return widget_to_build;
    }
}

public class TestOAuthPlugin : Ap.OAuthPlugin {
    public TestOAuthPlugin(Ag.Account account) {
        Object(account: account);
    }

    construct {
        var account_oauth_params =
            new HashTable<string, GLib.Value?> (str_hash, null);
        account_oauth_params.insert ("long", "short");
        account_oauth_params.insert ("wide", "narrow");
        set_account_oauth_parameters (account_oauth_params);

        var oauth_params = new HashTable<string, GLib.Value?> (str_hash, null);
        oauth_params.insert ("long", "not short");
        oauth_params.insert ("wide", "not narrow");
        set_oauth_parameters (oauth_params);
    }
}

public class TestApplicationPlugin : Ap.ApplicationPlugin {
    public Gtk.Widget widget_to_build;

    public TestApplicationPlugin(Ag.Application application,
                                 Ag.Account account) {
        Object(account: account, application: application);
    }

    public override unowned Gtk.Widget build_widget () {
        return widget_to_build;
    }
}

int main (string[] args)
{
    Gtk.test_init (ref args);

    Test.add_func ("/libaccount-plugin/client/load_plugin/null",
                   client_load_plugin_null);
    Test.add_func ("/libaccount-plugin/client/load_application_plugin/null",
                   client_load_application_plugin_null);
    Test.add_func ("/libaccount-plugin/plugin/create", accountplugin_create);
    Test.add_func ("/libaccount-plugin/plugin/create-headless",
                   accountplugin_create_headless);
    Test.add_func ("/libaccount-plugin/application-plugin/create",
                   applicationplugin_create);
    Test.add_func ("/libaccount-plugin/oauth-plugin/params",
                   oauthplugin_params);

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void client_load_plugin_null ()
{
    Test.log_set_fatal_handler (log_is_fatal);

    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    var plugin = Ap.client_load_plugin (account);
    assert (plugin == null);
}

void client_load_application_plugin_null ()
{
    Test.log_set_fatal_handler (log_is_fatal);

    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");
    var application = manager.get_application ("Gallery");

    var plugin = Ap.client_load_application_plugin (application, account);
    assert (plugin == null);
}

void accountplugin_create ()
{
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    var plugin = new TestPlugin (account);

    assert (plugin.account == account);
    assert (plugin.get_account () == account);

    plugin.need_authentication = true;
    assert (plugin.need_authentication == true);
    assert (plugin.get_need_authentication () == true);

    /* Make sure that the virtual method is called */
    plugin.widget_to_build = new Gtk.Label ("Hello world!");
    assert (plugin.build_widget () == plugin.widget_to_build);
}

void accountplugin_create_headless ()
{
    /* Making warnings non-fatal is needed because at-spi2 emits a g_warning
     * ("AT-SPI: Could not obtain desktop path or name") which we couldn't find
     * a way to remove. Any hint on how to avoid that warning (or even on
     * avoiding starting up at-spi2 in the first place) is very welcome. */
    Test.log_set_fatal_handler (log_is_fatal);

    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    var plugin = new TestOAuthPlugin (account);

    assert (plugin.account == account);
    assert (plugin.get_account () == account);

    string test_username = "Long John Silver";

    plugin.need_authentication = false;
    plugin.set_credentials (test_username, "irrelevant password");

    var main_loop = new GLib.MainLoop (null, false);

    plugin.finished.connect (() => {
        main_loop.quit ();
    });
    GLib.Idle.add (() => {
        plugin.act_headless ();
        return false;
    });

    main_loop.run ();

    /* check that the account was stored */
    assert (account.id != 0);

    assert (account.get_display_name () == test_username);

    /* The accounts created in headless mode must be disabled */
    account.select_service (null);
    assert (!account.get_enabled ());

    var service = manager.get_service ("MyService");
    var account_service = new Ag.AccountService (account, service);
    var auth_data = account_service.get_auth_data ();

    assert (auth_data.get_method () == "oauth2");
    assert (auth_data.get_mechanism () == "user_agent");

    var parameters = auth_data.get_parameters ();
    assert (parameters["long"].get_string () == "short");
    assert (parameters["wide"].get_string () == "narrow");

    /* delete the account */
    GLib.Idle.add (() => {
        plugin.delete_account.begin ((obj, res) => {
            try
            {
                plugin.delete_account.end (res);
            }
            catch (Error error)
            {
                critical ("Error deleting account: %s", error.message);
                assert_not_reached ();
            }
            main_loop.quit ();
        });
        return false;
    });

    main_loop.run ();
}

void applicationplugin_create ()
{
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");
    var application = manager.get_application ("Gallery");
    assert (application != null);

    var plugin = new TestApplicationPlugin (application, account);

    assert (plugin.account == account);
    assert (plugin.get_account () == account);
    assert (plugin.application == application);
    assert (plugin.get_application () == application);

    /* Make sure that the virtual method is called */
    plugin.widget_to_build = new Gtk.Label ("Hello world!");
    assert (plugin.build_widget () == plugin.widget_to_build);
}

void oauthplugin_params ()
{
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    var plugin = new TestOAuthPlugin (account);

    plugin.need_authentication = false;

    var cookies =
        new HashTable<string, string> (str_hash, str_equal);
    cookies.insert("first cookie", "KEY=VALUE");
    cookies.insert("second", "SILLY=TRUE");
    plugin.set_cookies (cookies);

    var session_data = prepare_session_data_test (plugin);
    assert (session_data != null);
    assert (session_data.n_children() == 4);
    assert (session_data.lookup_value ("long", null).get_string () ==
            "not short");
    assert (session_data.lookup_value ("wide", null).get_string () ==
            "not narrow");
    assert (session_data.lookup_value ("medium", null).get_string () ==
            "like this");

    var cookies_variant = session_data.lookup_value ("Cookies", null);
    assert (cookies_variant != null);
    assert (cookies_variant.n_children() == 2);
    assert (cookies_variant.lookup_value ("second", null).get_string() ==
            "SILLY=TRUE");
}

bool log_is_fatal (string? log_domain, LogLevelFlags log_level, string message)
{
    return (log_level & (LogLevelFlags.LEVEL_CRITICAL |
                         LogLevelFlags.LEVEL_ERROR)) != 0;
}
