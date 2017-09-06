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
    Test.add_func ("/credentials/preferences/create", preferences_create);
    */

    Test.run ();

    return Posix.EXIT_SUCCESS;
}

void preferences_create ()
{
    /* Prevent warnings from making the test fail. */
    Test.log_set_fatal_handler (log_is_fatal);

    var preferences = Gtk.test_create_widget (typeof (Cc.Credentials.Preferences));
}

bool log_is_fatal (string? log_domain, LogLevelFlags log_level, string message)
{
    return (log_level & (LogLevelFlags.LEVEL_CRITICAL |
                         LogLevelFlags.LEVEL_ERROR)) != 0;
}
