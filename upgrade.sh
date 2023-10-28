#!/usr/bin/env bash

set -eu

VERSION=3430200
wrk="$(pwd)"
pushd "$(mktemp -d)"
wget "https://www.sqlite.org/2023/sqlite-src-$VERSION.zip"
unzip "sqlite-src-$VERSION.zip"
cd "sqlite-src-$VERSION"
CFLAGS='-DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1' ./configure
make sqlite3.c
cp sqlite3.c sqlite3.h "$wrk/"
popd
