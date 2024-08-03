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

abbrev Tpe.toType : Tpe → Type
  | NUL => Unit
  | INT => UInt32
  | FLT => Float
  | TXT => String
  | BLB => String

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

-------------------------------------------------------------------------------
-- Sqlite

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

def Sqlite.Cursor.exec : Cursor -> IO Unit := fun cur => do
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

def Sqlite.Db.exec : Db -> String -> IO Unit := fun db stmt => do
  IO.println s!"> {stmt}"
  let cur <- db.prep stmt
  cur.exec

-------------------------------------------------------------------------------
-- Signature and Table

def Sig : Type := List (String × Tpe)
abbrev Sig.toType : Sig → Type
  | []    => Unit
  | x::xs => Prod x.2.toType (Sig.toType xs)
def Sig.toQuery (xs: Sig): String :=
  ", ".intercalate (xs.map fun x => x.1 ++ " " ++ x.2.toQuery)

structure Tab (s: Sig): Type where
  db   : Sqlite.Db
  name : String

abbrev ReadCursor (s: Sig) := Sqlite.Cursor
abbrev WriteCursor (s: Sig) := Sqlite.Cursor

def Sqlite.Db.getOrCreateTable (db: Db) (name: String) (sig: Sig): IO (Tab sig) := do
  db.exec s!"CREATE TABLE IF NOT EXISTS {name}({sig.toQuery})"
  return { db := db, name := name }
def Tab.prepInsert (tab: Tab s): IO (WriteCursor s) := do
  let list := ", ".intercalate (List.range s.length |>.map fun _ => "?")
  tab.db.prep s!"INSERT INTO {tab.name} VALUES ({list})"
def Tab.prepSelect (tab: Tab s): IO (ReadCursor s) := do
  let s := s!"SELECT * FROM {tab.name}"
  IO.println s!"> {s}"
  tab.db.prep s

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

def WriteCursor.write (c: WriteCursor s) (iCol: UInt32) (vs: s.toType): IO Unit := match s, vs with
  | ⟨_,a⟩::ss, (v, vs) => do
    match a with
      | .NUL => c.bindNull   iCol
      | .INT => c.bindUInt32 iCol v
      | .FLT => c.bindFloat  iCol v
      | .TXT => c.bindString iCol v
      | .BLB => c.bindString iCol v
    c.write (s:=ss) (iCol+1) vs
  | [], () => do
    let (false) <- c.step | throw (IO.userError "bind not done")
    c.boot -- reset

-------------------------------------------------------------------------------
-- main

def main : IO Unit := do
  IO.println <| <- Sqlite.version

  let db <- Sqlite.mk ":memory:"
  db.exec "SELECT SQLITE_VERSION()"
  --db.exec "DROP TABLE IF EXISTS cars"

  let Car: Sig := [("id", .INT), ("name", .TXT), ("price", .INT)]
  let cars <- db.getOrCreateTable "cars" Car
  let cur  <- cars.prepInsert
  cur.write 1 (1, "Audi",        52642, ())
  cur.write 1 (2, "Mercedes",    57127, ())
  cur.write 1 (3, "Skoda",        9000, ())
  cur.write 1 (4, "Volvo",       29000, ())
  cur.write 1 (5, "Bentley",    350000, ())
  cur.write 1 (6, "Citroen",     21000, ())
  cur.write 1 (7, "Hummer",      41400, ())
  cur.write 1 (8, "Volkswagen",  21600, ())

  db.exec "SELECT * FROM sqlite_master"

  (<- cars.prepSelect).exec
  db.exec "SELECT * FROM cars WHERE Price > 29000"
  db.exec "SELECT name FROM cars WHERE Price > 29000"
