#!/usr/bin/env python3

import os
import logging
import warnings
from lib.osinfo import OSRelease

warnings.filterwarnings("ignore")
logger = logging.getLogger()
current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)


def test_os_release_1():
    os_obj = OSRelease(f"{parent}/test/os-release")
    assert os_obj.os_name == "ubuntu"
    assert os_obj.major_rel == 20
    assert os_obj.minor_rel == 4
