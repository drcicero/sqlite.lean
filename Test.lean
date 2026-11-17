import Sqlite
open Sqlite

abbrev Car: Sig := [("id", .INT), ("name", .TXT), ("price", .INT)]

def main : IO Unit := do
  IO.println <| <- Sqlite.version

  let db <- Sqlite.mk ":memory:"
  db.exec "SELECT SQLITE_VERSION()"
  db.exec "PRAGMA database_list"
  --db.exec "DROP TABLE IF EXISTS cars"

  let cars <- db.getOrCreateTable "cars" Car
  let cur  <- cars.prepInsert
  cur.write (1, "Audi",        52642, ())
  cur.write (2, "Mercedes",    57127, ())
  cur.write (3, "Skoda",        9000, ())
  cur.write (4, "Volvo",       29000, ())
  cur.write (5, "Bentley",    350000, ())
  cur.write (6, "Citroen",     21000, ())
  cur.write (7, "Hummer",      41400, ())
  cur.write (8, "Volkswagen",  21600, ())

  db.exec "SELECT * FROM sqlite_master"

  for row in <- (<- cars.prepSelect).readAll do
    IO.println s!"  {repr row}"
  db.exec "SELECT * FROM cars WHERE Price > 29000"
  db.exec "SELECT name FROM cars WHERE Price > 29000"

  -- regression checks for the FFI layer
  db.exec "SELECT 1.5, NULL, 'a' || 'b', -1, 9223372036854775807"
  try db.exec "SELEKT 1" catch e => IO.println s!"  caught: {e}"
  try db.exec "SELECT * FROM nope" catch e => IO.println s!"  caught: {e}"
  db.exec "SELECT count(*) FROM cars" -- db still usable after prepare errors
  try discard <| db.getOrCreateTable "cars" [("id", .TXT)] catch e => IO.println s!"  caught: {e}"
  let c <- db.prep "SELECT ?, ?, ?, ?"
  c.bindFloat 1 2.5
  c.bindInt64 2 (-(2^40))
  c.bindString 3 "über"
  c.bindNull 4
  let (true) <- c.step | throw (IO.userError "expected a row")
  IO.println s!"  float={<- c.readFloat 0} i64={<- c.readInt64 1} txt={<- c.readString 2} null={repr (<- c.readString 3)}"

  -- a failed write resets the statement, so the next write works
  db.exec "CREATE TABLE uniq(id INT UNIQUE)"
  let u <- (<- db.getOrCreateTable "uniq" [("id", .INT)]).prepInsert
  u.write (1, ())
  try u.write (1, ()) catch e => IO.println s!"  caught: {e}"
  u.write (2, ())
  db.exec "SELECT * FROM uniq"

  -- table/column names are quoted, so they can't inject SQL
  let evil := "x\"); DROP TABLE cars; --"
  let t <- db.getOrCreateTable evil [("order", .INT), ("a\"b c", .TXT)]
  (<- t.prepInsert).write (1, "ok", ())
  for row in <- (<- t.prepSelect).readAll do IO.println s!"  {repr row}"
  db.exec "SELECT count(*) FROM cars"
