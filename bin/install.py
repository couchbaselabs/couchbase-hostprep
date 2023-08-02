#!/usr/bin/env python3

import logging
import warnings
import argparse
import sys
import os
import signal
import inspect
import traceback
import ansible_runner
from hostpreplib.bundles import SoftwareBundle

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
        self.args = parser.parse_args()

    @property
    def parameters(self):
        return self.args


class CustomFormatter(logging.Formatter):
    format_level = "%(levelname)s"
    format_name = "%(name)s"
    format_message = "%(message)s"
    format_line = "(%(filename)s:%(lineno)d)"
    format_extra = " [%(name)s](%(filename)s:%(lineno)d)"
    FORMATS = {
        logging.DEBUG: f"{format_level} - {format_message}",
        logging.INFO: f"{format_level} - {format_message}",
        logging.WARNING: f"{format_level} - {format_message}",
        logging.ERROR: f"{format_level} - {format_message}",
        logging.CRITICAL: f"{format_level} - {format_message}"
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        if logging.DEBUG >= logging.root.level:
            log_fmt += self.format_extra
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


class RunMain(object):

    def __init__(self):
        self.current = os.path.dirname(os.path.realpath(__file__))
        self.parent = os.path.dirname(self.current)
        self.config = f"{self.parent}/config/packages.json"
        self.op = SoftwareBundle(f"{self.parent}/config/packages.json")

    def run(self, options):
        extra_vars = {
            'ansible_python_interpreter': f"{self.parent}/venv/bin/python3"
        }
        for b in options.bundles:
            self.op.add(b)
        for bundle in self.op.install_list():
            for playbook in [bundle.pre, bundle.run, bundle.post]:
                if not playbook:
                    continue
                r = ansible_runner.run(playbook=f"{self.parent}/playbooks/{playbook}")
                print(f"{r.status}: {r.rc}")
                for each_host_event in r.events:
                    print(each_host_event['event'])
                print(f"Final status: {r.stats}")


def main():
    global logger
    signal.signal(signal.SIGINT, break_signal_handler)
    default_debug_file = f"{os.environ['HOME']}/{os.path.splitext(os.path.basename(__file__))[0]}_debug.out"
    debug_file = os.environ.get("DEBUG_FILE", default_debug_file)
    arg_parser = Parameters()
    parameters = arg_parser.parameters

    try:
        if parameters.debug:
            logger.setLevel(logging.DEBUG)

            try:
                open(debug_file, 'w').close()
            except Exception as err:
                print(f"[!] Warning: can not clear log file {debug_file}: {err}")

            file_handler = logging.FileHandler(debug_file)
            file_formatter = logging.Formatter(logging.BASIC_FORMAT)
            file_handler.setFormatter(file_formatter)
            logger.addHandler(file_handler)
        elif parameters.verbose:
            logger.setLevel(logging.INFO)
        else:
            logger.setLevel(logging.ERROR)
    except (ValueError, KeyError):
        pass

    screen_handler = logging.StreamHandler()
    screen_handler.setFormatter(CustomFormatter())
    logger.addHandler(screen_handler)

    RunMain().run(parameters)


if __name__ == '__main__':
    try:
        main()
    except SystemExit as e:
        sys.exit(e.code)
