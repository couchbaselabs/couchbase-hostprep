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
  if [ -z "$LINUXTYPE" ]; then
    source /etc/os-release
    export LINUXTYPE=$ID
    case $ID in
    centos)
      PKGMGR="yum"
      SVCMGR="systemctl"
      DEFAULT_ADMIN_GROUP="wheel"
      ;;
    ubuntu)
      PKGMGR="apt"
      SVCMGR="systemctl"
      DEFAULT_ADMIN_GROUP="sudo"
      ;;
    *)
      err_exit "Unknown Linux distribution $ID"
      ;;
    esac
  fi
}

function install_pkg {
  set_linux_type
  case $PKGMGR in
  yum)
    yum install -q -y $@
    ;;
  apt)
    apt-get update
    apt-get install -q -y $@
    ;;
  *)
    err_exit "Unknown package manager $PKGMGR"
    ;;
  esac
}

function install_pkg_file {
  set_linux_type
  case $PKGMGR in
  yum)
    rpm -i $@
    ;;
  apt)
    dpkg -i $@
    ;;
  *)
    err_exit "Unknown package manager $PKGMGR"
    ;;
  esac
}

function service_control {
  set_linux_type
  case $SVCMGR in
  systemctl)
    systemctl $@
    ;;
  *)
    err_exit "Unknown service manager $SVCMGR"
    ;;
  esac
}

function nm_check {
  set_linux_type
  case $LINUXTYPE in
  centos)
    local PKGNAME="NetworkManager"
    local SVCNAME=$PKGNAME
    ;;
  ubuntu)
    local PKGNAME="network-manager"
    local SVCNAME="NetworkManager.service"
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
  set_linux_type
  local MYGID=$(cat /etc/group | grep -v nobody | cut -d: -f3 | sort -n | tail -1)
  local MYUID=$(cat /etc/passwd | grep -v nobody | cut -d: -f3 | sort -n | tail -1)
  MYGID=$((MYGID + 1))
  MYUID=$((MYUID + 1))

  grep ^${ADMINUSER} /etc/group >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    groupadd -g $MYGID $ADMINUSER
  fi

  grep ^${ADMINUSER} /etc/passwd >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    useradd -m -u $MYUID -g $ADMINUSER $ADMINUSER
  fi

  usermod -a -G $DEFAULT_ADMIN_GROUP $ADMINUSER
  echo "${ADMINUSER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${ADMINUSER}
  chmod 440 /etc/sudoers.d/${ADMINUSER}
  [ ! -d /home/${ADMINUSER}/.ssh ] && mkdir /home/${ADMINUSER}/.ssh
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

# shellcheck disable=SC2120
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
case $LINUXTYPE in
centos)
  chkconfig --add disable-thp
  ;;
ubuntu)
  update-rc.d disable-thp defaults
  ;;
*)
  err_exit "Unknown linux type $LINUXTYPE"
  ;;
esac

which tuned-adm >/dev/null 2>&1
if [ $? -eq 0 ]; then
[ ! -d /etc/tuned/no-thp ] && mkdir /etc/tuned/no-thp

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
  set_linux_type
  case $LINUXTYPE in
  centos)
    install_pkg epel-release
    install_pkg bzip2 jq git python3 python3-pip python3-devel wget vim-enhanced xmlstarlet java-1.8.0-openjdk maven nc sysstat yum-utils bind-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    install_pkg docker-ce docker-ce-cli containerd.io
    usermod -a -G docker $ADMINUSER
    ;;
  ubuntu)
    install_pkg bzip2 jq git python3 python3-pip python3-dev wget vim xmlstarlet openjdk-8-jdk maven netcat sysstat apt-utils bind9-utils ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    install_pkg docker-ce docker-ce-cli containerd.io
    usermod -a -G docker $ADMINUSER
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

  if [ -d /home/${ADMINUSER}/bin ]; then
    cp -pr /home/${ADMINUSER}/bin /home/${ADMINUSER}/bin.backup
    rm -rf /home/${ADMINUSER}/bin
  fi
  mkdir /home/${ADMINUSER}/bin
  git clone -q https://github.com/mminichino/perf-lab-bin /home/${ADMINUSER}/bin
  chown -R ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/bin
}

function install_sw_couchbase {
  set_linux_type
  case $LINUXTYPE in
  centos)
    curl -s -o /var/tmp/couchbase-release-1.0-x86_64.rpm https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-x86_64.rpm
    install_pkg_file /var/tmp/couchbase-release-1.0-x86_64.rpm
    install_pkg couchbase-server-${CB_VERSION}
    ;;
  ubuntu)
    curl -s -o /var/tmp/couchbase-release-1.0-amd64.deb https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-amd64.deb
    install_pkg_file /var/tmp/couchbase-release-1.0-amd64.deb
    install_pkg couchbase-server=${CB_VERSION}
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac

cat <<EOF > /etc/security/limits.d/91-couchbase.conf
* soft nproc 10000
* hard nproc 10000
* soft nofile 70000
* hard nofile 70000
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

function prep_couchbase {
  exec 2>&1
  echo "Starting general host prep." | log_output
  set_linux_type
  echo "System type: $LINUXTYPE" | log_output
  add_admin_user | log_output
  disable_thp | log_output
  config_swappiness | log_output
  install_sw_generic | log_output
}

function enable_docker {
  set_linux_type
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

function disable_firewall {
  set_linux_type
  case $LINUXTYPE in
  centos)
    systemctl status firewalld >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      service_control stop firewalld
      service_control disable firewalld
    fi
    ;;
  ubuntu)
    ufw disable
    ;;
  *)
    err_exit "Unknown linux type $LINUXTYPE"
    ;;
  esac
}

function enable_chrony {
  if [ -z "$(ps -ef |grep ntpd |grep -v grep)" -a -z "$(ps -ef |grep chronyd |grep -v grep)" ]; then
    set_linux_type
    case $LINUXTYPE in
    centos)
      install_pkg chrony
      service_control enable chronyd
      service_control start chronyd
      ;;
    ubuntu)
      install_pkg chrony
      service_control enable chrony
      service_control start chrony
      ;;
    *)
      err_exit "Unknown linux type $LINUXTYPE"
      ;;
    esac
  fi
}

function prep_basic {
  exec 2>&1
  echo "Starting general host prep." | log_output
  set_linux_type
  echo "System type: $LINUXTYPE" | log_output
  nm_check | log_output
  host_name | log_output
  add_admin_user | log_output
  disable_thp | log_output
  config_swappiness | log_output
  install_sw_generic | log_output
  enable_docker | log_output
  disable_firewall | log_output
  enable_chrony | log_output
}

function get_mem_settings {
  HOST_MEMORY=$(free -m | awk 'NR==2 {print $2}')
  EVENTING_MEM=256
  HOST_MEMORY=$((HOST_MEMORY - EVENTING_MEM))
  ANALYTICS_MEM=$(printf "%.0f" $((HOST_MEMORY / 5)))
  HOST_MEMORY=$((HOST_MEMORY - ANALYTICS_MEM))
  FTS_MEM=512
  HOST_MEMORY=$((HOST_MEMORY - FTS_MEM))
  INDEX_MEM=768
  HOST_MEMORY=$((HOST_MEMORY - INDEX_MEM))
  DATA_MEM=$(printf "%.0f" $((HOST_MEMORY * 13/20)))
}

function dns_reverse_lookup {
[ -z "$1" ] && return
for dnsname in $(dig +noall +answer -x $1 | grep -v '^;;' | awk '{print $NF}' | sed -e 's/\.$//')
do
  check_dns_authority=$(dig +noall +authority $dnsname | grep -v '^;;')
  if [ -n "$check_dns_authority" ]; then
    echo $dnsname
    return
  fi
done
}

function cb_cluster_setup {
  get_mem_settings
  cb_read_node_config

  echo "Configuring a Couchbase cluster"

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_cluster_setup: no rally node set. Aborting."
  fi

  if [ -z "$INTERNAL_IP" ]; then
    err_exit "cb_cluster_setup: no IP set for the node. Aborting."
  fi

  if [ ! -x /opt/couchbase/bin/couchbase-cli ]; then
    err_exit "cb_cluster_setup: Couchbase CLI not found."
  fi

  if [ "$INTERNAL_IP" = "$RALLY_NODE" ]; then
    cb_node_init
  else
    cb_node_add
  fi
}

function cb_node_init {
  get_mem_settings

  if [ ! -f /etc/cb_node.cfg ]; then
    err_exit "No local node config file /etc/cb_node.cfg found."
  fi

  cb_read_node_config

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_node_init: no rally node set. Aborting."
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $RALLY_NODE)
  if [ -n "$REVERSE_LOOKUP" ]; then
    RALLY_HOST_NAME=$REVERSE_LOOKUP
  else
    RALLY_HOST_NAME=$RALLY_NODE
  fi

  echo "Couchbase Cluster $CLUSTER_NAME Init On $RALLY_HOST_NAME"

  if /opt/couchbase/bin/couchbase-cli host-list \
  --cluster $RALLY_HOST_NAME \
  --username $USERNAME \
  --password "$PASSWORD" | \
  grep -q $RALLY_HOST_NAME; then
    echo "The node already exists in the cluster"
  else
  /opt/couchbase/bin/couchbase-cli node-init \
    --cluster $RALLY_HOST_NAME \
    --username $USERNAME \
    --password "$PASSWORD" \
    --node-init-hostname $RALLY_HOST_NAME \
    --node-init-data-path $DATAPATH \
    --node-init-index-path $INDEXPATH \
    --node-init-analytics-path $ANALYTICSPATH \
    --node-init-eventing-path $EVENTINGPATH
  fi

  if /opt/couchbase/bin/couchbase-cli setting-cluster \
    --cluster $RALLY_HOST_NAME \
    --username $USERNAME \
    --password "$PASSWORD" | \
    grep -q 'ERROR: Cluster is not initialized'; then
    /opt/couchbase/bin/couchbase-cli cluster-init \
      --cluster $RALLY_HOST_NAME \
      --cluster-username $USERNAME \
      --cluster-password "$PASSWORD" \
      --cluster-port 8091 \
      --cluster-ramsize $DATA_MEM \
      --cluster-fts-ramsize $FTS_MEM \
      --cluster-index-ramsize $INDEX_MEM \
      --cluster-eventing-ramsize $EVENTING_MEM \
      --cluster-analytics-ramsize $ANALYTICS_MEM \
      --cluster-name $CLUSTER_NAME \
      --index-storage-setting $INDEX_MEM_OPT \
      --services $SERVICES
  else
    echo "Already initialized"
  fi

  if [ -n "$EXTERNAL_IP" ]; then
    cb_node_alt_address
  fi

  if [ -n "$GROUP_NAME" ]; then
    cb_server_group
  fi
}

function cb_node_add {
  get_mem_settings

  if [ ! -f /etc/cb_node.cfg ]; then
    err_exit "No local node config file /etc/cb_node.cfg found."
  fi

  cb_read_node_config

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_node_add: no rally node set. Aborting."
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $RALLY_NODE)
  if [ -n "$REVERSE_LOOKUP" ]; then
    RALLY_HOST_NAME=$REVERSE_LOOKUP
  else
    RALLY_HOST_NAME=$RALLY_NODE
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $INTERNAL_IP)
  if [ -n "$REVERSE_LOOKUP" ]; then
    ADD_HOST_NAME=$REVERSE_LOOKUP
  else
    ADD_HOST_NAME=$INTERNAL_IP
  fi

  echo "Waiting for cluster to initialize on $RALLY_HOST_NAME."
  cb_wait_init
  if [ $? -ne 0 ]; then
    err_exit "Timeout waiting for cluster to initialize"
  fi

  echo "Couchbase Node $ADD_HOST_NAME Add"

  if /opt/couchbase/bin/couchbase-cli host-list \
  --cluster $RALLY_HOST_NAME \
  --username $USERNAME \
  --password "$PASSWORD" | \
  grep -q $ADD_HOST_NAME; then
    echo "The node already exists in the cluster"
  else
  /opt/couchbase/bin/couchbase-cli node-init \
    --cluster $ADD_HOST_NAME \
    --username $USERNAME \
    --password "$PASSWORD" \
    --node-init-hostname $ADD_HOST_NAME \
    --node-init-data-path $DATAPATH \
    --node-init-index-path $INDEXPATH \
    --node-init-analytics-path $ANALYTICSPATH \
    --node-init-eventing-path $EVENTINGPATH
  fi

  if /opt/couchbase/bin/couchbase-cli host-list \
  --cluster $RALLY_HOST_NAME \
  --username $USERNAME \
  --password "$PASSWORD" | \
  grep -q $ADD_HOST_NAME; then
    echo "The node already exists in the cluster"
  else
  /opt/couchbase/bin/couchbase-cli server-add \
    --cluster $RALLY_HOST_NAME \
    --username $USERNAME \
    --password "$PASSWORD" \
    --server-add-username $USERNAME \
    --server-add-password "$PASSWORD" \
    --server-add $ADD_HOST_NAME \
    --services $SERVICES
  fi

  if [ -n "$EXTERNAL_IP" ]; then
    cb_node_alt_address
  fi

  if [ -n "$GROUP_NAME" ]; then
    cb_server_group
  fi
}

function cb_node_alt_address {
  cb_read_node_config

  if [ -z "$EXTERNAL_IP" ]; then
    return
  fi

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_node_alt_address: no rally node set. Aborting."
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $RALLY_NODE)
  if [ -n "$REVERSE_LOOKUP" ]; then
    RALLY_HOST_NAME=$REVERSE_LOOKUP
  else
    RALLY_HOST_NAME=$RALLY_NODE
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $INTERNAL_IP)
  if [ -n "$REVERSE_LOOKUP" ]; then
    ADD_HOST_NAME=$REVERSE_LOOKUP
  else
    ADD_HOST_NAME=$INTERNAL_IP
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $EXTERNAL_IP)
  if [ -n "$REVERSE_LOOKUP" ]; then
    EXT_HOST_NAME=$REVERSE_LOOKUP
  else
    EXT_HOST_NAME=$EXTERNAL_IP
  fi

  echo "Couchbase Node Alternate Address"

  /opt/couchbase/bin/couchbase-cli setting-alternate-address \
    --cluster $RALLY_HOST_NAME \
    --username $USERNAME \
    --password "$PASSWORD" \
    --set \
    --node $ADD_HOST_NAME \
    --hostname $EXT_HOST_NAME
}

function cb_rebalance {
  cb_read_node_config

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_rebalance: no rally node set. Aborting."
  fi

  echo "Couchbase rebalance"

  /opt/couchbase/bin/couchbase-cli rebalance \
    --cluster $RALLY_NODE \
    --username $USERNAME \
    --password "$PASSWORD" \
    --no-progress-bar
}

function cb_server_group {
  if [ ! -f /etc/cb_node.cfg ]; then
    err_exit "No local node config file /etc/cb_node.cfg found."
  fi

  cb_read_node_config

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_node_add: no rally node set. Aborting."
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $RALLY_NODE)
  if [ -n "$REVERSE_LOOKUP" ]; then
    RALLY_HOST_NAME=$REVERSE_LOOKUP
  else
    RALLY_HOST_NAME=$RALLY_NODE
  fi

  REVERSE_LOOKUP=$(dns_reverse_lookup $INTERNAL_IP)
  if [ -n "$REVERSE_LOOKUP" ]; then
    LOCAL_HOST_NAME=$REVERSE_LOOKUP
  else
    LOCAL_HOST_NAME=$INTERNAL_IP
  fi

  if [ -z "$GROUP_NAME" ]; then
    info_msg "${LOCAL_HOST_NAME}: No server group defined, using default group."
    return
  fi

  if /opt/couchbase/bin/couchbase-cli group-manage \
      --cluster $RALLY_NODE \
      --username $USERNAME \
      --password "$PASSWORD" \
      --list \
      --group-name "$GROUP_NAME" >/dev/null 2>&1
    then
      echo "${LOCAL_HOST_NAME}: Server group $GROUP_NAME already exists."
    else
      /opt/couchbase/bin/couchbase-cli group-manage \
        --cluster $RALLY_NODE \
        --username $USERNAME \
        --password "$PASSWORD" \
        --create \
        --group-name "$GROUP_NAME"
        [ $? -ne 0 ] && err_exit "${LOCAL_HOST_NAME}: can not create group $GROUP_NAME"
    fi

    CURRENT_GROUP=$(curl -sk -X GET -u "${USERNAME}:${PASSWORD}" http://${RALLY_NODE}:8091/pools/default/serverGroups \
    | jq --arg host $LOCAL_HOST_NAME -r '.groups[] | .name as $NAME | .nodes[] | select(.hostname | contains($host)) | $NAME')

    if [ "$CURRENT_GROUP" != "$GROUP_NAME" ]; then
    /opt/couchbase/bin/couchbase-cli group-manage \
      --cluster $RALLY_NODE \
      --username $USERNAME \
      --password "$PASSWORD" \
      --move-servers $LOCAL_HOST_NAME \
      --from-group "$CURRENT_GROUP" \
      --to-group "$GROUP_NAME"
      [ $? -ne 0 ] && err_exit "${LOCAL_HOST_NAME}: can not move from $CURRENT_GROUP to $GROUP_NAME"
    fi

    info_msg "${LOCAL_HOST_NAME}: is now a member of $GROUP_NAME"
}

function cb_wait_init {
  RETRY=1
  cb_read_node_config

  if [ -z "$RALLY_NODE" ]; then
    err_exit "cb_wait_init: no rally node set. Aborting."
  fi

  while true
  do
    /opt/couchbase/bin/couchbase-cli server-list \
      --cluster $RALLY_NODE \
      --username $USERNAME \
      --password "$PASSWORD" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 0
    fi
    if [ "$RETRY" -eq 60 ]; then
      return 1
    fi
    RETRY=$((RETRY + 1))
    sleep 1
  done
}

function cb_node_remove {
  echo "Couchbase Node Remove"
}

function cb_init_debug {
  get_mem_settings
  (
  echo "Debug mode"
  echo "Rally node: $RALLY_NODE"
  if [ -f /etc/cb_node.cfg ]; then
    cb_read_node_config
    echo "CB Config File:"
    echo "==============="
    cat /etc/cb_node.cfg
    echo "==============="
  else
    echo "No CB Config File."
  fi
  echo "INTERNAL_IP = $INTERNAL_IP"
  echo "EXTERNAL_IP = $EXTERNAL_IP"
  echo "SERVICES = $SERVICES"
  echo "INDEX_MEM_OPT = $INDEX_MEM_OPT"
  echo "DATA_MEM = $DATA_MEM"
  echo "FTS_MEM = $FTS_MEM"
  echo "INDEX_MEM = $INDEX_MEM"
  echo "EVENTING_MEM = $EVENTING_MEM"
  echo "ANALYTICS_MEM = $ANALYTICS_MEM"
  ) | tee /var/tmp/debug.out
}

function cb_write_node_config {
  echo "${INTERNAL_IP}:${EXTERNAL_IP}:${SERVICES}:${INDEX_MEM_OPT}:${GROUP_NAME}" > /etc/cb_node.cfg
}

function cb_read_node_config {
  if [ -f /etc/cb_node.cfg ]; then
    INTERNAL_IP=$(cat /etc/cb_node.cfg | cut -d: -f1)
    EXTERNAL_IP=$(cat /etc/cb_node.cfg | cut -d: -f2)
    SERVICES=$(cat /etc/cb_node.cfg | cut -d: -f3)
    INDEX_MEM_OPT=$(cat /etc/cb_node.cfg | cut -d: -f4)
    GROUP_NAME=$(cat /etc/cb_node.cfg | cut -d: -f5)
  fi
}
