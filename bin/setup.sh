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
  [ -z "$1" ] || [ -z "$2" ] && err_exit "zypper_find_package requires an argument"
  PACKAGE=$(zypper search "$1" | \
            grep -E "$2" | \
            tr -d '[:blank:]' | \
            cut -d\| -f 2 | \
            sort | \
            tail -1)
}

zypper_package_check() {
  [ -z "$1" ] && return
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
  [ -z "$1" ] && return
  if dpkg -s "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

yum_find_package() {
  [ -z "$1" ] && err_exit "yum_find_package requires an argument"
  PACKAGE=$(yum list available | \
            awk '{print $1}' | \
            grep -E "$1" | \
            grep -v -E '.src$' | \
            tail -1 | \
            sed -e 's/\.[a-zA-Z0-9_]*$//')
}

yum_package_check() {
  [ -z "$1" ] && return
  if yum list installed "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

pacman_package_check() {
  [ -z "$1" ] && return
  if pacman -Qi "$1" >/dev/null 2>&1
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
    yum_find_package "^python3[0-9]*\."
    if ! yum_package_check "$PACKAGE"
    then
      yum install -q -y "$PACKAGE"
    fi
    ;;
  ubuntu|debian)
    apt_find_package "^python3[0-9.]*$"
    if ! apt_package_check "$PACKAGE"
    then
      apt-get update
      apt-get install -q -y "$PACKAGE"
    fi
    apt_find_package "python3-venv"
    if ! apt_package_check "$PACKAGE"
    then
      apt-get update
      apt-get install -q -y "$PACKAGE"
    fi
    ;;
  opensuse-leap|sles)
    zypper_find_package "python3" '\s+python3[0-9]*\s+'
    if ! zypper_package_check "$PACKAGE"
    then
      zypper install -y "$PACKAGE"
    fi
    ;;
  arch)
    if ! pacman_package_check python3
    then
      pacman-key --init
      pacman-key --populate
      pacman -Sy --noconfirm
      pacman -S --noconfirm python3
    fi
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
  PYTHON_BIN=$(basename "$PYTHON_BIN")
}

install_check() {
  echo "Package Directory: $PACKAGE_DIR"
  cd "$PACKAGE_DIR" || err_exit "can not change to package directory"
  source "${PACKAGE_DIR:?}/${VENV_NAME:?}/bin/activate"
  python3 -V
  pip3 freeze
}

build_openssl() {
  [ ! -d "${PACKAGE_DIR}/python" ] && mkdir "${PACKAGE_DIR}/python"
  printf "Building OpenSSL ... "
  (
  curl -s -o /var/tmp/openssl-1.1.1t.tar.gz https://www.openssl.org/source/openssl-1.1.1t.tar.gz && \
  cd /var/tmp && \
  tar xzf openssl-1.1.1t.tar.gz && \
  cd openssl-1.1.1t && \
  ./config --prefix="${PACKAGE_DIR}/python/openssl" \
           --openssldir="${PACKAGE_DIR}/python/openssl" \
           shared zlib-dynamic && \
  make -j4 && \
  make install_sw
  [ $? -ne 0 ] && err_exit "OpenSSL build failed"
  ) >> $SETUP_LOG 2>&1
  echo "Done."
}

build_python() {
  printf "Building Python ... "
  (
  curl -s -o /var/tmp/Python-3.11.3.tgz ttps://www.python.org/ftp/python/3.11.3/Python-3.11.3.tgz && \
  cd /var/tmp && \
  tar xvf Python-3.9.13.tgz && \
  cd Python-3.9.13 && \
  ./configure --enable-optimizations \
              --with-openssl="${PACKAGE_DIR}/python/openssl" \
              --with-openssl-rpath=auto \
              --prefix="${PACKAGE_DIR}/python" && \
  make altinstall
  [ $? -ne 0 ] && err_exit "Python build failed"
  ) >> $SETUP_LOG 2>&1
  echo "Done."
}

while getopts "fce:" opt
do
  case $opt in
    f)
      FORCE=1
      ;;
    c)
      install_check
      exit 0
      ;;
    e)
      "$OPTARG"
      exit
      ;;
    \?)
      echo "Invalid Argument"
      exit 1
      ;;
  esac
done

install_python

find_python_bin

if [ -z "$PYTHON_BIN" ]
then
  err_exit "Python 3 installation unsuccessful, aborting"
fi

cd "$PACKAGE_DIR" || err_exit "can not change to package directory"

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
source "${PACKAGE_DIR:?}/${VENV_NAME:?}/bin/activate"
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
