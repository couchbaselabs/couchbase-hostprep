#!/usr/bin/env python3

import logging
import warnings
import argparse
import sys
import os
import signal
import inspect
import traceback
import datetime
import ansible_runner
from datetime import datetime
from hostpreplib.bundles import SoftwareBundle
from hostpreplib.hostinfo import HostInfo

warnings.filterwarnings("ignore")
logger = logging.getLogger()


def break_signal_handler(signum, frame):
    signal_name = signal.Signals(signum).name
    (filename, line, function, lines, index) = inspect.getframeinfo(frame)
    logger.debug(f"received break signal {signal_name} in {filename} {function} at line {line}")
    tb = traceback.format_exc()
    logger.debug(tb)
    print("")
    print("Break received, aborting.")
    sys.exit(1)


class Parameters(object):

    def __init__(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('-b', '--bundles', nargs='+', help='List of bundles to deploy')
        parser.add_argument('-d', '--debug', action='store_true', help="Debug output")
        parser.add_argument('-v', '--verbose', action='store_true', help="Verbose output")
        parser.add_argument('-V', '--version', action='store', help="Software Version String")
        self.args = parser.parse_args()

    @property
    def parameters(self):
        return self.args


class CustomFormatter(logging.Formatter):
    grey = "\x1b[38;20m"
    yellow = "\x1b[33;20m"
    red = "\x1b[31;20m"
    bold_red = "\x1b[31;1m"
    green = "\x1b[32;20m"
    reset = "\x1b[0m"
    format_level = "%(levelname)s"
    format_name = "%(name)s"
    format_message = "%(message)s"
    format_line = "(%(filename)s:%(lineno)d)"
    format_extra = " [%(name)s](%(filename)s:%(lineno)d)"
    format_timestamp = "%(asctime)s"
    FORMATS = {
        logging.DEBUG: f"{format_timestamp} [{grey}{format_level}{reset}] {format_message}",
        logging.INFO: f"{format_timestamp} [{green}{format_level}{reset}] {format_message}",
        logging.WARNING: f"{format_timestamp} [{yellow}{format_level}{reset}] {format_message}",
        logging.ERROR: f"{format_timestamp} [{red}{format_level}{reset}] {format_message}",
        logging.CRITICAL: f"{format_timestamp} [{red}{format_level}{reset}] {format_message}"
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        if logging.DEBUG >= logging.root.level:
            log_fmt += self.format_extra
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


class StreamToLogger(object):
    def __init__(self, _logger, _level):
        self.logger = _logger
        self.level = _level
        self.buffer = ''

    def write(self, buf):
        for line in buf.rstrip().splitlines():
            self.logger.log(self.level, line.rstrip())

    def flush(self):
        pass


class RunMain(object):

    def __init__(self):
        self.current = os.path.dirname(os.path.realpath(__file__))
        self.parent = os.path.dirname(self.current)
        self.config = f"{self.parent}/config/packages.json"
        self.op = SoftwareBundle(f"{self.parent}/config/packages.json")
        self.host_info = HostInfo()
        self.host_info.get_service_status()

    @staticmethod
    def run_timestamp(label: str):
        timestamp = datetime.utcnow().strftime("%b %d %H:%M:%S")
        logger.info(f" ==== Run {label} {timestamp} ====")

    def is_time_synced(self):
        return self.host_info.system.is_running("ntp") \
            or self.host_info.system.is_running("ntpd") \
            or self.host_info.system.is_running("systemd-timesyncd") \
            or self.host_info.system.is_running("chrony") \
            or self.host_info.system.is_running("chronyd")

    def is_firewalld_enabled(self):
        return self.host_info.system.is_running("firewalld")

    def run(self, options):
        os_name = self.op.os.os_name
        os_major = self.op.os.os_major_release
        os_minor = self.op.os.os_minor_release
        cbs_sw_version = options.version
        sgw_sw_version = options.version
        logger.info(f"Running on {os_name} release {os_major}")
        extra_vars = {
            'package_root': self.parent,
            'os_name': os_name,
            'os_major': os_major,
            'os_minor': os_minor,
            'cbs_sw_version': cbs_sw_version,
            'sgw_sw_version': sgw_sw_version,
            'time_svc_enabled': self.is_time_synced(),
            'firewalld_enabled': self.is_firewalld_enabled()
        }

        for b in options.bundles:
            self.op.add(b)

        self.run_timestamp("begins")

        for bundle in self.op.install_list():
            logger.info(f"Executing bundle {bundle.name}")
            for playbook in [bundle.pre, bundle.run, bundle.post]:
                if not playbook:
                    continue
                logger.info(f"Running playbook {playbook}")
                stdout_save = sys.stdout
                sys.stdout = StreamToLogger(logger, logging.INFO)
                r = ansible_runner.run(playbook=f"{self.parent}/playbooks/{playbook}", extravars=extra_vars)
                sys.stdout = stdout_save
                logger.info(f"Playbook status: {r.status}")
                if r.rc != 0:
                    logger.error(r.stats)
                    self.run_timestamp("failed")
                    sys.exit(r.rc)

        self.run_timestamp("successful")


def main():
    global logger
    signal.signal(signal.SIGINT, break_signal_handler)
    default_debug_file = f"/var/log/hostprep.log"
    debug_file = os.environ.get("DEBUG_FILE", default_debug_file)
    arg_parser = Parameters()
    parameters = arg_parser.parameters

    if parameters.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    if parameters.verbose:
        screen_handler = logging.StreamHandler()
        screen_handler.setFormatter(CustomFormatter())
        logger.addHandler(screen_handler)

    file_handler = logging.FileHandler(debug_file)
    file_handler.setFormatter(CustomFormatter())
    logger.addHandler(file_handler)

    RunMain().run(parameters)


if __name__ == '__main__':
    try:
        main()
    except SystemExit as e:
        sys.exit(e.code)
