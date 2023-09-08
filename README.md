[![GoDoc](https://godoc.org/github.com/eatonphil/gosqlite?status.svg)](https://godoc.org/github.com/eatonphil/gosqlite)

# gosqlite

gosqlite is a SQLite driver for the Go programming language.  It
is designed with the following goals in mind.

* **Lightweight** - Most methods should be little more than a small
  wrapper around SQLite C functions.
* **Performance** - Where possible, methods should be available to
  allow for the highest performance possible.
* **Understandable** - You should always know what SQLite functions
  are being called and in what order.
* **Unsurprising** - Connections, PRAGMAs, transactions, bindings, and
  stepping should work out of the box exactly as you would expect with
  SQLite.
* **Debuggable** - When you encounter a SQLite error, the SQLite
  documentation should be relevant and relatable to the Go code.
* **Ergonomic** - Where it makes sense, convenient compound methods
  should exist to make tasks easy and to conform to Go standard
  interfaces.

Most database drivers include a layer to work nicely with the Go
`database/sql` interface, which introduces connection pooling and
behavior differences from pure SQLite.  This driver does not include a
`database/sql` interface.

## Releases

* 2023-09-08 **v0.7.0** - SQLite version 3.43.0
* 2023-09-08 - Forked from https://github.com/bvinc/go-sqlite-lite

## Getting started

```go
import "github.com/eatonphil/gosqlite"
```

### Acquiring a connection
```go
conn, err := gosqlite.Open("mydatabase.db")
if err != nil {
	...
}
defer conn.Close()

// It's always a good idea to set a busy timeout
conn.BusyTimeout(5 * time.Second)
```

### Executing SQL
```go
err = conn.Exec(`CREATE TABLE student(name TEXT, age INTEGER)`)
if err != nil {
	...
}
// Exec can optionally bind parameters
err = conn.Exec(`INSERT INTO student VALUES (?, ?)`, "Bob", 18)
if err != nil {
	...
}
```

### Using Prepared Statements
```go
stmt, err := conn.Prepare(`INSERT INTO student VALUES (?, ?)`)
if err != nil {
	...
}
defer stmt.Close()

// Bind the arguments
err = stmt.Bind("Bill", 18)
if err != nil {
	...
}
// Step the statement
hasRow, err := stmt.Step()
if err != nil {
	...
}
// Reset the statement
err = stmt.Reset()
if err != nil {
	...
}
```

### Using Prepared Statements Conveniently

```go
stmt, err := conn.Prepare(`INSERT INTO student VALUES (?, ?)`)
if err != nil {
	...
}
defer stmt.Close()

// Exec binds arguments, steps the statement to completion, and always resets the statement
err = stmt.Exec("John", 19)
if err != nil {
	...
}
```

### Using Queries Conveniently

```go
// Prepare can prepare a statement and optionally also bind arguments
stmt, err := conn.Prepare(`SELECT name, age FROM student WHERE age = ?`, 18)
if err != nil {
	...
}
defer stmt.Close()

for {
	hasRow, err := stmt.Step()
	if err != nil {
		...
	}
	if !hasRow {
		// The query is finished
		break
	}

	// Use Scan to access column data from a row
	var name string
	var age int
	err = stmt.Scan(&name, &age)
	if err != nil {
		...
	}
	fmt.Println("name:", name, "age:", age)
}
// Remember to Reset the statement if you would like to Bind new arguments and reuse the prepared statement
```

### Getting columns that might be NULL

Scan can be convenient to use, but it doesn't handle NULL values.  To
get full control of column values, there are column methods for each
type.

```go
name, ok, err := stmt.ColumnText(0)
if err != nil {
	// Either the column index was out of range, or SQLite failed to allocate memory
	...
}
if !ok {
	// The column was NULL
}

age, ok, err := stmt.ColumnInt(1)
if err != nil {
	// Can only fail if the column index is out of range
	...
}
if !ok {
	// The column was NULL
}
```

`ColumnBlob` returns a nil slice in the case of NULL.
```go
blob, err := stmt.ColumnBlob(i)
if err != nil {
	// Either the column index was out of range, or SQLite failed to allocate memory
	...
}
if blob == nil {
	// The column was NULL
}
```

### Using Transactions

```go
// Equivalent to conn.Exec("BEGIN")
err := conn.Begin()
if err != nil {
	...
}

// Do some work
...

// Equivalent to conn.Exec("COMMIT")
err = conn.Commit()
if err != nil {
	...
}
```

### Using Transactions Conveniently

With error handling in Go, it can be pretty inconvenient to ensure
that a transaction is rolled back in the case of an error.  The
`WithTx` method is provided, which accepts a function of work to do
inside of a transaction.  `WithTx` will begin the transaction and call
the function.  If the function returns an error, the transaction will
be rolled back.  If the function succeeds, the transaction will be
committed.  `WithTx` can be a little awkward to use, but it's
necessary.  For example:

```go
err := conn.WithTx(func() error {
	return insertStudents(conn)
})
if err != nil {
	...
}

func insertStudents(conn *gosqlite.Conn) error {
	...
}
```

## Advanced Features

* Binding parameters to statements using SQLite named parameters.
* SQLite Blob Incremental IO API.
* SQLite Online Backup API.
* SQLite Session extension.
* Supports setting a custom busy handler
* Supports callback hooks on commit, rollback, and update.
* Supports setting compile-Time authorization callbacks.
* If shared cache mode is enabled and one statement receives a
  `SQLITE_LOCKED` error, the SQLite
  [unlock_notify](https://sqlite.org/unlock_notify.html) extension is
  used to transparently block and try again when the conflicting
  statement finishes.
* Compiled with SQLite support for JSON1, RTREE, FTS5, GEOPOLY, STAT4, and SOUNDEX.
* Compiled with SQLite support for OFFSET/LIMIT on UPDATE and DELETE statements.
* RawString and RawBytes can be used to reduce copying between Go and SQLite.  Please use with caution.

## Credit

This project began as a fork of https://github.com/bvinc/go-sqlite-lite.

## FAQ

### Why is there no `database/sql` interface?

If a `database/sql` interface is required, please use
https://github.com/mattn/go-gosqlite. Connection pooling causes
unnecessary overhead and weirdness. Transactions using `Exec("BEGIN")`
don't work as expected. Your connection does not correspond to
SQLite's concept of a connection. PRAGMA commands do not work as
expected. When you hit SQLite errors, such as locking or busy errors,
it's difficult to discover why since you don't know which connection
received which SQL and in what order.

### What are the differences between this driver and the bvinc/go-sqlite-lite driver?

This driver was forked from `bvinc/go-sqlite-lite`. It hadn't been
maintained in years and used an ancient version of SQLite.

### Are finalizers provided to automatically close connections and statements?

No finalizers are used in this driver. You are responsible for
closing connections and statements. While I mostly agree with
finalizers for cleaning up most accidental resource leaks, in this
case, finalizers may fix errors such as locking errors while debugging
only to find that the code works unreliably in production. Removing
finalizers makes the behavior consistent.

### Is it thread safe?

`gosqlite` is as thread safe as SQLite  SQLite with this driver
is compiled with `-DSQLITE_THREADSAFE=2` which is **Multi-thread**
mode. In this mode, SQLite can be safely used by multiple threads
provided that no single database connection is used simultaneously in
two or more threads.  This applies to goroutines.  A single database
connection should not be used simultaneously between two goroutines.

It is safe to use separate connection instances concurrently, even if
they are accessing the same database file. For example:

```go
// ERROR (without any extra synchronization)
c, _ := gosqlite.Open("sqlite.db")
go use(c)
go use(c)
```
```go
// OK
c1, _ := gosqlite.Open("sqlite.db")
c2, _ := gosqlite.Open("sqlite.db")
go use(c1)
go use(c2)
```

Consult the SQLite documentation for more information.

https://www.sqlite.org/threadsafe.html

### How do I pool connections for handling HTTP requests?

Opening new connections is cheap and connection pooling is generally
unnecessary for SQLite.  I would recommend that you open a new
connection for each request that you're handling.  This ensures that
each request is handled separately and the normal rules of SQLite
database/table locking apply.

If you've decided that pooling connections provides you with an
advantage, it would be outside the scope of this package and something
that you would need to implement and ensure works as needed.

## License

This project is licensed under the BSD license.
