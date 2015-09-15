#!/bin/bash
# Wrap the wrappables...
PATH="/usr/local/bin:$PATH"
eval "$(plenv init -)"
pushd /opt/puppetdb-stencils > /dev/null 2>&1
carton exec -- ./bin/puppetdb.pl "$@"
popd > /dev/null 2>&1
