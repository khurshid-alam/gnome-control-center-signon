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
 * Web credentials accounts Gtk.ListStore. Used as a model for the accounts
 * stored by libaccounts-glib.
 */
public class Cc.Credentials.AccountsModel : Gtk.ListStore
{
    private Ag.Manager accounts_manager;
    private uint[] past_failures;
    private WebcredentialsIndicator indicator;

    /**
     * Identifiers for columns in the accounts model.
     *
     * @param ACCOUNT_ID the Ag.AccountId for the Ag.Account
     * @param ACCOUNT the Ag.Account
     * @param PROVIDER_ICON the icon of the account provider
     * @param TRANSLUCENT_PIXBUF the translucent icon to show when the account
     * is disabled
     * @param ACCOUNT_DESCRIPTION the description of the account or provider
     * @param ENABLED whether the account is enabled
     * @param NEEDS_ATTENTION whether there is a problem with the account that
     * needs the attention of the user
     */
    public enum ModelColumns
    {
        ACCOUNT_ID = 0,
        ACCOUNT = 1,
        PROVIDER_ICON = 2,
        TRANSLUCENT_PIXBUF = 3,
        ACCOUNT_DESCRIPTION = 4,
        ENABLED = 5,
        NEEDS_ATTENTION = 6
    }

    private struct ColumnRecord
    {
        public uint account_id;
        public Ag.Account account;
        public Icon icon;
        public Gdk.Pixbuf translucent_pixbuf;
        public string description;
        public bool enabled;
        public bool attention;
    }

    /**
     * The account manager.
     */
    public Ag.Manager manager
    {
        get
        {
            return accounts_manager;
        }
    }

    /**
     * The Webcredentials interface used to report account authentication
     * failures.
     */
    public WebcredentialsIndicator webcredentials_interface
    {
        get
        {
            return indicator;
        }
    }

    /**
     * Create a new data model for the list of accounts.
     */
    public AccountsModel ()
    {
        Type[] types = { typeof (uint), typeof (Ag.Account), typeof (Icon),
                         typeof (Gdk.Pixbuf), typeof (string), typeof (bool),
                         typeof (bool) };
        set_column_types (types);

        accounts_manager = new Ag.Manager ();
        // Add a placeholder row at the end of the list.
        var add_account_text = _("Add account…");

        // Load a themed icon for the action of adding accounts.
        Icon provider_icon = null;

        try
        {
            provider_icon = Icon.new_for_string ("credentials-add-account");
        }
        catch (Error error)
        {
            message ("Error looking up themed add icon: %s", error.message);
        }

        insert_with_values (null, 0,
                            ModelColumns.ACCOUNT_ID, 0,
                            ModelColumns.PROVIDER_ICON, provider_icon,
                            ModelColumns.ACCOUNT_DESCRIPTION, add_account_text,
                            ModelColumns.ENABLED, true,
                            ModelColumns.NEEDS_ATTENTION, false,
                            -1);

        var accounts = accounts_manager.list ();

        // Sort by account ID.
        accounts.sort ((a, b) => { return (int)a - (int)b; });
        accounts.foreach (add_account);

        try
        {

            indicator = Bus.get_proxy_sync (BusType.SESSION,
                                            "com.canonical.indicators.webcredentials",
                                            "/com/canonical/indicators/webcredentials");

            var indicator_proxy = indicator as DBusProxy;
            indicator_proxy.g_properties_changed.connect (on_proxy_properties_changed);
            // Get the current list of failures.
            on_indicator_notify_failures ();
        }
        catch (IOError err)
        {
            warning ("Error initializing indicator proxy: %s\nAccount attention monitoring will be disabled", err.message);
        }

        accounts_manager.account_created.connect (on_account_created);
        accounts_manager.account_deleted.connect (on_account_deleted);
        accounts_manager.account_updated.connect (on_account_updated);
    }

    /**
     * Instantiate an account from the supplied account ID, and add it to the
     * list of accounts.
     *
     * This method is intended to be used with the foreach method of GLib
     * containers.
     *
     * @param account_id an Ag.AccountId to add to the list of accounts
     */
    private void add_account (uint account_id)
    {
        Ag.Account account;

        try
        {
            account = accounts_manager.load_account (account_id);
        }
        catch (Error error)
        {
            critical ("Unable to instantiate account: %s", error.message);
            return;
        }

        /* Insert the new account at the bottom of the list of accounts, but
         * before the ‘Add account’ row.
         */
        var record = fill_column_record (account_id);
        insert_with_values (null, this.iter_n_children (null) - 1,
                            ModelColumns.ACCOUNT_ID, record.account_id,
                            ModelColumns.ACCOUNT, record.account,
                            ModelColumns.PROVIDER_ICON, record.icon,
                            ModelColumns.TRANSLUCENT_PIXBUF, record.translucent_pixbuf,
                            ModelColumns.ACCOUNT_DESCRIPTION, record.description,
                            ModelColumns.ENABLED, record.enabled,
                            ModelColumns.NEEDS_ATTENTION, record.attention,
                            -1);
    }

    /**
     * Get an iter to a row in the model with a matching Ag.AccountId.
     *
     * The row in the model for adding a new account (which has an accound ID
     * of 0) is special, as it is always the last row. Additionally, false is
     * always returned when searching for that row.
     *
     * @param account_id the Ag.AccountId of an Ag.Account described in the
     * model
     * @return true if the account_id existed in the model, false otherwise
     */
    public bool find_iter_for_account_id (Ag.AccountId account_id,
                                          out Gtk.TreeIter iter)
    {
        Gtk.TreeIter local_iter;

        this.get_iter_first (out local_iter);

        // Special-case the "Add account…" row so that it is never changed.
        if (account_id == 0)
        {
            iter = local_iter;
            return false;
        }

        var found = false;
        do
        {
            Ag.AccountId model_account_id;
            this.get (local_iter, ModelColumns.ACCOUNT_ID, out model_account_id,
                      -1);

            if (account_id == model_account_id)
            {
                found = true;
                break;
            }
        } while (this.iter_next (ref local_iter));

        iter = local_iter;
        return found;
    }

    /**
     * Create a translucent Gdk.Pixbuf from a GLib.Icon.
     *
     * @param gicon the GLib.Icon to create a translucent pixbuf for
     */
    private Gdk.Pixbuf translucent_from_gicon (Icon gicon)
    {
        var icon_theme = Gtk.IconTheme.get_default ();
        
        try
        {
            var pixbuf = icon_theme.load_icon (gicon.to_string (),
                                               32, // Size in pixels.
                                               0); // No lookup flags.
            var temp_pixbuf = new Gdk.Pixbuf (pixbuf.get_colorspace (),
                                              true,
                                              pixbuf.get_bits_per_sample (),
                                              pixbuf.get_width (),
                                              pixbuf.get_height ());
            temp_pixbuf.fill (0);

            // Make the icon translucent.
            pixbuf.composite (temp_pixbuf, 0, 0, pixbuf.get_width (), pixbuf.get_height (), 0.0, 0.0, 1.0, 1.0, Gdk.InterpType.BILINEAR, 255 / 2);
            return temp_pixbuf;
        }
        catch (Error err)
        {
            message ("Error loading icon '%s': %s", gicon.to_string (),
                     err.message);
            return new Gdk.Pixbuf (Gdk.Colorspace.RGB,
                                   true, // Has alpha channel.
                                   8, // Bits per sample.
                                   32, // Width.
                                   32); // Height.
        }
    }

    /**
     * Handle D-Bus property changes on the indicator proxy.
     *
     * @param changed_properties dictionary of changed property names and
     * values
     * @param invalidated_properties array of names of invalidated properties
     */
    private void on_proxy_properties_changed (Variant changed_properties,
                                              string invalidated_properties[])
    {
        var iter = changed_properties.iterator ();

        Variant change;
        while ((change = iter.next_value ()) != null)
        {
            string property_name;
            change.get ("{sv}", out property_name, null);

            if (property_name == "Failures")
            {
                on_indicator_notify_failures ();
            }
        }
    }

    /**
     * Handle account authentication failures, marking the failing accounts as
     * needing attention.
     */
    private void on_indicator_notify_failures ()
    {
        var failures = indicator.failures;

        if (past_failures == null && failures == null)
        {
            return;
        }

        /* Vala uses the _TO_POINTER macros to insert bools and uints, so use
         * direct_hash and direct_equal.
         */
        var failures_hash = new HashTable<uint, bool> (direct_hash, direct_equal);

        if (past_failures != null)
        {
            foreach (var past_failure in past_failures)
            {
                failures_hash.insert (past_failure, false);
            }
        }

        if (failures != null)
        {
            foreach (var failure in failures)
            {
                failures_hash.insert (failure, true);
            }
        }

        past_failures = failures;
        failures_hash.foreach (set_failure);
    }

    /**
     * Set the failure state for an account id in the model.
     *
     * @param account_id the account ID for which to set the failure
     * @param failure true if the account should be marked as failing, false if
     * the account failure state should be cleared
     */
    private void set_failure (uint account_id, bool failure)
    {
        Gtk.TreeIter iter;

        if (find_iter_for_account_id (account_id, out iter))
        {
            this.set (iter, ModelColumns.NEEDS_ATTENTION, failure, -1);
        }
        else
        {
            message ("Failure change reported for non-existent account ID: %u",
                     account_id);
        }
    }

    /**
     * Handle the account-created signal on Ag.Manager.
     *
     * @param id the Ag.AccountId of the Ag.Account that was created
     */
    private void on_account_created (uint id)
    {
        Ag.AccountId account_id = (Ag.AccountId) id;

        add_account (account_id);
    }

    /**
     * Handle the account-deleted signal on Ag.Manager.
     *
     * @param id the Ag.AccountId of the Ag.Account that was deleted
     */
    private void on_account_deleted (uint id)
    {
        Ag.AccountId account_id = (Ag.AccountId) id;

        Gtk.TreeIter iter;
        if (find_iter_for_account_id (account_id, out iter))
        {
            this.remove (iter);
        }
        else
        {
            warning ("Account with ID %u was already removed", id);
        }
    }

    /**
     * Handle the account-updated signal on Ag.Manager.
     *
     * @param id the Ag.AccountId of the Ag.Account that was updated
     */
    private void on_account_updated (uint id)
    {
        Ag.AccountId account_id = (Ag.AccountId) id;

        Gtk.TreeIter iter;
        if (find_iter_for_account_id (account_id, out iter))
        {
            // Unconditionally copy the data from the changed account.
            var record = fill_column_record (account_id);
            this.set (iter,
                      ModelColumns.PROVIDER_ICON, record.icon,
                      ModelColumns.TRANSLUCENT_PIXBUF, record.translucent_pixbuf, 
                      ModelColumns.ACCOUNT_DESCRIPTION, record.description,
                      ModelColumns.ENABLED, record.enabled,
                      ModelColumns.NEEDS_ATTENTION, record.attention,
                      -1);
        }
        else
        {
            warning ("Account with ID %u was updated, but did not already exist in the model",
                     id);
            add_account (account_id);
        }
    }

    /**
     * Handle the account enabled state being changed, and update the model
     * accordingly.
     *
     * @param account the account which was updated
     * @param service the service which was changed. Ignored
     * @param enabled the current state of the account
     */
    private void on_account_enabled (Ag.Account account,
                                     string? service,
                                     bool enabled)
    {
        // Ignore service-level changes.
        // FIXME: http://code.google.com/p/accounts-sso/issues/detail?id=157
        if (service != "global" || service != null)
        {
            return;
        }

        Gtk.TreeIter iter;
        bool model_enabled;
        if (find_iter_for_account_id (account.id, out iter))
        {
            this.get (iter, ModelColumns.ENABLED, out model_enabled);

            if (model_enabled != enabled)
            {
                this.set (iter,
                          ModelColumns.ACCOUNT_DESCRIPTION, format_account_description (account),
                          ModelColumns.ENABLED, enabled,
                          -1);
            }
        }
        else
        {
            message ("Enabled state change reported for non-existent account ID: %u",
                     account.id);
        }
    }

    /**
     * Handle the account display name being changed, and update the model
     * accordingly.
     *
     * @param account the account which was updated
     */
    private void on_account_display_name_changed (Ag.Account account)
    {

        Gtk.TreeIter iter;
        if (find_iter_for_account_id (account.id, out iter))
        {
            this.set (iter,
                      ModelColumns.ACCOUNT_DESCRIPTION, format_account_description (account),
                      -1);
        }
        else
        {
            message ("Enabled state change reported for non-existent account ID: %u",
                     account.id);
        }
    }

    /**
     * Fill in a ColumnRecord structure with details of the account, for using
     * to fill in a row in the model.
     *
     * @param account_id the ID of the Ag.Account
     * @return a new ColumnRecord
     */
    private ColumnRecord fill_column_record (uint account_id)
    {
        var account = accounts_manager.get_account ((Ag.AccountId) account_id);

        var record = ColumnRecord ();
        // FIXME: Add provider property to Ag.Account, and use it here.
        var display_name = account.get_display_name ();
        record.enabled = account.get_enabled ();
        var name_markup = record.enabled ? display_name :
            "<span foreground=\"#555555\">" + display_name + "</span>";
        var provider = manager.get_provider (account.get_provider_name ());
        record.account_id = account_id;
        record.account = account;

        try
        {
            record.icon = Icon.new_for_string (provider.get_icon_name ());
        }
        catch (Error error)
        {
            message ("Error looking up themed provider icon: %s",
                     error.message);
            record.icon = null;
        }

        record.translucent_pixbuf = translucent_from_gicon (record.icon);

        // Also see format_account_description ().
        record.description = provider.get_display_name () + "\n"
                             + "<small>" + name_markup + "</small>";
        record.attention = false;

        account.enabled.connect (on_account_enabled);
        account.display_name_changed.connect (on_account_display_name_changed);

        return record;
    }

    /**
     * Provide a string describing the account for display to the user.
     *
     * @param account the account for which to generate the description
     * @return the account description
     */
    private string format_account_description (Ag.Account account)
    {
        var provider = manager.get_provider (account.get_provider_name ());
        var display_name = account.get_display_name ();
        var name_markup = account.get_enabled () ? display_name :
            "<span foreground=\"#555555\">" + display_name + "</span>";
        return provider.get_display_name () + "\n"
               + "<small>" + name_markup + "</small>";
    }
}
