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
    Test.add_func ("/credentials/accountsmodel/create", accountsmodel_create);
    Test.add_func ("/credentials/accountsmodel/add_account", accountsmodel_add_account);
    Test.add_func ("/credentials/accountsmodel/toggle_account_enabled", accountsmodel_toggle_account_enabled);
    Test.add_func ("/credentials/accountsmodel/delete_account", accountsmodel_delete_account);
    */

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void accountsmodel_create ()
{
    var treeview = Gtk.test_create_widget (typeof (Gtk.TreeView)) as Gtk.TreeView;

    var accounts_model = new Cc.Credentials.AccountsModel ();
    treeview.model = accounts_model;
}

void accountsmodel_add_account ()
{
    var treeview = Gtk.test_create_widget (typeof (Gtk.TreeView)) as Gtk.TreeView;
    var accounts_model = new Cc.Credentials.AccountsModel ();

    treeview.model = accounts_model;

    // Add an account.
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }
}

void accountsmodel_toggle_account_enabled ()
{
    var treeview = Gtk.test_create_widget (typeof (Gtk.TreeView)) as Gtk.TreeView;
    var accounts_model = new Cc.Credentials.AccountsModel ();

    treeview.model = accounts_model;

    // Update an existing account (by adding one first).
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }

    account.set_enabled (!account.get_enabled ());

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }
}

void accountsmodel_delete_account ()
{
    var treeview = Gtk.test_create_widget (typeof (Gtk.TreeView)) as Gtk.TreeView;
    var accounts_model = new Cc.Credentials.AccountsModel ();

    treeview.model = accounts_model;

    // Delete an existing account (by adding one first).
    var manager = new Ag.Manager ();
    var account = manager.create_account ("MyProvider");

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }

    account.delete ();

    try
    {
        account.store_blocking ();
    }
    catch (Error error)
    {
        assert_not_reached ();
    }
}
