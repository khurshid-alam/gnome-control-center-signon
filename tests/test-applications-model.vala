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

    Test.add_func ("/credentials/applicationsmodel/create", applicationsmodel_create);

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void applicationsmodel_create ()
{
    var treeview = Gtk.test_create_widget (typeof (Gtk.TreeView)) as Gtk.TreeView;
    var applications_model = new Cc.Credentials.ApplicationsModel ();

    treeview.model = applications_model;
}
