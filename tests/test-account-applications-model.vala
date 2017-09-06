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

    Test.add_func ("/credentials/accountapplicationsmodel/create", accountapplicationsmodel_create);
    Test.add_func ("/credentials/accountapplicationsmodel/add_account", accountapplicationsmodel_add_account);

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void accountapplicationsmodel_create ()
{
    var accountapplications_model = new Cc.Credentials.AccountApplicationsModel ();
}

void accountapplicationsmodel_add_account ()
{
    var accountapplications_model = new Cc.Credentials.AccountApplicationsModel ();

    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    try
    {
        account.store_blocking ();
    }
    catch (Error err)
    {
        error ("Failed to store new account: %s", err.message);
    }

    accountapplications_model.account = account;
}
