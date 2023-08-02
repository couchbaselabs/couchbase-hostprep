#!/bin/bash
# shellcheck disable=SC2086
# shellcheck disable=SC2181
# shellcheck disable=SC1090
#
DIRECTORY=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRECTORY" && pwd)
PACKAGE_DIR=$(dirname "$SCRIPT_DIR")
VENV_NAME=venv
FORCE=0
SETUP_LOG="setup.log"
INSTALL_PYTHON=1
SYSTEM_INSTALL=0

PYTHON_VERSION="3.9"
PIP_VERSION="3.9"
PYTHON39_YUM="python39 python39-pip python39-devel"
PYTHON39_APT="python3.9 python3.9-dev python3.9-venv python3-pip"
PYTHON39_ZYPPER="python39 python39-devel python3-pip"
PYTHON311_ZYPPER="python311 python311-devel python311-pip"
PYTHON39_PACMAN="python39"

PYTHON_BIN="python${PYTHON_VERSION}"
PIP_BIN="pip${PIP_VERSION}"

err_exit() {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   fi
   exit 1
}

set_tz() {
  if [ -f /etc/timezone ]
  then
    TZ_DATA=$(cat /etc/timezone)
  elif which timedatectl >/dev/null 2>&1
  then
    TZ_DATA=$(timedatectl show | grep Timezone | cut -d= -f2)
  else
    TZ_DATA="Etc/UTC"
  fi
  export TZ=${TZ_DATA}
}

read_os_info() {
  source /etc/os-release
  OS_MAJOR_REV="$(echo $VERSION_ID | cut -d. -f1)"
  OS_MINOR_REV="$(echo $VERSION_ID | cut -d. -f2)"
  export OS_MAJOR_REV OS_MINOR_REV ID
  echo "Linux type $ID - $NAME version $OS_MAJOR_REV"
}

set_python_version() {
   PYTHON_VERSION=$1
   PIP_VERSION=$PYTHON_VERSION
   PYTHON_BIN="python${PYTHON_VERSION}"
   PIP_BIN="pip${PIP_VERSION}"
}

install_prerequisites() {
  case ${ID:-null} in
  amzn|rocky|ol|fedora)
    yum install -y which
    ;;
  centos|rhel)
    ;;
  ubuntu)
    if [ "$OS_MAJOR_REV" -gt 20 ]; then
      set_tz
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -q -y software-properties-common
      add-apt-repository -y ppa:deadsnakes/ppa
    fi
    ;;
  debian)
    ;;
  opensuse-leap|sles)
    zypper install -y which
    ;;
  arch)
    pacman-key --init
    pacman-key --populate
    pacman -Sy --noconfirm
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

install_python() {
  case ${ID:-null} in
  centos|rhel|amzn|rocky|ol|fedora)
    if [ "$ID" = "amzn" ] && [ "$OS_MAJOR_REV" -eq 2 ]
    then
      amazon-linux-extras enable python3.8
      yum install -y python3.8
      set_python_version "3.8"
    else
      yum install -q -y $PYTHON39_YUM
    fi
    ;;
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -q -y $PYTHON39_APT
    ;;
  opensuse-leap|sles)
    if [ "$ID" = "sles" ] && [ "$OS_MINOR_REV" -ge 4 ]
    then
      zypper install -y $PYTHON311_ZYPPER
      set_python_version "3.11"
    else
      PIP_VERSION="3"
      zypper install -y $PYTHON39_ZYPPER
    fi
    ;;
  arch)
    pacman -S --noconfirm $PYTHON39_PACMAN
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

post_install() {
  case ${ID:-null} in
  centos|rhel|amzn|rocky|ol|fedora)
    ;;
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -q -y python3-dev python3-venv
    ;;
  opensuse-leap|sles)
    ;;
  arch)
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

find_python_bin() {
  if ! which $PYTHON_BIN > /dev/null 2>&1
  then
    err_exit "Python executable $PYTHON_BIN not found."
  fi
}

install_check() {
  echo "Package Directory: $PACKAGE_DIR"
  cd "$PACKAGE_DIR" || err_exit "can not change to package directory"
  source "${PACKAGE_DIR:?}/${VENV_NAME:?}/bin/activate"
  python3 -V
  pip3 freeze
}

while getopts "fcsn:" opt
do
  case $opt in
    f)
      FORCE=1
      ;;
    c)
      install_check
      exit 0
      ;;
    s)
      SYSTEM_INSTALL=1
      ;;
    n)
      VENV_NAME=$OPTARG
      ;;
    \?)
      echo "Invalid Argument"
      exit 1
      ;;
  esac
done

read_os_info

echo "Checking prerequisites"
install_prerequisites >> $SETUP_LOG 2>&1

if python3 -V >/dev/null 2>&1
then
  CURRENT_MAJOR_VERSION=$(python3 -V | awk '{print $2}' | cut -d. -f1)
  CURRENT_MINOR_VERSION=$(python3 -V | awk '{print $2}' | cut -d. -f2)
  if [ "$CURRENT_MINOR_VERSION" -ge 9 ]
  then
    INSTALL_PYTHON=0
    set_python_version "${CURRENT_MAJOR_VERSION}.${CURRENT_MINOR_VERSION}"
  fi
fi

if [ "$INSTALL_PYTHON" -eq 1 ]
then
  echo "Installing Python"
  install_python >> $SETUP_LOG 2>&1
else
  echo "Configuring Python"
  post_install >> $SETUP_LOG 2>&1
fi

find_python_bin

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

if [ "$SYSTEM_INSTALL" -eq 0 ]; then
  printf "Creating virtual environment... "
  $PYTHON_BIN -m venv "${PACKAGE_DIR:?}/$VENV_NAME"
  if [ $? -ne 0 ]; then
    echo "Virtual environment setup failed."
    exit 1
  fi
  echo "Done."

  printf "Activating virtual environment... "
  source "${PACKAGE_DIR:?}/${VENV_NAME:?}/bin/activate"
  echo "Done."
fi

if ! [ -f requirements.txt ]; then
  echo "No requirements.txt found."
  exit 1
fi

printf "Installing dependencies... "
$PYTHON_BIN -m pip install --upgrade pip setuptools wheel >> $SETUP_LOG 2>&1
$PIP_BIN install --no-cache-dir -r requirements.txt >> $SETUP_LOG 2>&1
if [ $? -ne 0 ]; then
  echo "Setup failed."
  rm -rf "${PACKAGE_DIR:?}/${VENV_NAME:?}"
  exit 1
else
  echo "Done."
fi

if [ -x "${SCRIPT_DIR}/post_setup.sh" ]
then
  echo "Running post setup steps"
  "${SCRIPT_DIR}/post_setup.sh" >> $SETUP_LOG 2>&1
  [ $? -ne 0 ] && err_exit "Post setup script error."
fi

echo "Setup complete."
