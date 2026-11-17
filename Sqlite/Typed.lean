import Sqlite.FFI

namespace Sqlite

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
  | INT => Int64
  | FLT => Float
  | TXT => String
  | BLB => String

inductive Val : Tpe → Type where
  | n : Val .NUL
  | i : Int64 → Val .INT
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
-- Cursor

def Cursor.getTpe (c: Cursor) (iCol: UInt32): IO Tpe :=
  return match (← c.getType iCol).toNat with
    | 1 => .INT
    | 2 => .FLT
    | 3 => .TXT
    | 4 => .BLB
    | 5 | _ => .NUL

def Cursor.readVal (c: Cursor) (iCol: UInt32): {α: Tpe} → IO (Val α)
  | .NUL => return .n
  | .INT => return .i (← c.readInt64 iCol)
  | .FLT => return .f (← c.readFloat iCol)
  | .TXT => return .t (← c.readString iCol)
  | .BLB => return .b (← c.readString iCol) -- TODO blob

def Cursor.readAny (c: Cursor) (iCol: UInt32): IO Any :=
  do let t := ← c.getTpe iCol; return ⟨ t, ← c.readVal iCol (α:=t) ⟩

def Cursor.readTyped (c: Cursor) (iCol: UInt32): (t: Tpe) → IO t.toType
  | .NUL => return ()
  | .INT => c.readInt64  iCol
  | .FLT => c.readFloat  iCol
  | .TXT => c.readString iCol
  | .BLB => c.readString iCol -- TODO blob

def Cursor.bindTyped (c: Cursor) (iCol: UInt32): (t: Tpe) → t.toType → IO Unit
  | .NUL, _ => c.bindNull   iCol
  | .INT, v => c.bindInt64  iCol v
  | .FLT, v => c.bindFloat  iCol v
  | .TXT, v => c.bindString iCol v
  | .BLB, v => c.bindString iCol v

def Cursor.exec : Cursor -> IO Unit := fun cur => do
  let count <- cur.reads
  let mut more <- cur.step
  let header: List (String × Tpe) <- (List.range count.toNat).mapM fun i =>
    return (<- cur.getName i.toUInt32, <- cur.getTpe i.toUInt32)
  IO.print "  "
  IO.println <| header
  while more do
    IO.print "  "
    IO.println <| <- header.zipIdx.mapM fun (_, i) => do
       let tmp <- cur.readAny i.toUInt32
       return s!"{tmp}"
    more <- cur.step
  return ()

def Db.exec : Db -> String -> IO Unit := fun db stmt => do
  IO.println s!"> {stmt}"
  let cur <- db.prep stmt
  cur.exec

def Cursor.bind (c: Cursor) (xs: List Any): IO Unit := do
  --let max ← c.binds
  let mut iCol := 1
  for x in xs do
    match x with
      | ⟨_, .n  ⟩ => c.bindNull   iCol
      | ⟨_, .i v⟩ => c.bindInt64  iCol v
      | ⟨_, .f v⟩ => c.bindFloat  iCol v
      | ⟨_, .t v⟩ => c.bindString iCol v
      | ⟨_, .b v⟩ => c.bindString iCol v
    iCol := iCol + 1
  let (false) <- c.step | throw (IO.userError "bind not done")
  c.boot -- reset

-------------------------------------------------------------------------------
-- Signature and Table

def Sig : Type := List (String × Tpe)
abbrev Sig.toType : Sig → Type
  | []    => Unit
  | x::xs => Prod x.2.toType (Sig.toType xs)
def Sig.toQuery (xs: Sig): String :=
  ", ".intercalate (xs.map fun x => x.1 ++ " " ++ x.2.toQuery)

-- The private constructors ensure a `Tab s` / `ReadCursor s` / `WriteCursor s`
-- can only be obtained via `getOrCreateTable` / `prepSelect` / `prepInsert`,
-- so `s` always matches the actual table.
structure Tab (s: Sig): Type where
  private mk ::
  db   : Db
  name : String

structure ReadCursor (s: Sig) where
  private mk ::
  cur : Cursor

structure WriteCursor (s: Sig) where
  private mk ::
  cur : Cursor

def Db.getOrCreateTable (db: Db) (name: String) (sig: Sig): IO (Tab sig) := do
  db.exec s!"CREATE TABLE IF NOT EXISTS {name}({sig.toQuery})"
  -- the table may already exist with a different schema
  let c <- db.prep s!"PRAGMA table_info({name})"
  let mut cols: List (String × String) := []
  while (<- c.step) do
    cols := cols ++ [(<- c.readString 1, <- c.readString 2)]
  let want := sig.map fun x => (x.1, x.2.toQuery)
  unless cols == want do
    throw <| IO.userError s!"table {name} has columns {cols}, expected {want}"
  return ⟨db, name⟩

def Tab.prepInsert (tab: Tab s): IO (WriteCursor s) := do
  let list := ", ".intercalate (List.range s.length |>.map fun _ => "?")
  return ⟨<- tab.db.prep s!"INSERT INTO {tab.name} VALUES ({list})"⟩
def Tab.prepSelect (tab: Tab s): IO (ReadCursor s) := do
  let s := s!"SELECT * FROM {tab.name}"
  IO.println s!"> {s}"
  return ⟨<- tab.db.prep s⟩

private def bindRow (c: Cursor) (iCol: UInt32): (s: Sig) → s.toType → IO Unit
  | [], () => return ()
  | (_, t)::ss, (v, vs) => do
    c.bindTyped iCol t v
    bindRow c (iCol+1) ss vs

private def readRow (c: Cursor) (iCol: UInt32): (s: Sig) → IO s.toType
  | [] => return ()
  | (_, t)::ss => return (<- c.readTyped iCol t, <- readRow c (iCol+1) ss)

def WriteCursor.write (c: WriteCursor s) (vs: s.toType): IO Unit :=
  try
    bindRow c.cur 1 s vs
    let (false) <- c.cur.step | throw (IO.userError "bind not done")
  finally
    -- reset even if bind/step failed; reset repeats step's error, so ignore it
    try c.cur.boot catch _ => pure ()

def ReadCursor.read (c: ReadCursor s): IO (Option s.toType) := do
  if (<- c.cur.step) then return some (<- readRow c.cur 0 s) else return none

def ReadCursor.readAll (c: ReadCursor s): IO (Array s.toType) := do
  let mut rows := #[]
  while true do
    match <- c.read with
      | some row => rows := rows.push row
      | none     => break
  return rows
