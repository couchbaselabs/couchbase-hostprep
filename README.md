# hostprep

Toolset to prep and install Couchbase and Sync Gateway on Linux hosts

## Disclaimer

> This package is **NOT SUPPORTED BY COUCHBASE**. The toolset is under active development, therefore features and functionality can change.

## Quick Start

Install prerequisites:
````
# curl -sfL https://raw.githubusercontent.com/mminichino/hostprep/main/bin/bootstrap.sh | sudo -E bash -
````

Install the package:
````
# git clone https://github.com/mminichino/hostprep /usr/local/hostprep
````

Prep Ubuntu host for Couchbase Server 7.1:
````
# /usr/local/hostprep/bin/hostprep.sh -t couchbase -v 7.1.0-2556-1
````

Prep CentOS host for Couchbase Server 7.1:
````
# /usr/local/hostprep/bin/hostprep.sh -t couchbase -v 7.1.0-2556
````

Write Couchbase node configuration parameters to a host:
````
# /usr/local/hostprep/bin/clusterinit.sh -m write -i 10.1.2.3 -e 172.16.4.5 -s "data,index,query" -o memopt -g us-east-2a
````

Configure Couchbase node based on stored configuration:
````
# /usr/local/hostprep/bin/clusterinit.sh -m config -r 10.1.2.3 -n cbcluster
````

Configure Sync Gateway node:
````
# /usr/local/hostprep/bin/hostprep.sh -t sgw -g 3.0.0
# /usr/local/hostprep/bin/clusterinit.sh -m sgw -r 10.1.2.3
````

## hostprep.sh options
| Option | Description                         |
|--------|-------------------------------------|
| -t     | Host type                           |
| -v     | Couchbase version                   |
| -g     | Sync Gateway version                |
| -n     | DNS server                          |
| -d     | DNS domain                          |
| -h     | Hostname                            |
| -u     | Admin username                      |
| -U     | Non-root user to pattern            |
| -c     | Call function from library and exit |

## clusterinit.sh options
| Option | Description                         |
|--------|-------------------------------------|
| -m     | Mode                                |
| -i     | Internal node IP                    |
| -e     | External node IP                    |
| -s     | Services                            |
| -o     | Cluster index memory storage option |
| -g     | Server group name                   |
| -r     | Rally node for init                 |
| -u     | Couchbase administrator user name   |
| -p     | Couchbase administrator password    |
| -n     | Couchbase cluster name              |