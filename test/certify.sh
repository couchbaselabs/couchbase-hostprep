#!/bin/bash
#
host_prep_repo="mminichino/hostprep"
sgw_version="3.0.0"

which yum >/dev/null 2>&1
if [ $? -eq 0 ]; then
  cb_version="7.1.0-2556"
else
  cb_version="7.1.0-2556-1"
fi

echo "Testing bootstrap"

curl -sfL https://raw.githubusercontent.com/${host_prep_repo}/main/bin/bootstrap.sh | sudo -E bash -

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."

echo "Testing repo pull"

sudo git clone https://github.com/${host_prep_repo} /usr/local/hostprep

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."

echo "Testing Couchbase prep"

sudo /usr/local/hostprep/bin/hostprep.sh -t couchbase -v ${cb_version}

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."

echo "Testing Sync Gateway pull"

sudo /usr/local/hostprep/bin/hostprep.sh -t sgw -g ${sgw_version}

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."
