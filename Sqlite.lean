namespace Sqlite

opaque DbPointed : NonemptyType
def Db : Type := DbPointed.type
instance : Nonempty Db := DbPointed.property

opaque CursorPointed : NonemptyType
def Cursor : Type := CursorPointed.type
instance : Nonempty Cursor := CursorPointed.property

@[extern "lean_sqlite3_libversion"] opaque version : IO String
@[extern "lean_sqlite3_open"]       opaque mk (filename: String): IO Db
@[extern "lean_sqlite3_prepare"]    opaque Db.prepare (db: Db) (stmt: String) : IO Cursor
@[extern "lean_sqlite3_step"]       opaque Cursor.step (Cursor: Cursor) : IO UInt32

@[extern "lean_sqlite3_read_count"] opaque Cursor.cols       (Cursor: Cursor): IO UInt32
@[extern "lean_sqlite3_read_name"]  opaque Cursor.getName    (Cursor: Cursor) (iCol: Uint32): IO String
@[extern "lean_sqlite3_read_type"]  opaque Cursor.getType    (Cursor: Cursor) (iCol: Uint32): IO UInt32
@[extern "lean_sqlite3_read_size"]  opaque Cursor.getSize    (Cursor: Cursor) (iCol: Uint32): IO UInt32

@[extern "lean_sqlite3_read_int32"] opaque Cursor.readUInt32 (Cursor: Cursor) (iCol: Uint32): IO UInt32
@[extern "lean_sqlite3_read_int64"] opaque Cursor.readUInt64 (Cursor: Cursor) (iCol: Uint32): IO UInt64
@[extern "lean_sqlite3_read_dbl"]   opaque Cursor.readFloat  (Cursor: Cursor) (iCol: Uint32): IO Float
@[extern "lean_sqlite3_read_txt"]   opaque Cursor.readString (Cursor: Cursor) (iCol: Uint32): IO String
