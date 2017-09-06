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
 * Standalone application for configuring web credentials accounts outside of
 * Unity Control Center.
 */
public class Cc.Credentials.Application : Gtk.Application
{
    static bool version;

    private Gtk.Window main_window;

    const OptionEntry[] options = {
        { "version", 'V', 0, OptionArg.NONE, ref version, N_("Output version information and exit"), null },
        { null }
    };

    public Application (string app_id, ApplicationFlags flags)
    {
        GLib.Object (application_id: app_id, flags: flags);
    }

    /**
     * Raise the window if the application already has a running instance.
     */
    public void on_app_activate ()
    {
        if (get_windows () != null)
        {
            main_window.present ();
        }
        else
        {
            Environment.set_application_name (_("Online Accounts preferences"));

            main_window = new Gtk.Window ();

            main_window.add (new Preferences ());
            main_window.set_application (this);
            main_window.show ();
        }
    }

    /**
     * Overriden method of GLib.Application, to handle command-line arguments
     * in the local instance. This is especially important for --version, so
     * that only the local instance exits.
     *
     * @param arguments the command-line arguments
     * @param exit_status the exit code to return to the OS
     * @return true if the arguments were successfully processed, false
     * otherwise
     */
    public override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)]
                                             ref unowned string[] args,
                                             out int exit_status)
    {
        try
        {
            register ();
        }
        catch (Error e)
        {
            critical ("Error during Application registration: %s", e.message);
            exit_status = 1;
            return true;
        }

        // Ugly workaround for GNOME bug 642885.
        unowned string[] arguments = args;
        if (arguments.length <= 1)
        {
            activate ();
            exit_status = 0;
        }
        else
        {
            try
            {
                var context = new OptionContext (_(" - Edit Web credentials settings"));
                context.set_translation_domain (Config.GETTEXT_PACKAGE);
                context.set_help_enabled (true);
                context.add_main_entries (options, null);
                context.add_group (Gtk.get_option_group (true));
                context.parse (ref arguments);
            }
            catch (OptionError e)
            {
                stdout.printf ("Error parsing command-line: %s\n", e.message);
                stdout.printf (_("Run '%s --help' to see a full list of available command line options.\n"),
                               arguments[0]);
                exit_status = 1;
                return true;
            }

            if (version)
            {
                stdout.printf ("%s %s\n", Config.PACKAGE_NAME,
                               Config.PACKAGE_VERSION);
                exit_status = 1;
                return true;
            }

            if (get_is_remote ())
            {
                stdout.printf ("%s\n",
                               _("Another instance is already running"));
                exit_status = 1;
                return true;
            }
            else
            {
                exit_status = 0;
            }
        }

        return true;
    }
}

public static int main (string[] arguments)
{
    var app = new Cc.Credentials.Application ("com.Canonical.WebCredentials.Preferences",
                                              ApplicationFlags.FLAGS_NONE);

    app.activate.connect (app.on_app_activate);

    return app.run (arguments);
}
