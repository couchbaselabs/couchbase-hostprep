#!/bin/bash
#
#
function print_usage {
if [ -n "$PRINT_USAGE" ]; then
   echo "$PRINT_USAGE"
fi
}

function err_exit {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   else
      print_usage
   fi
   exit 1
}

function warn_msg {
   if [ -n "$1" ]; then
      echo "[i] Warning: $1"
   fi
}

function info_msg {
   if [ -n "$1" ]; then
      echo "[i] Notice: $1"
   fi
}

function log_output {
    [ -z "$NOLOG" ] && NOLOG=0
    DATE=$(date '+%m-%d-%y_%H:%M:%S')
    [ -z "$LOGFILE" ] && LOGFILE=/var/log/$(basename $0).log
    while read line; do
        [ -z "$line" ] && continue
        if [ "$NOLOG" -eq 0 -a -n "$LOGFILE" ]; then
           echo "$DATE: $line" | tee -a $LOGFILE
        else
           echo "$DATE: $line"
        fi
    done
}

function set_linux_type {
  source /etc/os-release
  export LINUXTYPE=$ID
  case $ID in
  centos)
    PKGMGR="yum"
    SVGMGR="systemctl"
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

function install_pkg {
  case $PKGMGR in
  yum)
    yum install -y $@
    ;;
  *)
    err_exit "Unknown package manager $PKGMGR"
    ;;
  esac
}

function install_pkg_file {
  case $PKGMGR in
  yum)
    rpm -i $@
    ;;
  *)
    err_exit "Unknown package manager $PKGMGR"
    ;;
  esac
}

function service_control {
  case $SVGMGR in
  systemctl)
    systemctl $@
    ;;
  *)
    err_exit "Unknown service manager $SVGMGR"
    ;;
  esac
}

function nm_check {
  case $LINUXTYPE in
  centos)
    local PKGNAME="NetworkManager"
    local SVCNAME=$PKGNAME
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

  which nmcli >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    install_pkg $PKGNAME
    service_control enable $SVCNAME
    service_control start $SVCNAME
  fi
}

function host_dns {
  if [ -z "$NAMESERVER" -o -z "$DOMAIN" ]; then
    echo "DNS parameters not provided, skipping DNS config."
    return
  fi
  echo "Configuring DNS settings."
  local ifName=$(nmcli -t -f NAME c show --active)
  nmcli c m "$ifName" ipv4.ignore-auto-dns yes
  nmcli c m "$ifName" ipv4.dns $NAMESERVER
  nmcli c m "$ifName" ipv4.dns-search $DOMAIN
  nmcli connection up "$ifName"

  echo "search $DOMAIN" > /etc/resolv.conf
  for SERVER_ADDRESS in $(echo $NAMESERVER | tr ',' '\n'); do
    echo "nameserver $SERVER_ADDRESS" >> /etc/resolv.conf
  done
}

function host_name {
  echo "Configuring hostname."
  local ifName=$(nmcli -t -f NAME c show --active)
  if [ -n "$HOSTNAME" ]; then
    HOSTNAME=$(echo $HOSTNAME | awk -F. '{print $1}')
  else
    HOSTNAME="linuxhost"
  fi
  hostnamectl set-hostname $HOSTNAME
  IP_ADDRESS=$(nmcli c s "$ifName" | grep "IP4.ADDRESS" | awk '{print $2}' | sed -e 's/\/.*$//')

  echo "$IP_ADDRESS $HOSTNAME" >> /etc/hosts
}

function add_admin_user {
  local MYGID=$(cat /etc/group | grep -v nobody | cut -d: -f3 | sort -n | tail -1)
  local MYUID=$(cat /etc/passwd | grep -v nobody | cut -d: -f3 | sort -n | tail -1)
  MYGID=$((MYGID + 1))
  MYUID=$((MYUID + 1))
  groupadd -g $MYGID $ADMINUSER
  useradd -u $MYUID -g $ADMINUSER $ADMINUSER
  usermod -a -G wheel $ADMINUSER
  sed -i -e 's/^# %wheel/%wheel/' /etc/sudoers
  mkdir /home/${ADMINUSER}/.ssh
  chown ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/.ssh
  chmod 700 /home/${ADMINUSER}/.ssh
  if [ -n "$COPYUSER" ]; then
    if [ -f /home/${COPYUSER}/.ssh/authorized_keys ]; then
      cp /home/${COPYUSER}/.ssh/authorized_keys /home/${ADMINUSER}/.ssh/authorized_keys
      chmod 600 /home/${ADMINUSER}/.ssh/authorized_keys
      chown ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/.ssh/authorized_keys
    fi
  fi
}

function disable_thp {
echo "Disabling transparent huge pages."

cat <<EOF > /etc/init.d/disable-thp
#!/bin/bash
### BEGIN INIT INFO
# Provides:          disable-thp
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    couchbase-server
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable THP
# Description:       disables Transparent Huge Pages (THP) on boot
### END INIT INFO

case $1 in
start)
  if [ -d /sys/kernel/mm/transparent_hugepage ]; then
    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
    echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
  elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
    echo 'never' > /sys/kernel/mm/redhat_transparent_hugepage/enabled
    echo 'never' > /sys/kernel/mm/redhat_transparent_hugepage/defrag
  else
    return 0
  fi
;;
esac
EOF

chmod 755 /etc/init.d/disable-thp
chkconfig --add disable-thp

which tuned-adm >/dev/null 2>&1
if [ $? -eq 0 ]; then
mkdir /etc/tuned/no-thp

cat <<EOF > /etc/tuned/no-thp/tuned.conf
[main]
include=virtual-guest

[vm]
transparent_hugepages=never
EOF

tuned-adm profile no-thp
fi
}

function config_swappiness {
echo "Configuring swappiness."
echo "vm.swappiness = 0" >> /etc/sysctl.conf
echo 0 > /proc/sys/vm/swappiness
}

function install_sw_generic {
  case $LINUXTYPE in
  centos)
    yum install -y epel-release
    yum install -y bzip2 jq git python-pip wget vim-enhanced xmlstarlet java-1.8.0-openjdk maven nc sysstat yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    usermod -a -G docker $ADMINUSER
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

  mkdir /home/${ADMINUSER}/bin
  git clone https://github.com/mminichino/perf-lab-bin /home/${ADMINUSER}/bin
  chown -R ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/bin
}

function install_sw_couchbase {
  case $LINUXTYPE in
  centos)
    curl -o /var/tmp/couchbase-release-1.0-x86_64.rpm https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-x86_64.rpm
    install_pkg_file /var/tmp/couchbase-release-1.0-x86_64.rpm
    install_pkg couchbase-server-${VERSION}
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

cat <<EOF > /etc/security/limits.d/91-couchbase.conf
couchbase soft nproc 4096
couchbase hard nproc 16384
EOF
}

function prep_generic {
  exec 2>&1
  echo "Starting general host prep." | log_output
  set_linux_type
  echo "System type: $LINUXTYPE" | log_output
  nm_check | log_output
  host_dns | log_output
  host_name | log_output
  add_admin_user | log_output
  disable_thp | log_output
  config_swappiness | log_output
  install_sw_generic | log_output
}

function enable_docker {
  case $LINUXTYPE in
  centos)
    local PKGNAME="docker"
    local SVCNAME=$PKGNAME
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

  service_control start $SVCNAME
  service_control enable $SVCNAME
}

function cb_install {
  exec 2>&1
  echo "Starting Couchbase server install." | log_output
  set_linux_type
  echo "System type: $LINUXTYPE" | log_output
  install_sw_couchbase | log_output
}
