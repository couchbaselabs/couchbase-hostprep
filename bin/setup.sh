#!/bin/bash
#
#
DIRECTORY=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRECTORY" && pwd)
PACKAGE_DIR=$(dirname "$SCRIPT_DIR")
VENV_NAME=venv
FORCE=0
SETUP_LOG=/var/tmp/hostprep_setup.log
PYTHON_BIN=${PYTHON_BIN:-python3}
PIP_BIN=${PIP_BIN:-pip3}

err_exit() {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   fi
   exit 1
}

zypper_find_package() {
  RESULT=$(zypper search python3 | \
            grep -E '\s+python3[0-9]*\s+' | \
            tr -d '[:blank:]' | \
            cut -d\| -f 2 | \
            sort | \
            tail -1)
  PACKAGE=${RESULT:-python3}
}

zypper_package_check() {
  [ -z "$1" ] && err_exit "zypper_package_check requires an argument"
  if zypper search -i "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

apt_find_package() {
  [ -z "$1" ] && err_exit "apt_find_package requires an argument"
  PACKAGE=$(apt-cache search "$1" | \
           awk '{print $1}' | \
           sort | \
           tail -1)
  [ -z "$PACKAGE" ] && err_exit "apt_find_package: no suitable packages found for $1"
}

apt_package_check() {
  [ -z "$1" ] && err_exit "apt_package_check requires an argument"
  if dpkg -s "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

install_python() {
  echo "Installing Python 3"
  source /etc/os-release
  echo "Install linux type $ID"
  case ${ID:-null} in
  centos|rhel|amzn|rocky|ol|fedora)
    yum install -q -y python3
    ;;
  ubuntu|debian)
    apt_find_package "^python3[0-9.]*$"
    if ! apt_package_check "$PACKAGE"
    then
      apt-get update
      apt-get install -q -y "$PACKAGE"
    fi
    apt_find_package "^python3[0-9.]*-venv$"
    if ! apt_package_check "$PACKAGE"
    then
      apt-get update
      apt-get install -q -y "$PACKAGE"
    fi
    ;;
  opensuse-leap|sles)
    zypper_find_package
    if ! zypper_package_check "$PACKAGE"
    then
      zypper install -y "$PACKAGE"
    fi
    ;;
  arch)
    pacman-key --init
    pacman-key --populate
    pacman -Sy --noconfirm
    pacman -S --noconfirm python3
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

find_python_bin() {
  PYTHON_BIN=$(whereis -b python3 | \
               tr -s '[:blank:]' '\n' | \
               tail -n +2 | grep ^/usr/bin | \
               sort | \
               grep -E '[0-9.]$' | \
               tail -1)
}

while getopts "f" opt
do
  case $opt in
    f)
      FORCE=1
      ;;
    \?)
      echo "Invalid Argument"
      exit 1
      ;;
  esac
done

cd "$PACKAGE_DIR" || err_exit "can not change to package directory"

find_python_bin

if [ -z "$PYTHON_BIN" ] || ! "$PYTHON_BIN" -m ensurepip >/dev/null 2>&1
then
  printf "Installing Python 3..."
  if ! install_python >> $SETUP_LOG 2>&1
  then
    err_exit "Python 3 installation unsuccessful, aborting"
  fi
  echo "Done."
fi

if [ -d "${PACKAGE_DIR:?}/$VENV_NAME" ] && [ $FORCE -eq 0 ]; then
  echo "Virtual environment $PACKAGE_DIR/$VENV_NAME already exists."
  printf "Remove the existing directory? (y/n) [y]:"
  read -r INPUT
  if [ "$INPUT" == "y" ] || [ -z "$INPUT" ]; then
    [ -n "$PACKAGE_DIR" ] && [ -n "$VENV_NAME" ] && rm -rf "${PACKAGE_DIR:?}/$VENV_NAME"
  else
    echo "Setup cancelled. No changes were made."
    exit 1
  fi
fi

printf "Creating virtual environment... "
$PYTHON_BIN -m venv "${PACKAGE_DIR:?}/$VENV_NAME"
if [ $? -ne 0 ]; then
  echo "Virtual environment setup failed."
  exit 1
fi
echo "Done."

printf "Activating virtual environment... "
. "${PACKAGE_DIR:?}/${VENV_NAME:?}/bin/activate"
echo "Done."

printf "Installing dependencies... "
$PYTHON_BIN -m pip install --upgrade pip setuptools wheel >> $SETUP_LOG 2>&1
$PIP_BIN install --no-cache-dir -r requirements.txt >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]; then
  echo "Setup failed."
  rm -rf "${PACKAGE_DIR:?}/${VENV_NAME:?}"
  exit 1
else
  echo "Done."
  echo "Setup successful."
fi
