AC_INIT([Credentials Control Center],
        [0.1.7],
        [https://bugs.launchpad.net/gnome-control-center-signon],
        [credentials-control-center],
        [https://launchpad.net/gnome-control-center-signon])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_SRCDIR([src/cc-credentials-panel.c])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 -Wall no-dist-gzip dist-xz tar-ustar check-news no-define subdir-objects])
AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

# Gobject Introspection
GOBJECT_INTROSPECTION_CHECK([1.30.0])

# Check for programs
AC_PROG_CC
AM_PROG_CC_C_O
OVERRIDE_PROG_VALAC([0.15.1], [valac-0.16 valac-0.14 valac])

LT_PREREQ([2.2])
LT_INIT([disable-static])

# API reference documentation.
# The gtk-doc check MUST appear after the libtool check, so that
# gtkdoc-scangobj can parse libtool archives.
GTK_DOC_CHECK([1.14], [--flavour no-tmpl])

# Internationalization support
IT_PROG_INTLTOOL([0.40.1])

AC_SUBST([GETTEXT_PACKAGE], [$PACKAGE_TARNAME])
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], "$GETTEXT_PACKAGE", [Gettext package])

GNOME_COMPILE_WARNINGS([maximum])
GNOME_MAINTAINER_MODE_DEFINES

PKG_PROG_PKG_CONFIG([0.24])

# Libraries.
LIBACCOUNTS_GLIB_REQUIRED="libaccounts-glib >= 1.10"
LIBSIGNON_GLIB_REQUIRED="libsignon-glib >= 1.8"
GLIB_REQUIRED="glib-2.0 gio-2.0 gio-unix-2.0 >= 2.29.5"
GMODULE_REQUIRED="gmodule-2.0"
GTK_REQUIRED="gtk+-3.0 >= 3.0.0"
UNITY_CONTROL_CENTER_REQUIRED="libunity-control-center"

AC_ARG_VAR([control_center_extensiondir],
  [Install control center panel to the given extension dir. Alternatively, get the installation path from pkg-config.])

AC_ARG_WITH([unity-control-center],
  [AS_HELP_STRING([--without-unity-control-center],
    [Ignore the presence of unity-control-center and disable it])])

AS_IF([test "x$with_unity_control_center" != "xno"],
  [PKG_CHECK_EXISTS([$UNITY_CONTROL_CENTER_REQUIRED],
    [have_unity_control_center=yes],
    [have_unity_control_center=no])],
  [have_unity_control_center=no])

AS_IF([test "x$have_unity_control_center" = "xyes"],
  [AS_IF([test -n "$control_center_extensiondir"],
    [AC_SUBST([CCPANELDIR], [$control_center_extensiondir])],
    [AC_SUBST([CCPANELDIR], [`$PKG_CONFIG --variable=extensiondir $UNITY_CONTROL_CENTER_REQUIRED`])])],
  [UNITY_CONTROL_CENTER_REQUIRED=""
   AS_IF([test "x$with_unity_control_center" = "xyes"],
    [AC_MSG_ERROR([unity-control-center support requested but not found])])])

AM_CONDITIONAL([WITH_UNITY_CONTROL_CENTER],
  [test "x$have_unity_control_center" = "xyes"])

# Standalone preferences binary.
AC_ARG_ENABLE([standalone-preferences],
  [AS_HELP_STRING([--disable-standalone-preferences],
    [Build without a standalone preferences binary])])

AS_IF([test "x$enable_standalone_preferences" != "xno"],
  [have_standalone_preferences=yes],
  [have_standalone_preferences=no])

AM_CONDITIONAL([ENABLE_STANDALONE_PREFERENCES],
  [test "x$have_standalone_preferences" = "xyes"])

AS_IF([test "x$have_standalone_preferences" = "xno" -a \
   "x$have_unity_control_center" = "xno"],
  [AC_MSG_WARN([Both the standalone preferences panel and the unity-control-center panel are disabled. Only libaccount-plugin will be built.])])

PKG_CHECK_MODULES([CREDENTIALS_PANEL],
  [$LIBACCOUNTS_GLIB_REQUIRED
   $LIBSIGNON_GLIB_REQUIRED
   $GLIB_REQUIRED
   $GTK_REQUIRED
   $UNITY_CONTROL_CENTER_REQUIRED])

# libaccount-plugin variables.
AC_SUBST([LIBACCOUNT_PLUGIN_SO_VERSION], [1:0:1])
AC_SUBST([LIBACCOUNT_PLUGIN_API_VERSION], [1.0])
LIBACCOUNT_PLUGIN_DIR="$libdir/libaccount-plugin-$LIBACCOUNT_PLUGIN_API_VERSION"
AC_SUBST(LIBACCOUNT_PLUGIN_DIR)

# libaccount-plugin dependencies.
PKG_CHECK_MODULES([LIBACCOUNT_PLUGIN],
  [$LIBACCOUNTS_GLIB_REQUIRED
   $LIBSIGNON_GLIB_REQUIRED
   $GLIB_REQUIRED
   $GMODULE_REQUIRED
   $GTK_REQUIRED])

# update-accounts tool dependencies.
PKG_CHECK_MODULES([UPDATE_ACCOUNTS],
  [$LIBACCOUNTS_GLIB_REQUIRED
   $GLIB_REQUIRED])

# Check for GLib, Xvfb and D-Bus testing utilities.
AC_PATH_PROG([GTESTER], [gtester], [notfound])
AC_PATH_PROG([GTESTER_REPORT], [gtester-report], [notfound])
AC_PATH_PROG([XVFB_RUN], [xvfb-run], [notfound])
AC_PATH_PROG([DBUS_TEST_RUNNER], [dbus-test-runner], [notfound])
AS_IF([test "x$GTESTER" = "xnotfound" -o "x$GTESTER_REPORT" = "xnotfound" -o \
   "x$XVFB_RUN" = "xnotfound" -o "x$DBUS_TEST_RUNNER" = "xnotfound"],
  [AC_MSG_WARN([testing disabled as the required utilities were not found])],
  [CREDENTIALS_ENABLE_TESTS=true
   AC_SUBST([GTESTER])
   AC_SUBST([GTESTER_REPORT])
   AC_SUBST([XVFB_RUN])
   AC_SUBST([DBUS_TEST_RUNNER])])
AM_CONDITIONAL([CREDENTIALS_ENABLE_TESTS], [test "x$CREDENTIALS_ENABLE_TESTS" = "xtrue"])

# Check for lcov.
AC_ARG_ENABLE([coverage],
  [AS_HELP_STRING([--disable-coverage], [Disable code coverage testing and reporting])])

AS_IF([test "x$enable_coverage" != "xno"],
  [AC_PATH_PROG([LCOV], [lcov], [notfound])
   AC_PATH_PROG([LCOV_GENHTML], [genhtml], [notfound])
   AS_IF([test "x$LCOV" = "xnotfound" -o "x$LCOV_GENHTML" = "xnotfound"],
     [have_coverage=no],
     [have_coverage=yes])],
  [have_coverage=no])

AS_IF([test "x$have_coverage" = "xyes"],
  [AC_SUBST([LCOV])
   AC_SUBST([LCOV_GENHTML])
   CFLAGS="$CFLAGS -O0 -fprofile-arcs -ftest-coverage"
   LDFLAGS="$LDFLAGS -lgcov"],
  [AS_IF([test "x$enable_coverage" = "xyes"],
     [AC_MSG_ERROR([code coverage testing and reporting requested but the required utilites were not found])])])

AM_CONDITIONAL([CREDENTIALS_ENABLE_COVERAGE], [test "x$have_coverage" = "xyes"])

# Mallard help.
YELP_HELP_INIT

AC_CONFIG_FILES([
Makefile
data/credentials-preferences.desktop.in
data/unity-credentials-panel.desktop.in
data/update-accounts.desktop.in
doc/account-plugin/Makefile
doc/account-plugin/version.xml
help/Makefile
libaccount-plugin/account-plugin.pc
po/Makefile.in
])

AC_OUTPUT
