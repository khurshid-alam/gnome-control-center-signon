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

// FIXME: Make the model sortable.
/**
 * Web credentials applications Gtk.ListStore. Used as a model for the
 * applications managed by libaccounts-glib, for display in a combo box for
 * selecting an application.
 */
public class Cc.Credentials.ApplicationsModel : Gtk.ListStore
{
    private Ag.Manager manager;

    /**
     * Identifiers for columns in the applications model.
     *
     * @param APPLICATION_NAME the name of the application, for passing to
     * Ag.Manager.get_application ()
     * @param APPLICATION_DESCRIPTION the description of the application
     */
    public enum ModelColumns
    {
        APPLICATION_NAME = 0,
        APPLICATION_DESCRIPTION = 1
    }

    /**
     * Create a new data model for the list of applications.
     */
    public ApplicationsModel ()
    {
        Type[] types = { typeof (string), typeof (string) };
        set_column_types (types);

        // TODO: Use the same Ag.Manager throughout.
        manager = new Ag.Manager ();

        populate_model ();

        // FIXME: No notification signals for adding new applications.
    }

    /**
     * Populate the model with the current list of applications, by querying
     * for available services and then listing the applications available for
     * each service.
     */
    private void populate_model ()
    {
        var services = manager.list_services ();
        var application_hash = new HashTable<string, string> (str_hash,
                                                              str_equal);

        foreach (var service in services)
        {
            var applications = manager.list_applications_by_service (service);

            foreach (var application in applications)
            {
                application_hash.insert (dgettext (application.get_i18n_domain (),
                                                   application.get_name ()),
                                         dgettext (application.get_i18n_domain (),
                                                   application.get_description ()));
            }
        }

        application_hash.foreach (add_application);

        // Magic value! Must always be the first item in the list.
        insert_with_values (null, 0,
                            ModelColumns.APPLICATION_NAME, "all",
                            ModelColumns.APPLICATION_DESCRIPTION, _("All applications"));
    }

    /**
     * Insert a single application and application display name into the model.
     */
    private void add_application (string application_name,
                                  string application_description)
    {
        insert_with_values (null, -1,
                            ModelColumns.APPLICATION_NAME, application_name,
                            ModelColumns.APPLICATION_DESCRIPTION, application_description,
                            -1);
    }

    /**
     * Find an iter for a given application.
     *
     * @param application the name of an Ag.Application described in the model
     * @param iter the iter to set
     * @return true if the application existed in the model, false otherwise
     */
    public bool find_iter_for_application (string application,
                                           out Gtk.TreeIter iter)
    {
        Gtk.TreeIter local_iter;

        this.get_iter_first (out local_iter);

        var found = false;
        do
        {
            string model_application;
            this.get (local_iter, ModelColumns.APPLICATION_NAME,
                      out model_application, -1);

            if (model_application == application)
            {
                found = true;
                break;
            }
        } while (this.iter_next (ref local_iter));

        iter = local_iter;
        return found;
    }
}
