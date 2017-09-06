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
 * Web credentials accounts page. This is for selecting an account, or for
 * showing details of an existing account.
 */
public class Cc.Credentials.AccountsPage : Gtk.Grid
{
    public uint account_details_id { get; construct; }
    public string application_id { get; construct; }

    private Gtk.TreeView accounts_tree;
    private AccountsModel accounts_store;
    private Gtk.Notebook accounts_notebook;
    private AccountDetailsPage account_details_page;

    /**
     * Emitted when a new account should be added. Copied from ProvidersPage,
     * to be emitted again to the main panel.
     *
     * @param provider_name the name of the provider for which an account
     * should be added
     */
    public signal void new_account_request (string provider_name);

    /**
     * Emitted when an existing account needs to be reauthenticated. Copied
     * from AccountDetailsPage, to be emitted again to the main panel.
     *
     * @param account the account to authenticate
     */
    public signal void reauthenticate_account_request (Ag.Account account);

    /**
     * Emitted when an application needs to show options. Copied from
     * AccountDetailsPage, to be emitted again to the main panel.
     * 
     * @param application_row the AccountApplicationRow for the application
     * that needs configuration
     */
    public signal void account_options_request (AccountApplicationRow application_row);

    /**
     * Emitted when an account needs to show options. Copied from
     * AccountDetailsPage, to be emitted again to the main panel.
     *
     * @param plugin the Ap.Plugin for the account that needs configuration
     */
    public signal void account_edit_options_request (Ap.Plugin plugin);

    /**
     * Select the desired page of @link accounts_notebook to select an account
     * to view settings of, or for showing details of an existing account.
     *
     * @param SELECT_PROVIDER select a provider for a new account
     * @param ACCOUNT_DETAILS display details of an existing account
     */
    private enum NotebookPage
    {
        SELECT_PROVIDER = 0,
        ACCOUNT_DETAILS = 1
    }

    public AccountsPage ()
    {
        Object ();
    }

    public AccountsPage.with_account_details (Ag.AccountId account_id)
    {
        Object (account_details_id: account_id);
    }

    public AccountsPage.with_application (string application)
    {
        Object (application_id: application);
    }

    construct
    {
        row_spacing = 6;
        column_spacing = 12;

        this.attach (create_accounts_tree (), 0, 0, 1, 1);
        this.attach (create_accounts_notebook (), 1, 0, 1, 1);
        this.attach (create_legal_button (), 0, 1, 2, 1);

        // Force handling of the changed signal.
        var selection = accounts_tree.get_selection ();
        on_accounts_selection_changed (selection);

        // Update the selection if a new account was added.
        accounts_store.row_inserted.connect (on_accounts_store_row_inserted);

        set_size_request (-1, 400);

        show ();
    }

    /**
     * Create the buttonbox containing the button to display a legal notice.
     *
     * @return a Gtk.ButtonBox for presecting the legal notice button
     */
    private Gtk.Widget create_legal_button ()
    {
        var buttonbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        var legal_button = new Gtk.LinkButton.with_label ("help:"
                                                          + "web-credentials"
                                                          + "/legal-notice",
                                                          _("Legal notice"));

        buttonbox.layout_style = Gtk.ButtonBoxStyle.END;
        buttonbox.add (legal_button);
        buttonbox.show_all ();

        return buttonbox;
    }

    /**
     * Create the treeview for the list of accounts and show it.
     *
     * @return a Gtk.ScrolledWindow containing a treeview of accounts
     */
    private Gtk.Widget create_accounts_tree ()
    {
        accounts_tree = new Gtk.TreeView ();
        accounts_store = new AccountsModel ();

        accounts_tree.model = accounts_store;
        accounts_tree.headers_visible = false;

        var provider_icon_renderer = new Gtk.CellRendererPixbuf ();
        provider_icon_renderer.stock_size = Gtk.IconSize.DND;
        provider_icon_renderer.set_padding (8, 8);

        var text_renderer = new Gtk.CellRendererText ();
        text_renderer.ellipsize = Pango.EllipsizeMode.END;

        var accounts_tree_column = new Gtk.TreeViewColumn ();
        accounts_tree_column.pack_start (provider_icon_renderer, false);
        accounts_tree_column.set_cell_data_func (provider_icon_renderer,
                                                 provider_icon_cell_data_func);

        accounts_tree_column.pack_start (text_renderer, true);
        accounts_tree_column.add_attribute (text_renderer,
                                            "markup",
                                            AccountsModel.ModelColumns.ACCOUNT_DESCRIPTION);

        var attention_icon_renderer = new Gtk.CellRendererPixbuf ();
        attention_icon_renderer.icon_name = "dialog-error-symbolic";
        accounts_tree_column.pack_end (attention_icon_renderer, false);
        accounts_tree_column.add_attribute (attention_icon_renderer,
                                            "visible",
                                            AccountsModel.ModelColumns.NEEDS_ATTENTION);
        accounts_tree.append_column (accounts_tree_column);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.min_content_height = 250;
        scrolled_window.min_content_width = 250;
        scrolled_window.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scrolled_window.add (accounts_tree);

        var accounts_selection = accounts_tree.get_selection ();

        // Select the row with the account ID passed in at construction time.
        if (account_details_id != 0)
        {
            Gtk.TreeIter iter;

            if (accounts_store.find_iter_for_account_id (account_details_id,
                                                         out iter))
            {
                accounts_selection.select_iter (iter);
            }
            else
            {
                warning ("Passed-in account ID '%u' not found.",
                         (uint) account_details_id);
            }
        }

        // Check if any changes occured on the selected row.
        accounts_store.row_changed.connect (on_accounts_store_row_changed);

        // The changed handler depends on the notebook being constructed.
        accounts_selection.changed.connect (on_accounts_selection_changed);

        scrolled_window.show_all ();

        return scrolled_window;
    }

    /**
     * Create the notebook with a page for adding providers.
     *
     * @return a Gtk.Notebook containing a provider selection tree view
     */
    private Gtk.Widget create_accounts_notebook ()
    {
        accounts_notebook = new Gtk.Notebook ();
        accounts_notebook.show_tabs = false;
        accounts_notebook.show_border = false;
        accounts_notebook.expand = true;

        ProvidersPage providers_page;

        if (application_id != null)
        {
            providers_page = new ProvidersPage.with_application (application_id);
        }
        else
        {
            providers_page = new ProvidersPage ();
        }

        var account_details_page = create_account_details_page () as AccountDetailsPage;

        providers_page.new_account_request.connect (on_providers_page_new_account_request);
        account_details_page.reauthenticate_account_request.connect (on_account_details_page_reauthenticate_account_request);
        account_details_page.account_options_request.connect (on_account_details_page_account_options_request);
        account_details_page.account_edit_options_request.connect (on_account_details_page_account_edit_options_request);

        accounts_notebook.append_page (providers_page);
        accounts_notebook.append_page (account_details_page);

        accounts_notebook.set_current_page (NotebookPage.SELECT_PROVIDER);

        accounts_notebook.show_all ();

        return accounts_notebook;
    }

    /**
     * Create a notebook page for showing details for an account, such as the
     * list of applications which use that account.
     *
     * @return a Gtk.Grid containing widgets for listing account details 
     */
    private Gtk.Widget create_account_details_page ()
    {
        account_details_page = new AccountDetailsPage (accounts_store);

        return account_details_page;
    }

    /**
     * Show the translucent provider icon if the account is disabled, and the
     * standard icon when the account is enabled.
     *
     * @param column the TreeModelColumn. Unused
     * @param cell the Gtk.CellRendererPixbuf for the column
     * @param model the AccountsModel to get data from
     * @param iter the oter in AccountsModel to get data from
     */
    private void provider_icon_cell_data_func (Gtk.CellLayout column,
                                               Gtk.CellRenderer cell,
                                               Gtk.TreeModel model,
                                               Gtk.TreeIter iter)
    {
        bool enabled;
        Icon icon;
        Gdk.Pixbuf pixbuf;
        var renderer = cell as Gtk.CellRendererPixbuf;

        model.get (iter,
                   AccountsModel.ModelColumns.ENABLED, out enabled,
                   AccountsModel.ModelColumns.PROVIDER_ICON, out icon,
                   AccountsModel.ModelColumns.TRANSLUCENT_PIXBUF, out pixbuf,
                   -1);

        if (enabled)
        {
            renderer.pixbuf = null;
            renderer.gicon = icon;
        }
        else
        {
            renderer.gicon = null;
            renderer.pixbuf = pixbuf;
        }
    }

    /**
     * Reload the account details page if the currently-selected row changed.
     *
     * @param tree_model the AccountsModel
     * @param path the Gtk.TreePath of the changed row
     * @param iter the Gtk.TreeIter of the changed row
     */
    private void on_accounts_store_row_changed (Gtk.TreeModel tree_model,
                                                Gtk.TreePath path,
                                                Gtk.TreeIter iter)
    {
        var selection = accounts_tree.get_selection ();

        if (selection.path_is_selected (path))
        {
            // Set the selected iter again.
            account_details_page.account_iter = iter;
        }
    }

    /**
     * Show an appropriate page in the notebook, depending on which row was
     * selected in the accounts treeview.
     *
     * @param selection the selection of the accounts treeview
     */
    private void on_accounts_selection_changed (Gtk.TreeSelection selection)
    {
        Gtk.TreeModel model;
        Gtk.TreeIter iter;

        if (selection.get_selected (out model, out iter))
        {
            Gtk.TreeIter test_iter;

            var n_rows = model.iter_n_children (null);

            // n_rows is not an index, which is what iter_nth_child() expects
            if (model.iter_nth_child (out test_iter, null, n_rows - 1))
            {
                if (iter == test_iter)
                {
                    // Last row selected, switch to add account notebook page.
                    accounts_notebook.set_current_page (NotebookPage.SELECT_PROVIDER);
                }
                else
                {
                    // Account row selected, show the relevant account page.
                    account_details_page.account_iter = iter;
                    accounts_notebook.set_current_page (NotebookPage.ACCOUNT_DETAILS);
                }
            }
            else
            {
                // Selection was past the final row.
                assert_not_reached ();
            }
        }
        else
        {
            // Select the first row if nothing else is selected.
            if (model.iter_n_children (null) > 0)
            {
                selection.select_path (new Gtk.TreePath.first ());
            }
        }
    }

    /**
     * Tell the main panel to show a new account page for the provider selected
     * in the tree view of available providers.
     *
     * @param provider_name the name of the provider for which to add an
     * account
     */
    private void on_providers_page_new_account_request (string provider_name)
    {
        new_account_request (provider_name);
    }

    /**
     * Tell the main panel to show the authentication page for an account that
     * requires attention in the account details view.
     *
     * @param account the account to reauthenticate
     */
    private void on_account_details_page_reauthenticate_account_request (Ag.Account account)
    {
        reauthenticate_account_request (account);
    }

    /**
     * Tell the main panel to show the options page for an application that
     * required configuration in the account details view.
     *
     * @param application_row the AccountApplicationRow of the application to
     * show options for
     */
    private void on_account_details_page_account_options_request (AccountApplicationRow application_row)
    {
        account_options_request (application_row);
    }

    /**
     * Tell the main panel to show the options page for an account that
     * required configuration in the account details view.
     *
     * @param plugin the Ap.Plugin of the account to show options for
     */
    private void on_account_details_page_account_edit_options_request (Ap.Plugin plugin)
    {
        account_edit_options_request (plugin);
    }

    /**
     * Select the newly-added row, as required by the UI specification.
     *
     * @param path the Gtk.TreePath of the newly-added row
     * @param iter the Gtk.TreeIter of the newly-added row
     */
    private void on_accounts_store_row_inserted (Gtk.TreePath path,
                                                 Gtk.TreeIter iter)
    {
        var selection = accounts_tree.get_selection ();
        selection.select_iter (iter);
    }
}
