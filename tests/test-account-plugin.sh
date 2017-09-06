#!/bin/sh

# If dbus-test-runner doesn't exist, don't run the test: it would create
# unwanted records in the signon DB.
command -v dbus-test-runner > /dev/null || {
    echo "dbus-test-runner is not installed; skipping the test."
    exit 0
}

export SSO_LOGGING_LEVEL=2
export SSO_STORAGE_PATH="/tmp"
export SSO_DAEMON_TIMEOUT=5
export SSO_IDENTITY_TIMEOUT=5
export SSO_AUTHSESSION_TIMEOUT=5
# we don't want any extensions to be loaded
export SSO_EXTENSIONS_DIR="/non/existing/path"

xvfb-run --auto-servernum -- dbus-test-runner -m 360 \
    -t signond --ignore-return \
    -t ./tests/test-account-plugin \
    -f com.google.code.AccountsSSO.SingleSignOn
