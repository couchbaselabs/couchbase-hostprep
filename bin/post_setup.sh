#!/bin/bash
# shellcheck disable=SC2086
# shellcheck disable=SC2181
# shellcheck disable=SC1090
#
DIRECTORY=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRECTORY" && pwd)
PACKAGE_DIR=$(dirname "$SCRIPT_DIR")

read_os_info() {
  source /etc/os-release
  OS_MAJOR_REV="$(echo $VERSION_ID | cut -d. -f1)"
  OS_MINOR_REV="$(echo $VERSION_ID | cut -d. -f2)"
  export OS_MAJOR_REV OS_MINOR_REV ID
  echo "Linux type $ID - $NAME version $OS_MAJOR_REV"
}

install_ansible() {
  case ${ID:-null} in
  centos|rhel|amzn|rocky|ol|fedora)
    python3 -m pip install ansible
    python3 -m pip install ansible_runner
    ansible-galaxy collection install community.general
    ansible-galaxy collection install ansible.posix
    ;;
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -q -y python3-apt
    python3 -m pip install ansible
    python3 -m pip install ansible_runner
    ansible-galaxy collection install community.general
    ansible-galaxy collection install ansible.posix
    ;;
  opensuse-leap|sles)
    python3 -m pip install ansible
    python3 -m pip install ansible_runner
    ansible-galaxy collection install community.general
    ansible-galaxy collection install ansible.posix
    ;;
  arch)
    python3 -m pip install ansible
    python3 -m pip install ansible_runner
    ansible-galaxy collection install community.general
    ansible-galaxy collection install ansible.posix
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

install_hostprep_lib() {
  pip3 install "$PACKAGE_DIR/py_host_prep"
}

read_os_info

install_ansible

install_hostprep_lib

##