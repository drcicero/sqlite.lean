namespace Sqlite

opaque DbPointed : NonemptyType
def Db : Type := DbPointed.type
instance : Nonempty Db := DbPointed.property

opaque CursorPointed : NonemptyType
def Cursor : Type := CursorPointed.type
instance : Nonempty Cursor := CursorPointed.property

@[extern "lean_sqlite3_version"]  opaque version : IO String
@[extern "lean_sqlite3_open"]     opaque mk (filename: String): IO Db
@[extern "lean_sqlite3_prep"]     opaque Db.prep (db: Db) (stmt: String) : IO Cursor
@[extern "lean_sqlite3_step"]     opaque Cursor.step (Cursor: Cursor) : IO UInt32
@[extern "lean_sqlite3_boot"]     opaque Cursor.boot (Cursor: Cursor) : IO UInt32

@[extern "lean_sqlite3_bind_num"] opaque Cursor.binds (Cursor: Cursor): IO UInt32
@[extern "lean_sqlite3_bind_i32"] opaque Cursor.bindUInt32 (Cursor: Cursor) (iCol: UInt32) (v: UInt32): IO UInt32
@[extern "lean_sqlite3_bind_i64"] opaque Cursor.bindUInt64 (Cursor: Cursor) (iCol: UInt32) (v: UInt64): IO UInt32
@[extern "lean_sqlite3_bind_dbl"] opaque Cursor.bindFloat  (Cursor: Cursor) (iCol: UInt32) (v: Float):  IO UInt32
@[extern "lean_sqlite3_bind_txt"] opaque Cursor.bindString (Cursor: Cursor) (iCol: UInt32) (v: String): IO UInt32
@[extern "lean_sqlite3_bind_nll"] opaque Cursor.bindNull   (Cursor: Cursor) (iCol: UInt32): IO UInt32

@[extern "lean_sqlite3_read_num"] opaque Cursor.reads (Cursor: Cursor): IO UInt32
@[extern "lean_sqlite3_get_name"] opaque Cursor.getName    (Cursor: Cursor) (iCol: UInt32): IO String
@[extern "lean_sqlite3_get_type"] opaque Cursor.getType    (Cursor: Cursor) (iCol: UInt32): IO UInt32
@[extern "lean_sqlite3_get_size"] opaque Cursor.getSize    (Cursor: Cursor) (iCol: UInt32): IO UInt32
@[extern "lean_sqlite3_read_i32"] opaque Cursor.readUInt32 (Cursor: Cursor) (iCol: UInt32): IO UInt32
@[extern "lean_sqlite3_read_i64"] opaque Cursor.readUInt64 (Cursor: Cursor) (iCol: UInt32): IO UInt64
@[extern "lean_sqlite3_read_dbl"] opaque Cursor.readFloat  (Cursor: Cursor) (iCol: UInt32): IO Float
@[extern "lean_sqlite3_read_txt"] opaque Cursor.readString (Cursor: Cursor) (iCol: UInt32): IO String
