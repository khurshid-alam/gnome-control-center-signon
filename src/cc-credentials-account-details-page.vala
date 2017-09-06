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
 * Button widget, additionally storing an AccountApplicationRow.
 */
private class Cc.Credentials.AccountApplicationButton : Gtk.Button
{
    /**
     * An AccountApplicationRow, for showing the configuration widget from
     * on_options_button_clicked().
     * 
     * This property is necessary because Vala generates incorrect C code if
     * using g_object_set_data() and g_object_get_data() with a boxed type.
     */
    public AccountApplicationRow application_row { get; construct; }

    public AccountApplicationButton (string label, AccountApplicationRow row)
    {
        Object (label: label, application_row: row);
    }
}

/**
 * Switch widget, additionally storing an AccountApplicationRow.
 */
private class Cc.Credentials.AccountApplicationSwitch : Gtk.Switch
{
    public Ag.Account account { get; construct; }
    public Ag.Service service { get; construct; }
    bool store_in_progress;

    public AccountApplicationSwitch (Ag.Account acc, Ag.Service serv)
    {
        Object (account: acc, service: serv);
    }

    construct
    {
        store_in_progress = false;

        // Fetch current state from service.
        account.select_service (service);
        active = account.get_enabled ();
        account.select_service (null);

        account.set_data ("switch", this);
        account.enabled.connect (on_app_account_enabled);
        set_tooltip_text (_("Control whether this application integrates with Online Accounts"));
        notify["active"].connect (on_app_switch_activated);
    }

    /**
     * Handle the account being enabled or disabled and update the switch state
     * accordingly.
     */
    private void on_app_account_enabled (Ag.Account account, string service,
                                         bool enabled)
    {
        // If the global account is toggled, toggle the switch sensitivity.
        if (service == "global" || service == null)
        {
            sensitive = enabled;
            return;
        }

        if (this.service.get_name () == service && active != enabled)
        {
            active = enabled;
        }
    }

    /**
     * Handle the per-application switch being activated.
     */
    private void on_app_switch_activated ()
    {
        // Toggle the enabled state.
        account.select_service (service);
        account.set_enabled (active);
        account.select_service (null);

        try
        {
            account.store_blocking ();
        }
        catch (Ag.AccountsError err)
        {
            if (err is Ag.AccountsError.DELETED)
            {
                debug ("Enabled state changed during deletion of account ID: %u",
                       account.id);
            }
            else if (err is Ag.AccountsError.STORE_IN_PROGRESS)
            {
                debug ("Enabled state changed while store in progress of account ID: %u",
                       account.id);
            }
            else
            {
                critical ("Error changing enabled state of account: %s\nMessage: %s",
                          account.get_display_name (),
                          err.message);
            }
        }
    }
}

/**
 * Web credentials account details widget. Used inside a notebook page to list
 * the applications that use an account, provide a switch to enable or disable
 * the account and to provide a button for removing the account.
 */
public class Cc.Credentials.AccountDetailsPage : Gtk.Grid
{
    private AccountsModel accounts_store;
    private Ap.Plugin plugin;
    private Gtk.Frame frame;
    private Gtk.Label frame_label;
    private Gtk.Notebook action_notebook;
    private Gtk.Switch enabled_switch;
    private Gtk.Button grant_button;
    private Gtk.Label applications_grid_description;
    private Gtk.ScrolledWindow applications_scroll;
    private Gtk.Grid applications_grid;
    private Gtk.ButtonBox buttonbox;
    private Gtk.Button edit_options_button;
    private AccountApplicationsModel applications_model;
    private Ag.Account current_account;
    private bool edit_options_button_present = false;
    private bool needs_attention = false;
    private bool store_in_progress = false;

    /**
     * Pages for the action widget notebook.
     *
     * @param ENABLED_SWITCH the page containing the switch to enable or
     * disable the current account
     * @param ACCESS_BUTTON the page containing the button to trigger
     * reauthentication
     */
    private enum ActionPage
    {
        ENABLED_SWITCH = 0,
        ACCESS_BUTTON = 1
    }

    /**
     * Signal the preferences widget to switch to the authentication page.
     */
    public signal void reauthenticate_account_request (Ag.Account account);

    /**
     * Signal the preferences widget to switch to the options page.
     */
    public signal void account_options_request (AccountApplicationRow application_row);

    /**
     * Signal the preferences widget to switch to the options page and show the
     * edit options widget.
     */
    public signal void account_edit_options_request (Ap.Plugin plugin);

    /**
     * Index of the selected account in the model.
     */
    public Gtk.TreeIter account_iter
    {
        set
        {
            Ag.AccountId account_id;
            bool iter_needs_attention;
            accounts_store.get (value,
                                AccountsModel.ModelColumns.ACCOUNT_ID,
                                out account_id,
                                AccountsModel.ModelColumns.NEEDS_ATTENTION,
                                out iter_needs_attention,
                                -1);
            account = accounts_store.manager.get_account (account_id);

            if (iter_needs_attention != needs_attention)
            {
                needs_attention = iter_needs_attention;
                update_needs_attention_ui_state ();
            }
        }
    }

    /**
     * Keep the UI state consistent when the account is changed.
     */
    public Ag.Account account
    {
        get
        {
            return current_account;
        }
        set
        {
            // Skip if the account has not changed.
            if (current_account != null && (current_account.id == value.id))
            {
                return;
            }

            current_account = value;

            /* TODO: if needs_attention is true, we might want to hide the list
             * of the integrated applications.
             */

            plugin = Ap.client_load_plugin (value);
            if (plugin == null)
            {
                warning ("No valid plugin found for provider %s",
                         value.get_provider_name ());
            }
            else
            {
                var widget = plugin.build_widget ();
                if (widget == null)
                {
                    debug ("No configuration widget for provider %s",
                             value.get_provider_name ());
                    if (edit_options_button_present)
                    {
                        buttonbox.remove (edit_options_button);
                        edit_options_button_present = false;
                    }
                }
                else
                {
                    if (!edit_options_button_present)
                    {
                        buttonbox.add (edit_options_button);
                        buttonbox.set_child_secondary (edit_options_button,
                                                       true);
                        edit_options_button_present = true;
                    }

                    /* The configuration widget is instantiated by Preferences
                     * when the edit options button is clicked. */
                    widget.destroy ();
                }
            }


            enabled_switch.active = value.get_enabled ();
            value.enabled.connect (on_account_enabled);

            var manager = accounts_store.manager;
            var provider = manager.get_provider (value.get_provider_name ());
            var provider_display_name = provider.get_display_name ();

            update_needs_attention_ui_state ();

            // Update the applications model.
            applications_model.account = value;

            // Special-case having no consumer applications installed.
            unowned List<AccountApplicationRow?> applications = applications_model.application_rows;

            if (applications == null)
            {
                applications_grid_description.label = _("There are currently no applications installed which integrate with your %s account.").printf
                                                      (provider_display_name);
            }
            else
            {
                applications_grid_description.label = _("The following applications integrate with your %s account:").printf
                                                      (provider_display_name);
            }

            populate_applications_grid ();
        }
    }

    public AccountDetailsPage (AccountsModel accounts_store)
    {
        Object ();
        this.accounts_store = accounts_store;
        accounts_store.row_changed.connect (on_accounts_store_row_changed);
    }

    construct
    {
        orientation = Gtk.Orientation.VERTICAL;

        expand = true;

        this.add (create_description_frame ());
        this.add (create_applications_frame ());

        show ();
    }

    /**
     * Create the frame to contain the other widgets for the account and show
     * it.
     *
     * @return a Gtk.Frame for presenting details of the account
     */
    private Gtk.Widget create_applications_frame ()
    {
        var eventbox = new Gtk.EventBox ();
        var frame = new Gtk.Frame (null);
        var context = frame.get_style_context ();
        context.add_class ("ubuntu-online-accounts");
        frame.shadow_type = Gtk.ShadowType.ETCHED_IN;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;

        grid.add (create_applications_grid_description ());
        grid.add (create_applications_grid ());
        grid.add (create_remove_account_box ());

        frame.add (grid);
        eventbox.add (frame);

        // Override theme colors according to the UI specification.
        Gdk.RGBA color;
        context = eventbox.get_style_context ();
        if (context.lookup_color ("base_color", out color))
        {
            eventbox.override_background_color (Gtk.StateFlags.NORMAL, color);
        }
        else
        {
            warning ("Error looking up theme color");
        }

        return eventbox;
    }

    /**
     * Create the frame for the account details header and show it.
     *
     * @return a Gtk.Frame for presenting details of the account
     */
    private Gtk.Widget create_description_frame ()
    {
        frame = new Gtk.Frame (null);
        action_notebook = new Gtk.Notebook ();
        enabled_switch = new Gtk.Switch ();
        frame_label = new Gtk.Label (null);
        var grid = new Gtk.Grid ();
        grid.margin = 6;

        action_notebook.show_tabs = false;
        action_notebook.show_border = false;
        action_notebook.halign = Gtk.Align.END;
        action_notebook.valign = Gtk.Align.FILL;
        frame_label.hexpand = true;
        frame_label.use_markup = true;
        frame_label.wrap = true;
        frame_label.valign = Gtk.Align.CENTER;
        frame_label.xalign = 0.0f;
        grid.add (frame_label);

        enabled_switch.valign = Gtk.Align.CENTER;
        action_notebook.append_page (enabled_switch, null);
        grant_button = new Gtk.Button.with_label (_("Grant access"));
        grant_button.valign = Gtk.Align.CENTER;
        action_notebook.append_page (grant_button, null);

        grid.add (action_notebook);

        enabled_switch.notify["active"].connect (on_enabled_switch_activated);
        grant_button.clicked.connect (on_grant_button_clicked);

        frame.add (grid);
        frame.set_size_request (-1, 48);
        frame.show_all ();

        return frame;
    }

    /**
     * Create a description to place above the applications grid.
     *
     * @return a Gtk.Label for a description of the applications grid
     */
    private Gtk.Widget create_applications_grid_description ()
    {
        applications_grid_description = new Gtk.Label (null);

        applications_grid_description.margin = 6;
        applications_grid_description.xalign = 0.0f;

        applications_grid_description.set_line_wrap (true);
        applications_grid_description.set_size_request (414, -1);
        applications_grid_description.show ();

        return applications_grid_description;
    }

    /**
     * Create the grid with a list of applications using the current account.
     *
     * @return a Gtk.Grid containing a list of applications
     */
    private Gtk.Widget create_applications_grid ()
    {
        applications_model = new AccountApplicationsModel ();

        applications_scroll = new Gtk.ScrolledWindow (null, null);
        var context = applications_scroll.get_style_context ();
        context.add_class ("ubuntu-online-accounts");

        // Instantiates applications_grid.
        populate_applications_grid ();

        applications_scroll.window_placement_set = true;

        // Override theme colors according to the UI specification.
        Gdk.RGBA color;
        var viewport = applications_scroll.get_child ();
        context = viewport.get_style_context ();
        if (context.lookup_color ("base_color", out color))
        {
            viewport.override_background_color (Gtk.StateFlags.NORMAL, color);
        }
        else
        {
            warning ("Error looking up theme color");
        }

        return applications_scroll;
    }

    /**
     * Create a button box for the account editing buttons.
     *
     * @return a Gtk.ButtonBox for the remove or edit account buttons
     */
    private Gtk.Widget create_remove_account_box ()
    {
        buttonbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        buttonbox.set_layout (Gtk.ButtonBoxStyle.END);
        buttonbox.margin = 6;

        var remove_button = new Gtk.Button.with_label (_("Remove Account"));
        edit_options_button = new Gtk.Button.with_label (_("Edit Options"));

        remove_button.clicked.connect (on_remove_account_clicked);
        edit_options_button.clicked.connect (on_edit_options_button_clicked);

        buttonbox.add (remove_button);

        buttonbox.show_all ();
        edit_options_button.show ();

        return buttonbox;
    }

    /**
     * Populate the grid of applications from the model. Instantiates
     * applications_grid.
     */
    private void populate_applications_grid ()
    {
        if (applications_grid != null)
        {
            applications_grid.destroy ();
        }

        applications_grid = new Gtk.Grid ();
        applications_grid.border_width = 6;
        applications_grid.column_spacing = 12;
        applications_grid.row_spacing = 12;
        applications_grid.expand = true;

        unowned List<AccountApplicationRow?> applications = applications_model.application_rows;

        applications.foreach (add_application);

        applications_scroll.add_with_viewport (applications_grid);

        applications_scroll.show_all ();
    }

    /**
     * Add an individual application from the model to the applications grid.
     *
     * @param application the description of the application
     */
    private void add_application (AccountApplicationRow? application)
    {
        applications_grid.insert_row (0);

        var image = new Gtk.Image.from_gicon (application.icon,
                                              Gtk.IconSize.DND);
        image.margin_left = 4;
        applications_grid.attach (image, 0, 0, 1, 1);

        var label = new Gtk.Label (application.description);
        label.hexpand = true;
        label.use_markup = true;
        label.xalign = 0.0f;
        applications_grid.attach_next_to (label,
                                          image,
                                          Gtk.PositionType.RIGHT,
                                          1,
                                          1);

        var service = accounts_store.manager.get_service (application.service_name);
        var app_switch = new AccountApplicationSwitch (account, service);

        if (application.plugin_widget != null)
        {
            var button = new AccountApplicationButton (_("Options"),
                                                       application);
            applications_grid.attach_next_to (button,
                                              label,
                                              Gtk.PositionType.RIGHT,
                                              1,
                                              1);
            applications_grid.attach_next_to (app_switch,
                                              button,
                                              Gtk.PositionType.RIGHT,
                                              1,
                                              1);

            button.clicked.connect (on_options_button_clicked);
        }
        else
        {
            applications_grid.attach (app_switch, 3, 0, 1, 1);
        }
    }

    /**
     * Update the state of the action notebook and frame label when the
     * needs-attention state changes.
     */
    private void update_needs_attention_ui_state ()
    {
        var manager = accounts_store.manager;
        var provider = manager.get_provider (current_account.get_provider_name ());
        var provider_display_name = provider.get_display_name ();

        if (needs_attention)
        {
            frame_label.label = _("Please authorize Ubuntu to access your %s account:").printf
                                (provider_display_name);

            action_notebook.page = ActionPage.ACCESS_BUTTON;
        }
        else
        {
            frame_label.label = "<b>" + provider_display_name + "</b>\n"
                                + "<small><span foreground=\"#555555\">"
                                + current_account.get_display_name ()
                                + "</span></small>";

            action_notebook.page = ActionPage.ENABLED_SWITCH;
        }
    }

    /**
     * Handle the remove account button being clicked. The removal is
     * asynchronous, and on_remove_account_finished() is called when the
     * operation is complete.
     *
     * @see AccountDetailsPage.on_remove_account_finished
     */
    private void on_remove_account_clicked ()
    {
        // TODO: Pass parent window ID as first argument.
        var confirmation = new Gtk.MessageDialog (null,
                                                  Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                  Gtk.MessageType.QUESTION,
                                                  Gtk.ButtonsType.NONE,
                                                  "%s",
                                                  _("Are you sure that you wish to remove this Ubuntu Web Account?"));
        var manager = accounts_store.manager;
        var provider = manager.get_provider (current_account.get_provider_name ());
        var provider_display_name = provider.get_display_name ();
        var secondary_text = _("The Web Account which manages the integration of %s with your applications will be removed.").printf (provider_display_name)
                               + "\n\n"
                               + _("Your online %s account is not affected.").printf (provider_display_name);
        confirmation.secondary_text = secondary_text;
        confirmation.add_buttons (Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                  Gtk.Stock.REMOVE, Gtk.ResponseType.ACCEPT,
                                  null);

        var response = confirmation.run ();

        switch (response)
        {
            case Gtk.ResponseType.ACCEPT:
                // TODO: Set the UI to be insensitive during account removal?

                var plugin = Ap.client_load_plugin (current_account);
                if (plugin == null)
                {
                    /* This can really happen, if the plugin has been
                     * uninstalled; in this case, the user can still access the
                     * account (to disable or delete it).
                     */
                    warning ("No valid plugin found for provider %s",
                             current_account.get_provider_name ());
                    // TODO: Delete the account in this case.
                    break;
                }

                plugin.delete_account.begin ((obj, res) => {
                    try
                    {
                        plugin.delete_account.end (res);
                    }
                    catch (Error error)
                    {
                        critical ("Error deleting account: %s", error.message);
                    }
                    on_remove_account_finished (current_account);
                });
                break;
            case Gtk.ResponseType.CANCEL:
            case Gtk.ResponseType.DELETE_EVENT:
                break;
            default:
                assert_not_reached ();
        }

        confirmation.destroy ();
    }

    /**
     * Handle the completion of the asynchronous account removal operation.
     *
     * @param account the account that was removed
     */
    private void on_remove_account_finished (Ag.Account account)
    {
        /* TODO: Set the UI to be sensitive again? Switch to the add account
         * view.
         */
    }

    /**
     * Asynchronously store the current account.
     */
    private void store_current_account ()
    {
        if (store_in_progress)
        {
            debug ("Enabled state changed while store in progress of account ID: %u",
                   account.id);
            return;
        }
            
        store_in_progress = true;

        current_account.store_async.begin (null, (obj, res) =>
        {
            try
            {
                store_in_progress = false;

                current_account.store_async.end (res);
            }
            catch (Ag.AccountsError err)
            {
                if (err is Ag.AccountsError.DELETED)
                {
                    debug ("Enabled state changed during deletion of account ID: %u",
                           account.id);
                }
                else if (err is Ag.AccountsError.STORE_IN_PROGRESS)
                {
                    debug ("Enabled state changed while store in progress of account ID: %u",
                           account.id);
                }
                else
                {
                    critical ("Error changing enabled state of account: %s\nMessage: %s",
                              current_account.get_display_name (),
                              err.message);
                }
            }
        });
    }

    /**
     * Handle the account enabled switch being activated. Change the current
     * account to be the same state as the switch.
     */
    private void on_enabled_switch_activated ()
    {
        current_account.set_enabled (enabled_switch.active);
        store_current_account ();
    }

    /**
     * Handle the reauthentication button being clicked.
     */
    private void on_grant_button_clicked ()
    {
        reauthenticate_account_request (current_account);
    }

    /**
     * Handle the account being enabled or disabled from elsewhere, and update
     * the switch state accordingly.
     */
    private void on_account_enabled (string? service, bool enabled)
    {
        // Ignore service-level changes.
        // FIXME: http://code.google.com/p/accounts-sso/issues/detail?id=157
        if (service != "global" || service != null)
        {
            return;
        }

        if (enabled != enabled_switch.active)
        {
            enabled_switch.active = enabled;
        }
    }

    /**
     * Handle the options button for an application being clicked.
     *
     * @param button the AccountApplicationButton that emitted the clicked
     * signal. The account application plugin is a property on the button.
     */
    private void on_options_button_clicked (Gtk.Button button)
    {
        var app_button = button as AccountApplicationButton;
        var application_row = app_button.application_row;

        if (application_row.plugin_widget != null)
        {
            account_options_request (application_row);
        }
    }

    /**
     * Handle the edit options button for an account being clicked.
     */
    private void on_edit_options_button_clicked ()
    {
        account_edit_options_request (plugin);
    }

    /**
     * Handle a row in the accounts model being changed.
     *
     * Check to see whether the current account was changed, and then check to
     * see if the needs-attention flag is set, and update the action notebook
     * state accordingly.
     *
     * @param model the Gtk.TreeModel
     * @param path the Gtk.TreePath of the changed row
     * @param iter the Gtk.TreeIter of the changed row
     */
    private void on_accounts_store_row_changed (Gtk.TreeModel model,
                                                Gtk.TreePath path,
                                                Gtk.TreeIter iter)
    {
        Ag.AccountId account_id;
        bool changed_account_needs_attention;
        accounts_store.get (iter,
                            AccountsModel.ModelColumns.ACCOUNT_ID,
                            out account_id,
                            AccountsModel.ModelColumns.NEEDS_ATTENTION,
                            out changed_account_needs_attention,
                            -1);

        if (current_account.id == account_id)
        {
            if (changed_account_needs_attention != needs_attention)
            {
                needs_attention = changed_account_needs_attention;
                update_needs_attention_ui_state ();
            }
        }
    }
}
