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

/**
 * Used to receive credentials captured from other applications (browser).
 */
[DBus (name = "com.canonical.webcredentials.capture")]
public class Cc.Credentials.LoginCapture : Object
{
    public LoginCapture()
    {
        Bus.own_name (BusType.SESSION,
                      "com.canonical.webcredentials.capture",
                      BusNameOwnerFlags.NONE,
                      on_bus_acquired,
                      () => {},
                      () => warning ("Could not acquire name."));
    }

    [DBus (visible = false)]
    public signal void new_account_request (string provider_name,
                                            string username,
                                            string? password,
                                            HashTable<string,string> cookies);

    public void login_captured (string provider_name,
                                string username,
                                string? password,
                                HashTable<string,string> cookies)
    {
        debug ("Login captured: %s, %s", provider_name, username);

        new_account_request (provider_name, username, password, cookies);
    }

    private void on_bus_acquired (DBusConnection conn)
    {
        try
        {
            conn.register_object ("/com/canonical/webcredentials/capture",
                                  this);
        }
        catch (IOError e)
        {
            warning ("Could not register service.");
        }
    }
}

