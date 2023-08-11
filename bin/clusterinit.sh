#!/bin/bash
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
MODE="debug"
SERVICES="data,index,query"
INDEX_MEM_OPT="default"
INTERNAL_IP=""
EXTERNAL_IP=""
GROUP_NAME=""
NODE_NUMBER=1
USERNAME="Administrator"
PASSWORD="password"
CLUSTER_NAME="cbdb"
if [ -d /cbdata ]; then
  chown -R couchbase:couchbase /cbdata
  chmod 775 /cbdata
  DATAPATH=/cbdata
  INDEXPATH=/cbdata
  ANALYTICSPATH=/cbdata
  EVENTINGPATH=/cbdata
else
  DATAPATH=/opt/couchbase/var/lib/couchbase/data
  INDEXPATH=/opt/couchbase/var/lib/couchbase/data
  ANALYTICSPATH=/opt/couchbase/var/lib/couchbase/data
  EVENTINGPATH=/opt/couchbase/var/lib/couchbase/data
fi
PRINT_USAGE="Usage: $0 -m | -i | -e | -s | -o | -r | -g | -u | -p | -n
             -m Mode
             -i Internal node IP
             -e External node IP
             -s Services
             -o Cluster index memory storage option
             -g Server group name
             -r Rally node for init
             -u Couchbase administrator user name
             -p Couchbase administrator password
             -n Couchbase cluster name"

while getopts "m:i:e:s:o:r:u:p:n:g:" opt
do
  case $opt in
    m)
      MODE=$OPTARG
      ;;
    i)
      INTERNAL_IP=$OPTARG
      ;;
    e)
      if [ "$OPTARG" != "none" ]; then
        EXTERNAL_IP=$OPTARG
      fi
      ;;
    s)
      SERVICES=$OPTARG
      ;;
    o)
      INDEX_MEM_OPT=$OPTARG
      ;;
    r)
      RALLY_NODE=$OPTARG
      ;;
    u)
      USERNAME=$OPTARG
      ;;
    p)
      PASSWORD=$OPTARG
      ;;
    n)
      CLUSTER_NAME=$OPTARG
      ;;
    g)
      GROUP_NAME=$OPTARG
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$(id -u)" -ne 0 ]; then
  err_exit "You must run this utility as root."
fi

case $MODE in
  config)
    cb_cluster_setup
    ;;
  rebalance)
    cb_rebalance
    ;;
  remove)
    cb_node_remove
    ;;
  write)
    cb_write_node_config
    ;;
  sgw)
    sgw_setup
    ;;
  debug)
    cb_init_debug
    ;;
  *)
    err_exit "Unknown mode $MODE"
    ;;
esac
