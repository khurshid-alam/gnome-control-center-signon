/* vi: set et sw=4 ts=4 cino=t0,(0: */
/* -*- Mode: C; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * This file is part of libaccount-plugin
 *
 * Copyright (C) 2012 Canonical Ltd.
 *
 * Contact: Alberto Mardegan <alberto.mardegan@canonical.com>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License version 3, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _AP_CLIENT_H_
#define _AP_CLIENT_H_

#include <glib.h>
#include <libaccounts-glib/ag-account.h>
#include <libaccounts-glib/ag-application.h>

G_BEGIN_DECLS

typedef struct _ApPlugin ApPlugin;
typedef struct _ApApplicationPlugin ApApplicationPlugin;

ApPlugin *ap_client_load_plugin (AgAccount *account);
gboolean ap_client_has_plugin (AgProvider *provider);

ApApplicationPlugin *
ap_client_load_application_plugin (AgApplication *application,
                                   AgAccount *account);

G_END_DECLS

#endif /* _AP_CLIENT_H_ */
