#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

#
# Create a "light" version of sdc-clients and its npm deps. Specifically this
# is about having a binary-module-free and small distro of sdc-clients for
# usage in the platform.
#
# Here "light" means:
# - no ldapjs and the clients that use it (not currently needed by platform
#   scripts)
# - no binary modules
# - Stripped down npm module installs. We attempt to get it down to:
#       $NAME/
#           package.json
#           index.js
# - flatten deps (i.e. no deeply nested node_modules dirs)
#
#
# Warnings:
# - This *does* involve taking liberties with specified dependency
#   versions. E.g. You get the version of the shared dtrace-provider already
#   in "/usr/node/node_modules/dtrace-provider".
# - This will start with the node-sdc-clients.git#master and attempt to get
#   the version of deps that its package.json specifies. However, you need
#   to worry about recursive version mismatches and new/removed module
#   deps manually.
#
#
# Usage:
#       ./mk-sdc-clients-light.sh [SHA] [TARGET-DIR] [LIBS...]
#
# By default SHA is "master". It is the version of node-sdc-clients.git to use.
# By default TARGET-DIR is "./node_modules/sdc-clients".
# By default if LIBS is excluded, then all sdc-clients/lib/*.js API modules
#       are included. Note that UFDS-direct "APIs" are always excluded
#       (ufds.js, etc.) If any LIBS are specified, then only those are
#       kept.
#
#
# Examples:
#       ./mk-sdc-clients-light.sh master node_modules/sdc-clients imgapi.js amon.js
#

if [ "$TRACE" != "" ]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail



#---- support stuff

function fatal
{
    echo "$(basename $0): fatal error: $*"
    exit 1
}

function errexit
{
    [[ $1 -ne 0 ]] || exit 0
    fatal "error exit status $1 at line $2"
}

trap 'errexit $? $LINENO' EXIT



#---- mainline

SHA=$1
if [[ -z "$SHA" ]]; then
    SHA=master
fi
shift

D=$1
if [[ -z "$D" ]]; then
    D=node_modules/sdc-clients
fi
shift

LIBS=$*

rm -rf $D
mkdir -p $D
cd $D

# sdc-clients (stripped of ldap-using clients)
mkdir _repos
(cd _repos && git clone git@github.com:joyent/node-sdc-clients.git)
(cd _repos/node-sdc-clients && git checkout $SHA)
mv _repos/node-sdc-clients/{package.json,lib} .
(cd lib && rm -f config.js package.js ufds.js mapi.javascript assertions.js)

if [[ -n "$LIBS" ]]; then
    for LIB in $(cd lib && ls -1 *api.js) amon.js ca.js; do
        if [[ -z $(echo "$LIBS" | grep "\<$LIB\>") ]]; then
            rm -f lib/$LIB
        fi
    done
fi

# restify (stripped down just for client usage)
DEP=$(json -f package.json dependencies.restify)
if [[ ${DEP:0:6} == "git://" ]]; then
    (cd _repos && git clone git://github.com/mcavage/node-restify.git)
    SHA=$(json -f package.json dependencies.restify | cut -d'#' -f2)
    [[ -n "$SHA" ]] || fatal "error finding restify dep git sha"
    (cd _repos/node-restify && git checkout $SHA)
    mkdir -p node_modules/restify
    mv _repos/node-restify/{LICENSE,package.json,lib} node_modules/restify
else
    npm install restify@$DEP
    (cd node_modules/restify \
        && rm -rf node_modules bin README.md CHANGES.md .npmignore)
fi
(cd node_modules/restify/lib \
    && rm -rf formatters plugins request.js response.js \
        router.js server.js)

# assert-plus
npm install assert-plus

# backoff (used by restify)
VER=$(json -f node_modules/restify/package.json dependencies.backoff)
npm install backoff@$VER
(cd node_modules/backoff \
    && rm -rf .[a-z]* examples README.md tests)

# clone (used by restify)
VER=$(json -f node_modules/restify/package.json dependencies.clone)
npm install clone@$VER
(cd node_modules/clone \
    && rm -rf .[a-z]* README.md test.js)

# verror
VER=$(json -f package.json dependencies.verror)
npm install verror@$VER
(cd node_modules/verror \
    && rm -rf .[a-z]* node_modules README.md examples Makefile* jsl.node.conf tests)

# extsprintf (used by verror)
VER=$(json -f node_modules/verror/package.json dependencies.extsprintf)
npm install extsprintf@$VER
(cd node_modules/extsprintf \
    && rm -rf .[a-z]* node_modules README.md examples Makefile* jsl.node.conf)

# async
VER=$(json -f package.json dependencies.async)
npm install async@$VER
(cd node_modules/async \
    && rm -rf .[a-z]* node_modules README.md Makefile*)

# vasync
VER=$(json -f package.json dependencies.vasync)
npm install vasync@$VER
(cd node_modules/vasync \
    && rm -rf .[a-z]* node_modules README.md examples Makefile* jsl.node.conf)

# jsprim (used by vasync)
VER=$(json -f node_modules/vasync/package.json dependencies.jsprim)
npm install jsprim@$VER
(cd node_modules/jsprim \
    && rm -rf .[a-z]* node_modules README.md Makefile* test jsl.node.conf)

# json-schema (used by jsprim, but not by our code path, so we no-op it)
touch node_modules/json-schema.js

# keep-alive-agent (used by restify)
VER=$(json -f node_modules/restify/package.json dependencies.keep-alive-agent)
npm install keep-alive-agent@$VER
(cd node_modules/keep-alive-agent \
    && rm -rf .[a-z]* node_modules README.md test)

# lru-cache
VER=$(json -f package.json dependencies.lru-cache)
npm install lru-cache@$VER
(cd node_modules/lru-cache \
    && rm -rf .[a-z]* node_modules AUTHORS README.md test)

# mime (used by restify)
VER=$(json -f node_modules/restify/package.json dependencies.mime)
npm install mime@$VER
(cd node_modules/mime \
    && rm -rf .[a-z]* node_modules README.md test.js)

# once (used by restify)
VER=$(json -f node_modules/restify/package.json dependencies.once)
npm install once@$VER
(cd node_modules/once \
    && rm -rf .[a-z]* node_modules README.md test)

# node-uuid
VER=$(json -f package.json dependencies.node-uuid)
npm install node-uuid@$VER
(cd node_modules/node-uuid \
    && rm -rf .[a-z]* node_modules README.md test benchmark)

# ssh-agent
VER=$(json -f package.json dependencies.ssh-agent)
npm install ssh-agent@$VER
(cd node_modules/ssh-agent \
    && rm -rf .[a-z]* node_modules README.md bin tst)

# ctype (used by ssh-agent)
VER=$(json -f node_modules/ssh-agent/package.json dependencies.ctype)
npm install ctype@$VER
(cd node_modules/ctype \
    && rm -rf .[a-z]* node_modules README* tools man tst CHANGELOG)

# Drop this hack when <https://github.com/mcavage/node-restify/pull/313>
# is pulled.
touch node_modules/semver.js

# bunyan
# Patch bunyan usages to use the platform one, because it has dtrace-provider
# hooked up.
patch -p0 <<PATCH
--- node_modules/restify/lib/bunyan_helper.js.orig  2013-02-05 15:39:13.000000000 -0800
+++ node_modules/restify/lib/bunyan_helper.js   2013-02-05 15:40:49.000000000 -0800
@@ -4,7 +4,11 @@
 var util = require('util');

 var assert = require('assert-plus');
-var bunyan = require('bunyan');
+if (process.platform === 'sunos') {
+    bunyan = require('/usr/node/node_modules/bunyan');
+} else {
+    bunyan = require('bunyan');
+}
 var LRU = require('lru-cache');
 var uuid = require('node-uuid');

--- node_modules/restify/lib/index.js.orig  2013-02-05 16:08:51.000000000 -0800
+++ node_modules/restify/lib/index.js   2013-02-05 16:09:04.000000000 -0800
@@ -7,6 +7,8 @@
 // and enables much faster load times
 //

+process.env.RESTIFY_CLIENT_ONLY = 1;
+
 function createClient(options) {
         var assert = require('assert-plus');
         var bunyan = require('./bunyan_helper');
--- node_modules/restify/lib/dtrace.js
+++ node_modules/restify/lib/dtrace.js
@@ -38,7 +38,7 @@
 module.exports = function exportStaticProvider() {
         if (!PROVIDER) {
                 try {
-                        var dtrace = require('dtrace-provider');
+                        var dtrace = require('/usr/node/node_modules/dtrace-provider');
                         PROVIDER = dtrace.createDTraceProvider('restify');
                 } catch (e) {
                         PROVIDER = {
PATCH


rm -rf node_modules/.bin
rm -rf _repos
