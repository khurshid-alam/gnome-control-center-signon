SUBDIRS = help po

DISTCHECK_CONFIGURE_FLAGS = \
	--enable-gtk-doc \
	--enable-introspection=yes \
	--with-unity-control-center

# libaccount-plugin.
lib_LTLIBRARIES = libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la

libaccount_plugin_@LIBACCOUNT_PLUGIN_API_VERSION@_la_CPPFLAGS = \
	-include $(top_builddir)/config.h \
	-DLIBACCOUNT_PLUGIN_DIR=\"$(LIBACCOUNT_PLUGIN_DIR)\" \
	-DG_LOG_DOMAIN=\"account-plugin\" \
	$(LIBACCOUNT_PLUGIN_CFLAGS) \
	$(WARN_CFLAGS)
libaccount_plugin_@LIBACCOUNT_PLUGIN_API_VERSION@_la_LIBADD = \
	$(LIBACCOUNT_PLUGIN_LIBS)
libaccount_plugin_@LIBACCOUNT_PLUGIN_API_VERSION@_la_LDFLAGS = \
	-version-info $(LIBACCOUNT_PLUGIN_SO_VERSION) \
	-export-symbols-regex '^ap_'
libaccount_plugin_@LIBACCOUNT_PLUGIN_API_VERSION@_la_SOURCES = \
	libaccount-plugin/application-plugin.c \
	libaccount-plugin/client.c \
	libaccount-plugin/oauth-plugin.c \
	libaccount-plugin/plugin.c
libaccount_plugin_includedir = $(includedir)/libaccount-plugin
libaccount_plugin_include_HEADERS = \
	libaccount-plugin/account-plugin.h \
	libaccount-plugin/application-plugin.h \
	libaccount-plugin/client.h \
	libaccount-plugin/oauth-plugin.h \
	libaccount-plugin/plugin.h \
	libaccount-plugin/module.h

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = libaccount-plugin/AccountPlugin.vapi

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libaccount-plugin/account-plugin.pc

# Credentials control center applet.
cappletname = credentials

if WITH_UNITY_CONTROL_CENTER
ccpanelsdir = $(CCPANELDIR)
ccpanels_LTLIBRARIES = libcredentials.la
endif

common_cppflags = \
	$(CREDENTIALS_PANEL_CFLAGS) \
	-include $(top_builddir)/config.h \
	-DG_LOG_DOMAIN=\"\$(cappletname)-cc-panel\" \
	-DGNOMELOCALEDIR="\"$(datadir)/locale\"" \
	-DGNOMECC_DATA_DIR="\"$(pkgdatadir)\"" \
	$(WARN_CFLAGS)

libcredentials_la_CPPFLAGS = \
	$(common_cppflags)

VALAFLAGS = \
	--vapidir $(top_srcdir)/src \
	--vapidir $(top_srcdir)/libaccount-plugin \
	--pkg config \
	--pkg AccountPlugin \
	--pkg libaccounts-glib \
	--pkg assertions \
	--pkg posix \
	--pkg signon \
	--pkg gtk+-3.0 \
	--pkg gmodule-2.0

common_vala_sources = \
	src/cc-credentials-account-applications-model.vala \
	src/cc-credentials-account-details-page.vala \
	src/cc-credentials-accounts-model.vala \
	src/cc-credentials-accounts-page.vala \
	src/cc-credentials-applications-model.vala \
	src/cc-credentials-authorization-page.vala \
	src/cc-credentials-login-capture.vala \
	src/cc-credentials-preferences.vala \
	src/cc-credentials-providers-model.vala \
	src/cc-credentials-providers-page.vala \
	src/cc-webcredentials-indicator.vala

libcredentials_la_SOURCES = \
	$(common_vala_sources) \
	src/cc-credentials-panel.c

libcredentials_la_LIBADD = \
	$(CREDENTIALS_PANEL_LIBS) \
	libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la
libcredentials_la_LDFLAGS = \
	-export_dynamic \
	-avoid-version \
	-module \
	-no-undefined \
	-export-symbols-regex '^g_io_module_(load|unload)'

if ENABLE_STANDALONE_PREFERENCES
bin_PROGRAMS = credentials-preferences
else !ENABLE_STANDALONE_PREFERENCES
noinst_PROGRAMS = credentials-preferences
if WITH_UNITY_CONTROL_CENTER
preferences_ldadd = libcredentials.la
endif
endif

online-accounts-preferences: online-accounts-preferences.in Makefile
	$(AM_V_GEN)$(SED) -e "s|\@DESKTOPDIR\@|$(desktopdir)|" $< > $@
	$(AM_V_at)chmod +x $@

bin_SCRIPTS = \
	online-accounts-preferences

credentials_preferences_CPPFLAGS = \
	$(common_cppflags)

credentials_preferences_SOURCES = \
	$(common_vala_sources) \
	src/cc-credentials-application.vala

credentials_preferences_LDADD = \
	$(CREDENTIALS_PANEL_LIBS) \
	libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la \
	$(preferences_ldadd)

# Account update tool for enabling new services
libexec_PROGRAMS = update-accounts

update_accounts_CPPFLAGS = \
	-include $(top_builddir)/config.h \
	$(UPDATE_ACCOUNTS_CFLAGS) \
	$(WARN_CFLAGS)

update_accounts_SOURCES = \
	tools/update-accounts.c

update_accounts_LDADD = \
	$(UPDATE_ACCOUNTS_LIBS)

# Tests.
tests/test-control-center.sh: Makefile
	$(AM_V_GEN)echo "#!/bin/sh -e" > $@; \
		echo "for testcase in $(tests_nodbus)" >> $@; \
		echo "do" >> $@; \
		echo "    $(XVFB_RUN) --auto-servernum -- $(DBUS_TEST_RUNNER) --task=$(top_builddir)/\$$testcase || exit 1" >> $@; \
		echo "done" >> $@; \
		chmod +x $@

tests_nodbus = \
	tests/test-account-applications-model \
	tests/test-account-details-page \
	tests/test-accounts-model \
	tests/test-accounts-page \
	tests/test-applications-model \
	tests/test-authorization-page \
	tests/test-preferences \
	tests/test-providers-model \
	tests/test-providers-page
tests_dbus = \
	tests/test-account-plugin
if CREDENTIALS_ENABLE_TESTS
check_PROGRAMS = \
	$(tests_nodbus) \
	$(tests_dbus)
dist_check_SCRIPTS = \
	tests/test-account-plugin.sh
check_SCRIPTS = \
	tests/test-control-center.sh
endif

if WITH_UNITY_CONTROL_CENTER
tests_ldadd = \
	$(CREDENTIALS_PANEL_LIBS) \
	libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la \
	libcredentials.la
else !WITH_UNITY_CONTROL_CENTER
tests_ldadd = \
	$(CREDENTIALS_PANEL_LIBS) \
	libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la
endif

tests_test_account_applications_model_SOURCES = \
	$(common_vala_sources) \
	tests/test-account-applications-model.vala

tests_test_account_applications_model_CPPFLAGS = \
	$(common_cppflags)

tests_test_account_applications_model_LDADD = \
	$(tests_ldadd)

tests_test_account_details_page_SOURCES = \
	$(common_vala_sources) \
	tests/test-account-details-page.vala

tests_test_account_details_page_CPPFLAGS = \
	$(common_cppflags)

tests_test_account_details_page_LDADD = \
	$(tests_ldadd)

tests_test_accounts_model_SOURCES = \
	$(common_vala_sources) \
	tests/test-accounts-model.vala

tests_test_accounts_model_CPPFLAGS = \
	$(common_cppflags)

tests_test_accounts_model_LDADD = \
	$(tests_ldadd)

tests_test_accounts_page_SOURCES = \
	$(common_vala_sources) \
	tests/test-accounts-page.vala

tests_test_accounts_page_CPPFLAGS = \
	$(common_cppflags)

tests_test_accounts_page_LDADD = \
	$(tests_ldadd)

tests_test_applications_model_SOURCES = \
	$(common_vala_sources) \
	tests/test-applications-model.vala

tests_test_applications_model_CPPFLAGS = \
	$(common_cppflags)

tests_test_applications_model_LDADD = \
	$(tests_ldadd)

tests_test_authorization_page_SOURCES = \
	$(common_vala_sources) \
	tests/test-authorization-page.vala

tests_test_authorization_page_CPPFLAGS = \
	$(common_cppflags)

tests_test_authorization_page_LDADD = \
	$(tests_ldadd)

tests_test_preferences_SOURCES = \
	$(common_vala_sources) \
	tests/test-preferences.vala

tests_test_preferences_CPPFLAGS = \
	$(common_cppflags)

tests_test_preferences_LDADD = \
	$(tests_ldadd)

tests_test_providers_model_SOURCES = \
	$(common_vala_sources) \
	tests/test-providers-model.vala

tests_test_providers_model_CPPFLAGS = \
	$(common_cppflags)

tests_test_providers_model_LDADD = \
	$(tests_ldadd)

tests_test_providers_page_SOURCES = \
	$(common_vala_sources) \
	tests/test-providers-page.vala

tests_test_providers_page_CPPFLAGS = \
	$(common_cppflags)

tests_test_providers_page_LDADD = \
	$(tests_ldadd)

tests_test_account_plugin_SOURCES = \
	$(common_vala_sources) \
	libaccount-plugin/oauth-plugin.c \
	tests/test-account-plugin.vala

tests_test_account_plugin_CPPFLAGS = \
	$(common_cppflags) \
	-DBUILDING_UNIT_TESTS

tests_test_account_plugin_LDADD = \
	$(CREDENTIALS_PANEL_LIBS) \
	libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la

if CREDENTIALS_ENABLE_TESTS
TESTS_ENVIRONMENT = \
	MALLOC_CHECK_=2 \
	MALLOC_PERTURB_=$$(($${RANDOM:-256} % 256)) \
	ACCOUNTS=/tmp \
	AG_APPLICATIONS=$(top_srcdir)/tests/data \
	AG_SERVICES=$(top_srcdir)/tests/data \
	AG_SERVICE_TYPES=$(top_srcdir)/tests/data \
	AG_PROVIDERS=$(top_srcdir)/tests/data \
	AG_DEBUG=all \
	G_DEBUG=gc-friendly \
	G_MESSAGES_DEBUG=all \
	G_SLICE=always-malloc,debug-blocks \
	SSO_LOGGING_LEVEL=2 \
	SSO_STORAGE_PATH="/tmp" \
	SSO_DAEMON_TIMEOUT=5 \
	SSO_IDENTITY_TIMEOUT=5 \
	SSO_AUTHSESSION_TIMEOUT=5 \
	SSO_EXTENSIONS_DIR="/non/existing/path" \
	UBUNTU_MENUPROXY=""

TESTS = \
	$(dist_check_SCRIPTS) \
	$(check_SCRIPTS)

# test-report: run tests and generate report.
# perf-report: run tests with -m perf and generate report.
# full-report: like test-report: with -m perf and -m slow.
test-report perf-report full-report: $(check_PROGRAMS)
	$(AM_V_at)test -z "$(check_PROGRAMS)" || { \
	  case $@ in \
	  test-report) test_options="-k";; \
	  perf-report) test_options="-k -m=perf";; \
	  full-report) test_options="-k -m=perf -m=slow";; \
	  esac ; \
	  $(TESTS_ENVIRONMENT) $(GTESTER) --verbose $$test_options -o test-log.xml $(tests_nodbus) ; \
	  if test -d "$(top_srcdir)/.bzr" ; then \
	    REVISION=`bzr revision-info` ; \
	  else \
	    REVISION=$(PACKAGE_VERSION) ; \
	  fi ; \
	  echo '<?xml version="1.0"?>' > $@.xml ; \
	  echo '<report-collection>' >> $@.xml ; \
	  echo '<info>' >> $@.xml ; \
	  echo '  <package>$(PACKAGE_NAME)</package>' >> $@.xml ; \
	  echo '  <version>$(PACKAGE_VERSION)</version>' >> $@.xml ; \
	  echo "  <revision>$$REVISION</revision>" >> $@.xml ; \
	  echo '</info>' >> $@.xml ; \
	  sed '1,1s/^<?xml\b[^>?]*?>//' < test-log.xml >> $@.xml ; \
	  rm test-log.xml ; \
	  echo >> $@.xml ; \
	  echo '</report-collection>' >> $@.xml ; \
	  $(GTESTER_REPORT) --version 2>/dev/null 1>&2 ; test "$$?" != 0 || $(GTESTER_REPORT) $@.xml >$@.html ; \
	}
else # !CREDENTIALS_ENABLE_TESTS
test:
	echo "Test run disabled due to the lack of GLib testing utilities"
endif

noinst_test_data = \
	tests/data/e-mail.service-type \
	tests/data/Gallery.application \
	tests/data/Mailer.application \
	tests/data/MyProvider.provider \
	tests/data/MyService2.service \
	tests/data/MyService.service \
	tests/data/OtherService.service

# Code coverage reporting.
if CREDENTIALS_ENABLE_COVERAGE
# Depend on full-report so that all the tests are run.
lcov: full-report
	$(AM_V_at)$(LCOV) --base-directory $(top_builddir) \
		--directory $(top_builddir)/libaccount-plugin \
		--directory $(top_builddir)/src --capture \
		--output-file credentials-lcov.info --test-name CREDENTIALS \
		--no-checksum --compat-libtool
	$(AM_V_at)LANG=C $(LCOV_GENHTML) --prefix $(top_builddir) \
		--output-directory credentials-lcov \
		--title "Credentials code coverage" --legend --show-details \
		credentials-lcov.info

lcov-clean:
	$(AM_V_at)$(LCOV) --directory $(top_builddir) -z
	$(AM_V_at)rm -rf credentials-lcov.info credentials-lcov
	$(AM_V_at)find -name '*.gcda' -delete
else # !CREDENTIALS_ENABLE_COVERAGE
lcov:
	$(AM_V_at)echo "Code coverage reporting not available"

lcov-clean:
	$(AM_V_at)rm -rf credentials-lcov.info credentials-lcov
	$(AM_V_at)find -name '*.gcda' -delete
endif

@INTLTOOL_DESKTOP_RULE@

desktopdir = $(datadir)/applications
if WITH_UNITY_CONTROL_CENTER
if ENABLE_STANDALONE_PREFERENCES
desktop_in_files = \
	data/credentials-preferences.desktop.in \
	data/unity-credentials-panel.desktop.in \
	data/update-accounts.desktop.in
else !ENABLE_STANDALONE_PREFERENCES
desktop_in_files = \
	data/unity-credentials-panel.desktop.in \
	data/update-accounts.desktop.in
endif
else !WITH_UNITY_CONTROL_CENTER
if ENABLE_STANDALONE_PREFERENCES
desktop_in_files = \
	data/credentials-preferences.desktop.in \
	data/update-accounts.desktop.in
else !ENABLE_STANDALONE_PREFERENCES
desktop_in_files = \
	data/update-accounts.desktop.in
endif
endif
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

data/update-accounts.desktop: data/update-accounts.desktop.in
	$(AM_V_GEN)$(SED) -e "s|\@LIBEXECDIR\@|$(libexecdir)|" $< > $@

dbus_servicedir = $(datadir)/dbus-1/services
dbus_service_in_files = data/com.canonical.webcredentials.capture.service.in
dbus_service_DATA = $(dbus_service_in_files:.service.in=.service)

service_executable = $(bindir)/online-accounts-preferences

data/com.canonical.webcredentials.capture.service: data/com.canonical.webcredentials.capture.service.in
	$(AM_V_GEN)$(SED) -e "s|\@SERVICE_EXECUTABLE\@|$(service_executable)|" $< > $@

iconthemedir = $(datadir)/icons/hicolor
credentialsicon = credentials-preferences.png

icon16dir = $(iconthemedir)/16x16/apps
icon22dir = $(iconthemedir)/22x22/apps
icon24dir = $(iconthemedir)/24x24/apps
icon32dir = $(iconthemedir)/32x32/apps
icon48dir = $(iconthemedir)/48x48/apps
icon64dir = $(iconthemedir)/64x64/apps
icon128dir = $(iconthemedir)/128x128/apps

dist_icon16_DATA = icons/16x16/$(credentialsicon)
dist_icon22_DATA = icons/22x22/$(credentialsicon)
dist_icon24_DATA = icons/24x24/$(credentialsicon)
dist_icon32_DATA = \
	icons/32x32/$(credentialsicon) \
	icons/32x32/credentials-add-account.png
dist_icon48_DATA = icons/48x48/$(credentialsicon)
dist_icon64_DATA = icons/64x64/$(credentialsicon)
dist_icon128_DATA = icons/128x128/$(credentialsicon)

update_icon_cache = gtk-update-icon-cache --ignore-theme-index --force $(iconthemedir)

install-data-hook: install-update-icon-cache
uninstall-hook: uninstall-update-icon-cache

install-update-icon-cache:
	$(AM_V_at)$(POST_INSTALL)
	test -n "$(DESTDIR)" || $(update_icon_cache)
uninstall-update-icon-cache:
	$(AM_V_at)$(POST_UNINSTALL)
	test -n "$(DESTDIR)" || $(update_icon_cache)

# Gtk-doc.
gtkdoc_builddir = $(top_builddir)/doc/account-plugin
gtkdoc_distdir = $(top_distdir)/doc/account-plugin
gtkdoc_srcdir = $(top_srcdir)/doc/account-plugin

all-local:
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) all
check-local: test
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) check
clean-local: lcov-clean
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) clean
	find -name '*.gcno' -delete
distclean-local:
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) distclean
docs: $(lib_LTLIBRARIES)
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) docs
install-data-local:
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) install-data
uninstall-local:
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) uninstall

dist-hook: bzr-changelog-hook
	$(MKDIR_P) $(gtkdoc_distdir)
	cp $(gtkdoc_srcdir)/Makefile.am $(gtkdoc_srcdir)/Makefile.in $(gtkdoc_distdir)
	cd $(gtkdoc_builddir) && $(MAKE) $(AM_MAKEFLAGS) \
	  distdir="../../$(gtkdoc_distdir)" \
	  top_distdir="../../$(top_distdir)" \
	  dist-hook

bzr-changelog-hook: Makefile
	$(AM_V_at)cd $(top_srcdir) && \
	if $(top_srcdir)/build-aux/missing --run bzr log \
		--gnu-changelog > .ChangeLog.tmp; \
	then mv -f .ChangeLog.tmp "$(top_distdir)/ChangeLog"; \
	else rm -f .ChangeLog.tmp; exit 1; fi

dist_noinst_SCRIPTS = \
	autogen.sh

dist_noinst_DATA = \
	$(dbus_service_in_files) \
	$(gtkdoc_srcdir)/account-plugin-docs.xml \
	$(gtkdoc_srcdir)/account-plugin-sections.txt \
	$(gtkdoc_srcdir)/version.xml.in \
	$(noinst_test_data) \
	COPYING.LGPL \
	gtk-doc.make \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in \
	online-accounts-preferences.in \
	src/config.vapi \
	src/assertions.vapi \
	src/signon.vapi

CLEANFILES = \
	$(dbus_service_DATA) \
	$(desktop_in_files) \
	$(desktop_DATA) \
	tests/test-control-center.sh

DISTCLEANFILES = \
	doc/account-plugin/version.xml \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache

MAINTAINERCLEANFILES = \
	build-aux/compile \
	build-aux/config.guess \
	build-aux/config.sub \
	build-aux/depcomp \
	build-aux/install-sh \
	build-aux/ltmain.sh \
	build-aux/missing \
	aclocal.m4 \
	config.h.in

# libaccount-plugin introspection.
-include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = --add-include-path=$(srcdir)
INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)

if HAVE_INTROSPECTION
introspection_sources = \
	libaccount-plugin/account-plugin.h \
	libaccount-plugin/application-plugin.c \
	libaccount-plugin/application-plugin.h \
	libaccount-plugin/client.c \
	libaccount-plugin/client.h \
	libaccount-plugin/module.h \
	libaccount-plugin/oauth-plugin.c \
	libaccount-plugin/oauth-plugin.h \
	libaccount-plugin/plugin.c \
	libaccount-plugin/plugin.h

AccountPlugin-1.0.gir: libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la
AccountPlugin_1_0_gir_INCLUDES = \
	Accounts-1.0 \
	GObject-2.0 \
	Gtk-3.0
AccountPlugin_1_0_gir_SCANNERFLAGS = \
	--identifier-prefix=Ap \
	--symbol-prefix=ap \
	--c-include="libaccount-plugin/account-plugin.h" \
	--warn-all

AccountPlugin_1_0_gir_CFLAGS = $(LIBACCOUNT_PLUGIN_CFLAGS)
AccountPlugin_1_0_gir_LIBS = libaccount-plugin-@LIBACCOUNT_PLUGIN_API_VERSION@.la
AccountPlugin_1_0_gir_FILES = $(introspection_sources)
INTROSPECTION_GIRS += AccountPlugin-1.0.gir

girdir = $(datadir)/gir-1.0
gir_DATA = $(INTROSPECTION_GIRS)

typelibdir = $(libdir)/girepository-1.0
typelib_DATA = $(INTROSPECTION_GIRS:.gir=.typelib)

CLEANFILES += $(gir_DATA) $(typelib_DATA)
endif

.PHONY: bzr-changelog-hook
.PHONY: docs
.PHONY: install-update-icon-cache uninstall-update-icon-cache
.PHONY: test test-report perf-report full-report
.PHONY: lcov lcov-clean
