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

int main (string[] args)
{
    Gtk.test_init (ref args);

    /* Skip until a mock webcredentials indicator is developed.
    Test.add_func ("/credentials/accountdetailspage/create", accountdetailspage_create);
    Test.add_func ("/credentials/accountdetailspage/set_account", accountdetailspage_set_get_account);
    */

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void accountdetailspage_create ()
{
    var accounts_model = new Cc.Credentials.AccountsModel ();

    // Instantiate by calling g_object_new () on the type.
    var page = Gtk.test_create_widget (typeof (Cc.Credentials.AccountDetailsPage));

    // Instantiate by calling cc_credentials_accounts_details_page_new ().
    var other_page = new Cc.Credentials.AccountDetailsPage (accounts_model);
}

void accountdetailspage_set_get_account ()
{
    var accounts_model = new Cc.Credentials.AccountsModel ();

    var page = new Cc.Credentials.AccountDetailsPage (accounts_model);

    var manager = accounts_model.manager;

    // Make sure that at least one account exists.
    var account = manager.create_account ("MyProvider");

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }

    /* prevent warnings from making the test fail */
    Test.log_set_fatal_handler (log_is_fatal);

    page.account = account;

    assert (page.account == account);
}

bool log_is_fatal (string? log_domain, LogLevelFlags log_levels, string message)
{
    return (log_levels & (LogLevelFlags.LEVEL_CRITICAL |
                          LogLevelFlags.LEVEL_ERROR)) != 0;
}
