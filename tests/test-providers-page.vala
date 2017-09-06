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

    Test.add_func ("/credentials/providerspage/create", providerspage_create);

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void providerspage_create ()
{
    // Instantiate by calling g_object_new () on the type.
    var page = Gtk.test_create_widget (typeof (Cc.Credentials.ProvidersPage));

    // Instantiate by calling cc_credentials_accounts_details_page_new ().
    var other_page = new Cc.Credentials.ProvidersPage ();
}