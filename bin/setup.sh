#!/bin/bash
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

install_python() {
  echo "Installing Python 3"
  source /etc/os-release
  echo "Install linux type $ID"
  case ${ID:-null} in
  centos|rhel|amzn|rocky|ol|fedora)
    yum install -q -y python3
    ;;
  ubuntu|debian)
    apt-get update
    apt-get install -q -y python3
    ;;
  opensuse-leap|sles)
    zypper install -y python3
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

if ! which "$PYTHON_BIN" >/dev/null 2>&1
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
