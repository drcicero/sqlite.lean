import Sqlite

inductive Tpe where
  | NUL | INT | FLT | TXT | BLB
deriving Repr, Inhabited
def Tpe.toString (t: Tpe): String := (reprPrec t 0).pretty
instance: ToString Tpe where toString := Tpe.toString

inductive Val : Tpe → Type where
  | n : Val .NUL
  | i : UInt32 → Val .INT
  | f : Float → Val .FLT
  | t : String → Val .TXT
  | b : String → Val .BLB
deriving Repr
def Val.toString (t: Val α): String := (reprPrec t 0).pretty
instance: ToString (Val α) where toString := Val.toString

def Any := (t: Tpe) × Val t
def Any.toString : Any → String := fun a => a.2.toString
instance: ToString Any where toString := Any.toString

def Sqlite.Cursor.getTpe (c: Sqlite.Cursor) (iCol: UInt32): IO Tpe :=
  return match (← c.getType iCol).val.1 with
    | 1 => .INT
    | 2 => .FLT
    | 3 => .TXT
    | 4 => .BLB
    | 5 | _ => .NUL

def Sqlite.Cursor.readVal (c: Sqlite.Cursor) (iCol: UInt32): {α: Tpe} → IO (Val α)
  | .NUL => return .n
  | .INT => return .i (← c.readUInt32 iCol)
  | .FLT => return .f (← c.readFloat iCol)
  | .TXT => return .t (← c.readString iCol)
  | .BLB => return .b (← c.readString iCol) -- TODO blob

def Sqlite.Cursor.readAny (c: Sqlite.Cursor) (iCol: UInt32): IO Any :=
  do let t := ← c.getTpe iCol; return ⟨ t, ← c.readVal iCol (α:=t) ⟩

def Sqlite.Db.exec : Sqlite.Db -> String -> IO PUnit := fun db stmt => do
  IO.println s!"> {stmt}"
  let cur <- db.prepare stmt
  let mut ok <- cur.step
  let count <- cur.cols
  let header: List (String × Tpe) <- (List.range count.toNat).mapM fun i =>
    return (<- cur.getName i.toUInt32, <- cur.getTpe i.toUInt32)
  IO.print "  "
  IO.println <| header
  while ok == 100 do
    IO.print "  "
    --IO.println <| <- header.enum.mapM fun (i, _) => return s!"{<- cur.readString i}"
    IO.println <| <- header.enum.mapM fun (i, n, α) => do
       let tmp <- cur.readAny i.toUInt32
       return s!"{tmp}"
    ok <- cur.step
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
