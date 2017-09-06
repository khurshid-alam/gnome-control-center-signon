#!/usr/bin/env python
#
from distutils.core import setup
from DistUtilsExtra.command import build_extra

setup(name="unity-control-center-signon-autopilot",
      version="0.1",
      author="Alberto Mardegan",
      author_email="alberto.mardegan@canonical.com",
      url="http://launchpad.net/uoa-integration-tests",
      license="GNU General Public License v3 (GPLv3)",
      packages=["unity_control_center_signon"],
      cmdclass={"build": build_extra.build_extra,})
