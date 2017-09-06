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
 *      Alvaro Lopez Ortega <alvaro@canonical.com>
 *      David King <david.king@canonical.com>
 */

#include <gtk/gtk.h>
#include <libunity-control-center/cc-panel.h>
#include <glib/gi18n-lib.h>
#include <stdlib.h>
#include "config.h"

extern void* cc_credentials_preferences_new (void);
extern void* cc_credentials_preferences_new_with_account_details (guint account_id);
extern void* cc_credentials_preferences_new_with_application (const gchar *application);

GType cc_credentials_panel_get_type(void);

#define CC_TYPE_CREDENTIALS_PANEL (cc_credentials_panel_get_type ())
#define CC_CREDENTIALS_PANEL(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), CC_TYPE_CREDENTIALS_PANEL, CcCredentialsPanel))

typedef struct _CcCredentialsPanel CcCredentialsPanel;
typedef struct _CcCredentialsPanelClass CcCredentialsPanelClass;
typedef struct _CcCredentialsPanelPrivate CcCredentialsPanelPrivate;

typedef enum _StartupAction StartupAction;

/**
 * StartupAction:
 * @CREDENTIALS_ACTION_DEFAULT: the default action, which shows the list of
 * accounts
 * @CREDENTAILS_ACTION_ACCOUNT_DETAILS: show the details of a specific account
 *
 * The action to perform when the panel is first displayed.
 */
enum _StartupAction
{
    CREDENTIALS_ACTION_DEFAULT,
    CREDENTIALS_ACTION_ACCOUNT_DETAILS,
    CREDENTIALS_ACTION_APPLICATION
};

struct _CcCredentialsPanel
{
    CcPanel parent_instance;
    CcCredentialsPanelPrivate *priv;
};

struct _CcCredentialsPanelClass
{
    CcPanelClass parent_class;
};

struct _CcCredentialsPanelPrivate
{
    StartupAction startup_action;
    guint account_id;
    gchar *application_name;
};

enum
{
    PROP_0,
    PROP_ARGV
};

G_DEFINE_DYNAMIC_TYPE (CcCredentialsPanel, cc_credentials_panel, CC_TYPE_PANEL)

static void
cc_credentials_panel_get_property (GObject *object,
                                   guint property_id,
                                   GValue *value,
                                   GParamSpec *pspec)
{
    switch (property_id)
    {
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
    }
}

static void
cc_credentials_panel_set_property (GObject *object,
                                   guint property_id,
                                   const GValue *value,
                                   GParamSpec *pspec)
{
    CcCredentialsPanel *self = CC_CREDENTIALS_PANEL (object);
    CcCredentialsPanelPrivate *priv = self->priv;

    switch (property_id)
    {
    case PROP_ARGV:
    {
        gchar **argv;

        priv->startup_action = CREDENTIALS_ACTION_DEFAULT;

        argv = g_value_get_boxed (value);

        if (argv && argv[0])
        {
            static const gchar ACCOUNT_DETAILS[] = "account-details=";
            static const gchar APPLICATION[] = "application=";

            g_debug ("Startup argument given: %s", argv[0]);

            if (g_str_has_prefix (argv[0], ACCOUNT_DETAILS))
            {
                priv->startup_action = CREDENTIALS_ACTION_ACCOUNT_DETAILS;
                /* Strip off the argument text. */
                priv->account_id = atoi (argv[0]
                                         + sizeof (ACCOUNT_DETAILS)
                                         - 1);
            }
            else if (g_str_has_prefix (argv[0], APPLICATION))
            {
                /* Providing an application changes the startup action, but the
                 * effect is not visible until the account details view is
                 * displayed.
                 */
                priv->startup_action = CREDENTIALS_ACTION_APPLICATION;
                /* Strip off the argument text. */
                priv->application_name = g_strdup (argv[0]
                                                   + sizeof (APPLICATION)
                                                   - 1);
            }
        }
    }
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
    }
}

static void
cc_credentials_panel_constructed (GObject *object)
{
    GtkWidget *widget;
    CcCredentialsPanel *self;
    CcCredentialsPanelPrivate *priv;

    self = CC_CREDENTIALS_PANEL (object);
    priv = self->priv;

    switch (priv->startup_action)
    {
    case CREDENTIALS_ACTION_APPLICATION:
        widget = GTK_WIDGET (cc_credentials_preferences_new_with_application (priv->application_name));
        break;
    case CREDENTIALS_ACTION_ACCOUNT_DETAILS:
        widget = GTK_WIDGET (cc_credentials_preferences_new_with_account_details (priv->account_id));
        break;
    case CREDENTIALS_ACTION_DEFAULT:
        widget = GTK_WIDGET (cc_credentials_preferences_new ());
        break;
    default:
        g_assert_not_reached ();
    }

    gtk_widget_show_all (widget);

    gtk_container_add (GTK_CONTAINER (self), widget);
}

static void
cc_credentials_panel_finalize (GObject *object)
{
    CcCredentialsPanelPrivate *priv = ((CcCredentialsPanel *) object)->priv;

    if (priv->application_name)
    {
        g_free (priv->application_name);
    }

    G_OBJECT_CLASS (cc_credentials_panel_parent_class)->finalize (object);
}

static void
cc_credentials_panel_class_finalize (CcCredentialsPanelClass *klass)
{
}

static const char *
cc_credentials_panel_get_help_uri (CcPanel *panel)
{
    return "help:ubuntu-help/accounts";
}

static void
cc_credentials_panel_class_init (CcCredentialsPanelClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    CcPanelClass *panel_class = CC_PANEL_CLASS (klass);
    g_type_class_add_private (klass, sizeof (CcCredentialsPanelPrivate));

    object_class->get_property = cc_credentials_panel_get_property;
    object_class->set_property = cc_credentials_panel_set_property;
    object_class->constructed = cc_credentials_panel_constructed;
    object_class->finalize = cc_credentials_panel_finalize;

    panel_class->get_help_uri = cc_credentials_panel_get_help_uri;

    g_object_class_override_property (object_class, PROP_ARGV, "argv");
}

static void
cc_credentials_panel_init (CcCredentialsPanel *self)
{
    self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, CC_TYPE_CREDENTIALS_PANEL,
                                              CcCredentialsPanelPrivate);
}

void
g_io_module_load (GIOModule *module)
{
    bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
    bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

    /* Generated by G_DEFINE_DYNAMIC_TYPE. */
    cc_credentials_panel_register_type (G_TYPE_MODULE (module));
    g_io_extension_point_implement (CC_SHELL_PANEL_EXTENSION_POINT,
                                    CC_TYPE_CREDENTIALS_PANEL,
                                    "credentials", 0);
}

void g_io_module_unload (GIOModule *module)
{
}
