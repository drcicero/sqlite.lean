import Sqlite

def Sqlite.Db.exec : Sqlite.Db -> String -> IO PUnit := fun db stmt => do
  IO.println s!"> {stmt}"
  let stmt <- db.prepare stmt
  let mut ok <- stmt.step
  let count <- stmt.cols
  let header <- (List.range count.toNat).mapM fun i =>
    return (<- stmt.getName i, <- stmt.getType i)
  IO.print "  "
  IO.println <| header
  while ok == 100 do
    IO.print "  "
    IO.println <| <- header.enum.mapM fun (i, nmtp) => return s!"{<- stmt.readString i}"
    ok <- stmt.step
  IO.println s!"  DONE {ok}"
  return ()

def main : IO Unit := do
  IO.println <| <- Sqlite.version

  let db <- Sqlite.mk ":memory:"

  db.exec "SELECT SQLITE_VERSION()"

  db.exec "DROP TABLE IF EXISTS Cars"
  db.exec "CREATE TABLE Cars(Id INT, Name TEXT, Price INT)"
  db.exec "INSERT INTO Cars VALUES (1, 'Audi', 52642), (2, 'Mercedes', 57127), (3, 'Skoda', 9000)"
  db.exec "INSERT INTO Cars VALUES (4, 'Volvo', 29000), (5, 'Bentley', 350000), (6, 'Citroen', 21000)"
  db.exec "INSERT INTO Cars VALUES (7, 'Hummer', 41400), (8, 'Volkswagen', 21600)"

  db.exec "SELECT * FROM sqlite_master"

  db.exec "SELECT * FROM Cars"
  db.exec "SELECT * FROM Cars WHERE Price > 29000"
  db.exec "SELECT Name FROM Cars WHERE Price > 29000"
