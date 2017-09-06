#! /usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2013 Canonical Ltd.
# Contact: Alberto Mardegan <alberto.mardegan@canonical.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.

from autopilot.testcase import AutopilotTestCase
from autopilot.matchers import Eventually
from testtools.matchers import Contains, Equals, NotEquals, GreaterThan
from autopilot.introspection.dbus import StateNotFoundError
from time import sleep
import BaseHTTPServer, SimpleHTTPServer, SocketServer, ssl, cgi
import threading

class Handler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        s.end_headers()

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.send_header('Content-Encoding', 'utf-8')
        self.end_headers()
        self.wfile.write("""
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Login here</title></head>
<body>
<h3>Login form</h3>
<form method="POST" action="https://localhost:%(port)s/login.html">
  Username: <input type="text" name="username" size="15" /><br />
  Password: <input type="password" name="password" size="15" /><br />
  <p><input type="submit" value="Login" /></p>
</form>
</body>
</html>
""" % { 'port': self.server.server_port })
        self.server.show_login_event.set()

    def do_POST(self):
        form = cgi.FieldStorage(
            fp=self.rfile, 
            headers=self.headers,
            environ={'REQUEST_METHOD':'POST',
                     'CONTENT_TYPE':self.headers['Content-Type'],
                     })
        self.send_response(301)
        self.send_header("Location",
            "https://localhost:%(port)s/success.html#access_token=%(username)s%(password)s&expires_in=3600" % {
                'port': self.server.server_port,
                'username': form['username'].value,
                'password': form['password'].value
            })
        self.end_headers()
        self.server.login_done_event.set()


class LocalServer:
    def __init__(self):
        self.PORT = 5120
        #self.handler = SimpleHTTPServer.SimpleHTTPRequestHandler
        self.handler = Handler
        self.httpd = BaseHTTPServer.HTTPServer(("localhost", self.PORT), self.handler)
        self.httpd.show_login_event = threading.Event()
        self.httpd.login_done_event = threading.Event()
        self.httpd.socket = ssl.wrap_socket (self.httpd.socket, certfile='/etc/ssl/certs/uoa-test-server.pem', server_side=True)
        self.httpd_thread = threading.Thread(target=self.httpd.serve_forever)

    def run(self):
        self.httpd_thread.setDaemon(True)
        self.httpd_thread.start()


class ControlCenterTests(AutopilotTestCase):
    def setUp(self):
        super(ControlCenterTests, self).setUp()
        self.app = self.launch_test_application('unity-control-center', 'credentials', capture_output=True)

    def test_title(self):
        """ Checks whether the Online Accounts window title is correct """
        window = self.app.select_single('GtkApplicationWindow')
        self.assertThat(window, NotEquals(None))
        self.assertThat(window.title, Eventually(Equals('Online Accounts')))

    def test_available_providers(self):
        """ Checks whether all the expected providers are available """
        add_account_btn = self.app.select_single('GtkTextCellAccessible', accessible_name=u'Add account…')
        self.assertThat(add_account_btn, NotEquals(None))

        self.mouse.move_to_object(add_account_btn)
        self.mouse.click()

        required_providers = [
                'FakeOAuth',
                ]
        for provider in required_providers:
            provider_item = self.app.select_single('GtkTextCellAccessible', accessible_name=provider)
            self.assertThat(add_account_btn, NotEquals(None))

    def test_create_oauth2_account(self):
        """ Test the creation of an OAuth 2.0 account """
        self.server = LocalServer()
        self.server.run()

        add_account_btn = self.app.select_single('GtkTextCellAccessible', accessible_name=u'Add account…')
        self.assertThat(add_account_btn, NotEquals(None))

        self.mouse.move_to_object(add_account_btn)
        self.mouse.click()

        filter_box = self.app.select_single('GtkComboBoxAccessible', accessible_name='all')
        self.assertThat(filter_box, NotEquals(None))
        self.mouse.move_to_object(filter_box)
        self.mouse.click()

        sleep(1)
        filter_item_test = None
        # We can't use select_single, because the menu items appear twice in
        # the hirarchy
        filter_item_tests = self.app.select_many('GtkMenuItemAccessible',
                accessible_name='IntegrationTests')
        self.assertThat(len(filter_item_tests), GreaterThan(0))
        filter_item_test = filter_item_tests[0]
        self.assertThat(filter_item_test, NotEquals(None))
        self.mouse.move_to_object(filter_item_test)
        self.mouse.click()

        provider_item = self.app.wait_select_single('GtkTextCellAccessible', accessible_name='FakeOAuth')
        self.assertThat(provider_item, NotEquals(None))

        self.mouse.move_to_object(provider_item)
        self.mouse.click()

        # At this point, the signon-ui process should be spawned by D-Bus and
        # try to connect to our local webserver.
        # Here we wait until we know that the webserver has served the login page:
        self.server.httpd.show_login_event.wait(30)
        self.assertThat(self.server.httpd.show_login_event.is_set(), Equals(True))
        self.server.httpd.show_login_event.clear()

        # Give some time to signon-ui to render the page
        sleep(2)

        # Move to the username field
        self.keyboard.press_and_release('Tab')
        self.keyboard.press_and_release('Tab')
        self.keyboard.press_and_release('Tab')
        self.keyboard.press_and_release('Tab')
        self.keyboard.type('john')
        self.keyboard.press_and_release('Tab')
        self.keyboard.type('loser')
        self.keyboard.press_and_release('Enter')

        # At this point signon-ui should make a post request with the login
        # data; let's wait for it:
        self.server.httpd.login_done_event.wait(30)
        self.assertThat(self.server.httpd.login_done_event.is_set(), Equals(True))
        self.server.httpd.login_done_event.clear()

        # The account should be created shortly
        account_item = self.app.wait_select_single('GtkTextCellAccessible', accessible_name='FakeOAuth\njohn')
        self.assertThat(account_item, NotEquals(None))

        # Delete it
        self.mouse.move_to_object(account_item)
        self.mouse.click()

        remove_button = self.app.wait_select_single('GtkButtonAccessible', accessible_name='Remove Account')
        self.assertThat(remove_button, NotEquals(None))
        self.mouse.move_to_object(remove_button)
        self.mouse.click()

        sleep(1)
        self.keyboard.press_and_release('Tab')
        self.keyboard.press_and_release('Enter')

        # Check that the account has been deleted
        sleep(1)
        try:
            account_item = self.app.select_single('GtkTextCellAccessible', accessible_name='FakeOAuth\njohn')
        except StateNotFoundError:
            account_item = None
        self.assertThat(account_item, Equals(None))
