# Upgrading sqlite

We need to make our own amalgamation, since we want to enable
`SQLITE_ENABLE_UPDATE_DELETE_LIMIT` during the parser generator phase.

`-DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1` seems to be the only important
option when creating the amalgamation.

```sh
VERSION=3.43.0
wrk=$(pwd)
pushd $(mktemp -d)
wget https://www.sqlite.org/2023/sqlite-src-$VERSION.zip
unzip sqlite-src-$VERSION.zip 
cd sqlite-src-$VERSION
CFLAGS='-DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1' ./configure
make sqlite3.c
cp sqlite3.c sqlite3.h $wrk/
popd
```
