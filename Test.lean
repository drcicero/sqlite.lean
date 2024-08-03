import Sqlite

inductive Tpe where
  | NUL | INT | FLT | TXT | BLB
deriving Repr, Inhabited
def Tpe.toString (t: Tpe): String := (reprPrec t 0).pretty
instance: ToString Tpe where toString := Tpe.toString

def Tpe.toQuery : Tpe → String
  | NUL => "NULL"
  | INT => "INT"
  | FLT => "FLOAT"
  | TXT => "TEXT"
  | BLB => "BLOB"

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

instance : CoeOut (Val α) Any where coe a := ⟨α, a⟩

def Sqlite.Cursor.getTpe (c: Cursor) (iCol: UInt32): IO Tpe :=
  return match (← c.getType iCol).val.1 with
    | 1 => .INT
    | 2 => .FLT
    | 3 => .TXT
    | 4 => .BLB
    | 5 | _ => .NUL

def Sqlite.Cursor.readVal (c: Cursor) (iCol: UInt32): {α: Tpe} → IO (Val α)
  | .NUL => return .n
  | .INT => return .i (← c.readUInt32 iCol)
  | .FLT => return .f (← c.readFloat iCol)
  | .TXT => return .t (← c.readString iCol)
  | .BLB => return .b (← c.readString iCol) -- TODO blob

def Sqlite.Cursor.readAny (c: Cursor) (iCol: UInt32): IO Any :=
  do let t := ← c.getTpe iCol; return ⟨ t, ← c.readVal iCol (α:=t) ⟩

def Sqlite.Cursor.exec : Cursor -> IO PUnit := fun cur => do
  let count <- cur.reads
  let mut more <- cur.step
  let header: List (String × Tpe) <- (List.range count.toNat).mapM fun i =>
    return (<- cur.getName i.toUInt32, <- cur.getTpe i.toUInt32)
  IO.print "  "
  IO.println <| header
  while more do
    IO.print "  "
    --IO.println <| <- header.enum.mapM fun (i, _) => return s!"{<- cur.readString i.toUInt32}"
    IO.println <| <- header.enum.mapM fun (i, n, α) => do
       let tmp <- cur.readAny i.toUInt32
       return s!"{tmp}"
    more <- cur.step
  return ()

def Sqlite.Db.exec : Db -> String -> IO PUnit := fun db stmt => do
  IO.println s!"> {stmt}"
  let cur <- db.prep stmt
  cur.exec

-- def Sqlite.Db.createIfNotExists : Tab
-- def Sqlite.Db.insert : Db → IO Unit := _
-- def Sqlite.Db.select : Db → IO Unit := _

def Sqlite.Cursor.bind (c: Cursor) (xs: List Any): IO Unit := do
  --let max ← c.binds
  let mut iCol := 1
  for ⟨_, a⟩ in xs do
    match a with
      | .n   => c.bindNull   iCol
      | .i v => c.bindUInt32 iCol v
      | .f v => c.bindFloat  iCol v
      | .t v => c.bindString iCol v
      | .b v => c.bindString iCol v
    iCol := iCol + 1
  let (false) <- c.step | throw (IO.userError "bind not done")
  c.boot -- reset

structure Sig : Type where
  columns: List (String × Tpe)
def Sig.toQuery (xs: Sig): String :=
  ", ".intercalate (xs.columns.map fun x => x.1 ++ " " ++ x.2.toQuery)

structure Tab (s: Sig): Type where
  db   : Sqlite.Db
  name : String
  sig  : Sig

def Sqlite.Db.getOrCreateTable (db: Db) (name: String) (sig: Sig): IO (Tab sig) := do
  db.exec s!"CREATE TABLE IF NOT EXISTS {name}({sig.toQuery})"
  return { db := db, name := name, sig := sig }
def Tab.prepInsert (tab: Tab s): IO Sqlite.Cursor := do
  let list := ", ".intercalate (List.range tab.sig.columns.length |>.map fun i => "?")
  tab.db.prep s!"INSERT INTO {tab.name} VALUES ({list})"
def Tab.prepSelect (tab: Tab s): IO Sqlite.Cursor := do
  let s := s!"SELECT * FROM {tab.name}"
  IO.println s!"> {s}"
  tab.db.prep s

def main : IO Unit := do
  IO.println <| <- Sqlite.version

  let db <- Sqlite.mk ":memory:"
  db.exec "SELECT SQLITE_VERSION()"
  --db.exec "DROP TABLE IF EXISTS cars"

  let Car  := Sig.mk [("id", .INT), ("name", .TXT), ("price", .INT)]
  let cars <- db.getOrCreateTable "cars" Car
  let cur  <- cars.prepInsert
  cur.bind [Val.i 1, Val.t "Audi",       Val.i  52642]
  cur.bind [Val.i 2, Val.t "Mercedes",   Val.i  57127]
  cur.bind [Val.i 3, Val.t "Skoda",      Val.i   9000]
  cur.bind [Val.i 4, Val.t "Volvo",      Val.i  29000]
  cur.bind [Val.i 5, Val.t "Bentley",    Val.i 350000]
  cur.bind [Val.i 6, Val.t "Citroen",    Val.i  21000]
  cur.bind [Val.i 7, Val.t "Hummer",     Val.i  41400]
  cur.bind [Val.i 8, Val.t "Volkswagen", Val.i  21600]

  db.exec "SELECT * FROM sqlite_master"

  (<- cars.prepSelect).exec
  db.exec "SELECT * FROM cars WHERE Price > 29000"
  db.exec "SELECT name FROM cars WHERE Price > 29000"
