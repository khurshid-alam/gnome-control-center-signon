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
 * Used to monitor the Failures property, so that accounts with login failures
 * can be marked as needing attention.
 */
[DBus (name = "com.canonical.indicators.webcredentials")]
public interface Cc.WebcredentialsIndicator : Object
{
    public abstract uint[] failures { owned get; }
    public abstract async void report_failure (uint account_id,
                                               HashTable<string, Variant> notification) throws IOError;
    public abstract async void remove_failures (uint[] account_ids)
        throws IOError;
    public abstract async void clear_error_status () throws IOError;
}
