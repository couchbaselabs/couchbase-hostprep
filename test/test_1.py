#!/usr/bin/env python3

import os
import logging
import warnings
import pytest
from test.common import start_container, stop_container, copy_to_container, run_in_container, container_mkdir, copy_dir_to_container

warnings.filterwarnings("ignore")
logger = logging.getLogger()
current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)


@pytest.mark.parametrize("container, platform", [("rhel-8-init", ("linux/amd64",)),
                                                 ("rhel-9-init", ("linux/amd64",)),
                                                 ("rockylinux:8", ("linux/amd64",)),
                                                 ("rockylinux:9", ("linux/amd64",)),
                                                 ("oraclelinux:8", ("linux/amd64",)),
                                                 ("oraclelinux:9", ("linux/amd64",)),
                                                 ("fedora:latest", ("linux/amd64",)),
                                                 ("ubuntu-focal-init", ("linux/amd64",)),
                                                 ("ubuntu-jammy-init", ("linux/amd64",)),
                                                 ("debian-bullseye-init", ("linux/amd64",)),
                                                 ("opensuse-init", ("linux/amd64",)),
                                                 ("sles-155-init", ("linux/amd64",)),
                                                 ("sles-153-init", ("linux/amd64",)),
                                                 ("amazon-2-init", ("linux/amd64",)),
                                                 ("amazon-2023-init", ("linux/amd64",))])
def test_1(container, platform):
    global parent
    volume = "/opt/couchbase"
    bin_dir = f"{parent}/bin"
    cfg_dir = f"{parent}/config"
    lib_dir = f"{parent}/lib"
    playbook_dir = f"{parent}/playbooks"
    hostprep_dir = f"{parent}/py_host_prep"
    requirements = f"{parent}/requirements.txt"
    chrony_defaults = f"{parent}/test/chrony"
    destination = "/usr/local/hostprep"
    sys_defaults = "/etc/default"

    container_id = start_container(container, platform, volume)
    try:
        container_mkdir(container_id, destination)
        copy_dir_to_container(container_id, bin_dir, destination)
        copy_dir_to_container(container_id, cfg_dir, destination)
        copy_dir_to_container(container_id, lib_dir, destination)
        copy_dir_to_container(container_id, playbook_dir, destination)
        copy_dir_to_container(container_id, hostprep_dir, destination)
        copy_to_container(container_id, requirements, destination)
        copy_to_container(container_id, chrony_defaults, sys_defaults)
        run_in_container(container_id, destination, ["bin/setup.sh", "-s"])
        run_in_container(container_id, destination, ["bin/install.py", "-b", "CBS"])
        stop_container(container_id)
    except Exception:
        stop_container(container_id)
        raise
