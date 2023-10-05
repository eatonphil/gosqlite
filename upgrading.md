# Upgrading sqlite

We need to make our own amalgamation, since we want to enable
`SQLITE_ENABLE_UPDATE_DELETE_LIMIT` during the parser generator phase.

`-DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1` seems to be the only important
option when creating the amalgamation.

```sh
./upgrade.sh
```
