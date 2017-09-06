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
 * Web credentials providers page. This is for selecting an available provider
 * to add a new account for.
 */
public class Cc.Credentials.ProvidersPage : Gtk.Grid
{
    /**
     * Emitted when a new account should be added.
     *
     * @param provider_name the name of the provider for which an account
     * should be added
     */
    public signal void new_account_request (string provider_name);

    /**
     * Select the desired page of @link providers_notebook to select a provider
     * tree view or label describing no applications for this provider.
     *
     * @param TREE show the tree view of providers for this application
     * @param LABEL show the label explaining the lack of available
     * applications
     */
    private enum NotebookPage
    {
        TREE = 0,
        LABEL = 1
    }

    private Ag.Manager manager;
    private Gtk.ComboBox applications_combo;
    private Gtk.Notebook providers_notebook;
    private Gtk.TreeModelFilter filter_model;
    private string current_application;

    public string application_id { get; construct; }

    public ProvidersPage ()
    {
        Object ();
    }

    public ProvidersPage.with_application (string application)
    {
        Object (application_id: application);
    }

    construct
    {
        orientation = Gtk.Orientation.VERTICAL;
        expand = true;

        // TODO: Use common Ag.Manager.
        manager = new Ag.Manager ();

        this.add (create_providers_selector ());
        this.add (create_providers_notebook ());

        /* This defaults to -1, no selection, so force it to have the first
         * item selected.
         */
        applications_combo.active = 0;

        // Trigger a refilter if an application was passed in.
        if (application_id != null)
        {
            current_application = application_id;

            Gtk.TreeIter iter;
            var applications_model = applications_combo.model as ApplicationsModel;
            if (applications_model.find_iter_for_application (application_id,
                                                              out iter))
            {
                applications_combo.set_active_iter (iter);
            }
            else
            {
                message ("Passed-in application '%s' was not found",
                         application_id);
            }
        }

        set_size_request (-1, 400);

        show ();
    }

    /**
     * Create the infobar which describes the treeview of account providers.
     *
     * @return a Gtk.InfoBar describing the account providers
     */
    private Gtk.Widget create_providers_selector ()
    {
        var label = new Gtk.Label (_("Show accounts that integrate with:"));
        var applications_model = new ApplicationsModel ();
        applications_combo = new Gtk.ComboBox.with_model (applications_model);
        applications_combo.hexpand = true;
        var text_renderer = new Gtk.CellRendererText ();
        applications_combo.pack_start (text_renderer, false);
        applications_combo.set_attributes (text_renderer, "markup",
                                           ApplicationsModel.ModelColumns.APPLICATION_DESCRIPTION);
        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.add (label);
        grid.add (applications_combo);

        applications_combo.changed.connect (on_applications_combo_changed);

        // Height matches infobar of AccountDetailsPage.
        grid.set_size_request (-1, 48);
        grid.show_all ();

        return grid;
    }

    /**
     * Create the notebook for holding the provider treeview or a label.
     *
     * @return a Gtk.Notebook
     */
    private Gtk.Widget create_providers_notebook ()
    {
        providers_notebook = new Gtk.Notebook ();
        providers_notebook.show_border = false;
        providers_notebook.show_tabs = false;

        providers_notebook.append_page (create_providers_tree ());

        var no_applications_label = new Gtk.Label (_("There are currently no account providers available which integrate with this application"));
        no_applications_label.wrap = true;
        providers_notebook.append_page (no_applications_label);

        providers_notebook.show_all ();

        return providers_notebook;
    }

    /**
     * Create the treeview of account providers, for setting up a new account.
     *
     * @return a Gtk.ScrolledWindow containing the account provider treeview
     */
    private Gtk.Widget create_providers_tree ()
    {
        var providers_model = new ProvidersModel ();
        filter_model = new Gtk.TreeModelFilter (providers_model, null);
        filter_model.set_visible_func (filter_model_visible);
        var providers_tree = new Gtk.TreeView.with_model (filter_model);
        providers_tree.headers_visible = false;
        providers_tree.hover_selection = true;
        providers_tree.tooltip_column = ProvidersModel.ModelColumns.TOOLTIP;

        var pixbuf_renderer = new Gtk.CellRendererPixbuf ();
        pixbuf_renderer.stock_size = Gtk.IconSize.DND;
        pixbuf_renderer.set_padding (8, 8);
        var text_renderer = new Gtk.CellRendererText ();

        var providers_tree_column = new Gtk.TreeViewColumn ();
        providers_tree_column.pack_start (pixbuf_renderer, false);
        providers_tree_column.add_attribute (pixbuf_renderer, "gicon",
                                             ProvidersModel.ModelColumns.PROVIDER_ICON);
        providers_tree_column.pack_start (text_renderer, true);
        providers_tree_column.add_attribute (text_renderer, "markup",
                                             ProvidersModel.ModelColumns.PROVIDER_DESCRIPTION);
        providers_tree.append_column (providers_tree_column);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.min_content_height = 250;
        scrolled_window.min_content_width = 400;
        scrolled_window.expand = true;
        scrolled_window.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scrolled_window.add (providers_tree);

        /* Add a new account when a row is single-clicked, as selection is
         * already handled on hover.
         */
        providers_tree.button_press_event.connect (on_providers_tree_button_press_event);
        providers_tree.row_activated.connect (on_providers_tree_row_activated);

        scrolled_window.show_all ();

        return scrolled_window;
    }

    /**
     * Visible filter function for the filter tree model of applications.
     *
     * @param model the child tree model to filter
     * @param iter the iter to query data from
     */
    private bool filter_model_visible (Gtk.TreeModel model, Gtk.TreeIter iter)
    {
        string application_name;
        model.get (iter,
                   ApplicationsModel.ModelColumns.APPLICATION_NAME, out application_name,
                   -1);

        return application_name == current_application;
    }

    /**
     * Handle the application combo box selection being changed, by updating
     * the current application being filtered by the filter model.
     *
     * @param applications_combo the combo box for selecting from a list of
     * applications
     */
    private void on_applications_combo_changed (Gtk.ComboBox applications_combo)
    {
        Gtk.TreeIter iter;
        if (applications_combo.get_active_iter (out iter))
        {
            string application_name;
            var model = applications_combo.model;
            model.get (iter,
                       ApplicationsModel.ModelColumns.APPLICATION_NAME, out application_name,
                       -1);

            current_application = application_name;
            filter_model.refilter ();

            // Update the widget shown in the providers notebook.
            var n_items = filter_model.iter_n_children (null);
            update_notebook_widget (n_items);
        }
    }

    /**
     * Use the current selection (either with the pointer or keyboard
     * navigation) to select a provider for which to create a new account.
     *
     * @param providers_tree the treeview from which to get the current
     * selection
     */
    private void add_account_for_current_selection (Gtk.TreeView providers_tree)
    {
        var selection = providers_tree.get_selection ();
        Gtk.TreeModel model;
        Gtk.TreeIter iter;

        if (selection.get_selected (out model, out iter))
        {
            string provider_name;
            model.get (iter,
                       ProvidersModel.ModelColumns.PROVIDER_NAME, out provider_name,
                       -1);

            /* Unselect the row, as otherwise it is impossible to add
             * another account from the same provider immediately
             * afterwards.
             */
            selection.unselect_all ();

            // Emit signal for the main panel to switch notebook page.
            new_account_request (provider_name);
        }
    }

    /**
     * Update which widget the providers notebook is showing, based on the
     * number of items in the filter model.
     *
     * @param n_items the number of items shown in the providers tree view,
     * from the filter model
     */
    private void update_notebook_widget (int n_items)
    {
        if (n_items > 0)
        {
            providers_notebook.set_current_page (NotebookPage.TREE);
        }
        else
        {
            providers_notebook.set_current_page (NotebookPage.LABEL);
        }
    }

    /**
     * Check which row the pointer was clicked over, and create a new account
     * for the associated provider.
     *
     * @param widget the widget (providers_tree) that generated the event
     * @param event the button press event
     * @return true if the event was handled, false if the event should be
     * propagated
     */
    private bool on_providers_tree_button_press_event (Gtk.Widget widget,
                                                       Gdk.EventButton event)
    {
        if (event.button == 1 && event.type == Gdk.EventType.BUTTON_PRESS)
        {
            /* The selected row will be the row that the button press event
             * occurred on.
             */
            add_account_for_current_selection (widget as Gtk.TreeView);

            return true;
        }
        else
        {
            // Propagate the event if it is not for creating a new account.
            return false;
        }
    }

    /**
     * Make activations (with the keyboard, presumably) act the same as
     * single-clicking on a row.
     *
     * @param tree_view the tree view which had a row activated
     * @param path the path of the activated row (unused)
     * @param column the column for the activated row (unused)
     */
    private void on_providers_tree_row_activated (Gtk.TreeView tree_view,
                                                  Gtk.TreePath path,
                                                  Gtk.TreeViewColumn column)
    {
        add_account_for_current_selection (tree_view);
    }
}
