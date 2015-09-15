#!/bin/bash
# Wrap the wrappables...
PATH="/usr/local/bin:$PATH"
pushd /opt/puppetdb.pl > /dev/null 2>&1
carton exec -- ./bin/puppetdb.pl "$@"
popd > /dev/null 2>&1
