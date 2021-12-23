#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
MODE="debug"
SERVICES="data,index,query"
INDEX_MEM_OPT="default"
INTERNAL_IP=""
EXTERNAL_IP=""
NODE_NUMBER=1
USERNAME="Administrator"
PASSWORD="password"
CLUSTER_NAME="cbdb"
DATAPATH=/opt/couchbase/var/lib/couchbase/data
INDEXPATH=/opt/couchbase/var/lib/couchbase/data
ANALYTICSPATH=/opt/couchbase/var/lib/couchbase/data
EVENTINGPATH=/opt/couchbase/var/lib/couchbase/data
PRINT_USAGE="Usage: $0 -m | -i | -e | -s | -o | -r
             -m Mode
             -i Internal node IP
             -e External node IP
             -s Services
             -o Cluster index memory storage option
             -r Rally node for init"

while getopts "m:i:e:s:o:r:u:p:n:" opt
do
  case $opt in
    m)
      MODE=$OPTARG
      ;;
    i)
      INTERNAL_IP=$OPTARG
      ;;
    e)
      EXTERNAL_IP=$OPTARG
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
  debug)
    cb_init_debug
    ;;
  *)
    err_exit "Unknown mode $MODE"
    ;;
esac
