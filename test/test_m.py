#!/usr/bin/env python3

import os
import argparse
import logging
import warnings
from common import start_container, stop_container, copy_to_container, run_in_container, get_container_id, container_mkdir, copy_dir_to_container

warnings.filterwarnings("ignore")
logger = logging.getLogger()
current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)


class Params(object):

    def __init__(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("--container", action="store", help="Container", default="redhat/ubi8")
        parser.add_argument("--script", action="store", help="Script", default="python_setup.sh")
        parser.add_argument("--log", action="store", help="Script", default="setup.log")
        parser.add_argument("--run", action="store_true")
        parser.add_argument("--start", action="store_true")
        parser.add_argument("--stop", action="store_true")
        parser.add_argument("--refresh", action="store_true")
        self.args = parser.parse_args()

    @property
    def parameters(self):
        return self.args


def manual_1(args: argparse.Namespace):
    global parent
    bin_dir = f"{parent}/bin"
    requirements = f"{parent}/requirements.txt"
    destination = "/usr/local/hostprep"

    container_id = start_container(args.container)
    try:
        container_mkdir(container_id, destination)
        copy_dir_to_container(container_id, bin_dir, destination)
        copy_to_container(container_id, requirements, destination)
        run_in_container(container_id, destination, ["bin/setup.sh", "-s"])
        stop_container(container_id)
    except Exception:
        raise


def manual_2(args: argparse.Namespace):
    global parent
    bin_dir = f"{parent}/bin"
    cfg_dir = f"{parent}/config"
    lib_dir = f"{parent}/lib"
    playbook_dir = f"{parent}/playbooks"
    hostprep_dir = f"{parent}/py_host_prep"
    requirements = f"{parent}/requirements.txt"
    chrony_defaults = f"{parent}/test/chrony"
    destination = "/usr/local/hostprep"
    sys_defaults = "/etc/default"

    container_id = start_container(args.container)
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
    except Exception:
        raise


def refresh():
    global parent
    bin_dir = f"{parent}/bin"
    cfg_dir = f"{parent}/config"
    lib_dir = f"{parent}/lib"
    playbook_dir = f"{parent}/playbooks"
    hostprep_dir = f"{parent}/py_host_prep"
    requirements = f"{parent}/requirements.txt"
    destination = "/usr/local/hostprep"

    container_id = get_container_id()
    try:
        copy_dir_to_container(container_id, bin_dir, destination)
        copy_dir_to_container(container_id, cfg_dir, destination)
        copy_dir_to_container(container_id, lib_dir, destination)
        copy_dir_to_container(container_id, playbook_dir, destination)
        copy_dir_to_container(container_id, hostprep_dir, destination)
        copy_to_container(container_id, requirements, destination)
    except Exception:
        raise


p = Params()
options = p.parameters

try:
    debug_level = int(os.environ['DEBUG_LEVEL'])
except (ValueError, KeyError):
    debug_level = 3

if debug_level == 0:
    logger.setLevel(logging.DEBUG)
elif debug_level == 1:
    logger.setLevel(logging.ERROR)
elif debug_level == 2:
    logger.setLevel(logging.INFO)
else:
    logger.setLevel(logging.CRITICAL)

logging.basicConfig()

if options.stop:
    container = get_container_id()
    stop_container(container)

if options.run:
    manual_1(options)

if options.start:
    manual_2(options)

if options.refresh:
    refresh()
