#!/usr/bin/env python3

import os
import logging
import warnings
import pytest
from common import start_container, stop_container, copy_to_container, run_in_container, container_mkdir, copy_dir_to_container

warnings.filterwarnings("ignore")
logger = logging.getLogger()
current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)


@pytest.mark.parametrize("container", ["redhat/ubi8",
                                       "redhat/ubi9",
                                       "rockylinux:8",
                                       "rockylinux:9",
                                       "oraclelinux:8",
                                       "oraclelinux:9",
                                       "fedora:latest",
                                       "ubuntu:focal",
                                       "ubuntu:jammy",
                                       "debian:bullseye",
                                       "opensuse/leap:latest",
                                       "registry.suse.com/suse/sle15:latest",
                                       "registry.suse.com/suse/sle15:15.3",
                                       "amazonlinux:2",
                                       "amazonlinux:2023"])
@pytest.mark.parametrize("script", ["bin/setup.sh"])
def test_1(container, script):
    global parent
    bin_dir = f"{parent}/bin"
    requirements = f"{parent}/requirements.txt"
    destination = "/usr/local/hostprep"

    container_id = start_container(container)
    try:
        container_mkdir(container_id, destination)
        copy_dir_to_container(container_id, bin_dir, destination)
        copy_to_container(container_id, requirements, destination)
        run_in_container(container_id, destination, "bin/setup.sh")
        stop_container(container_id)
    except Exception:
        stop_container(container_id)
        raise
