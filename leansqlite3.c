#include <lean/lean.h>
#include <sqlite3.h>
#include <stdio.h>

#define internal inline static
#define external extern "C"
#define l_arg lean_obj_arg
#define l_res lean_obj_res

///////////////////////////////////////////////////////////////////////////////
// sqlite3 class

static lean_external_class* g_sqlite3_external_class = NULL;
internal void lean_sqlite3_finalizer(void* db) {
    sqlite3* db2 = (sqlite3*) db;
    sqlite3_close(db2);
}
internal void lean_sqlite3_foreach(void* mod, l_arg fn) {
    // intentionally left blank
}
external l_res lean_sqlite3_initialize() {
    g_sqlite3_external_class = lean_register_external_class(
        lean_sqlite3_finalizer,
        lean_sqlite3_foreach);
    return lean_io_result_mk_ok(lean_box(0));
}
internal lean_object* lean_sqlite3_box(sqlite3* db) {
    return lean_alloc_external(g_sqlite3_external_class, db);
}
internal sqlite3* lean_sqlite3_unbox(lean_object* db) {
    return (sqlite3*) (lean_get_external_data(db));
}

///////////////////////////////////////////////////////////////////////////////
// sqlite3_stmt class

static lean_external_class* g_sqlite3_stmt_external_class = NULL;
internal void lean_sqlite3_stmt_finalizer(void* stmt) {
    sqlite3_stmt* stmt2 = (sqlite3_stmt*) stmt;
    sqlite3_finalize(stmt2);
}
internal void lean_sqlite3_stmt_foreach(void* mod, l_arg fn) {
    // intentionally left blank
}
external l_res lean_sqlite3_stmt_initialize() {
    g_sqlite3_stmt_external_class = lean_register_external_class(
        lean_sqlite3_stmt_finalizer,
        lean_sqlite3_stmt_foreach);
    return lean_io_result_mk_ok(lean_box(0));
}
internal lean_object* lean_sqlite3_stmt_box(sqlite3_stmt* db) {
    return lean_alloc_external(g_sqlite3_stmt_external_class, db);
}
internal sqlite3_stmt* lean_sqlite3_stmt_unbox(lean_object* db) {
    return (sqlite3_stmt*) (lean_get_external_data(db));
}

///////////////////////////////////////////////////////////////////////////////
// functions
// tutorial https://zetcode.com/db/sqlitec/

external l_res lean_sqlite3_version() {
    return lean_io_result_mk_ok(lean_mk_string(sqlite3_libversion()));
}
external l_res lean_sqlite3_open(const char *filename) {
    sqlite3 *db;
    int res = sqlite3_open(filename, &db);
    //fprintf(stderr, "db ptr %p\n", db);
    if (res != SQLITE_OK) {
      fprintf(stderr, "Cannot open database: %s\n", sqlite3_errmsg(db));
      sqlite3_close(db);
      return lean_io_result_mk_error(lean_sqlite3_box(db));
    }
    return lean_io_result_mk_ok(lean_sqlite3_box(db));
}
external l_res lean_sqlite3_prepare(l_arg db_l, l_arg stmt_l) {
    sqlite3 *db = lean_sqlite3_unbox(db_l);
    //fprintf(stderr, "db ptr %p\n", db);
    const char *stmt_s = lean_string_cstr(stmt_l);
    //fprintf(stderr, "stmt in %s\n", stmt_s);
    sqlite3_stmt *stmt;
    int res = sqlite3_prepare_v2(db, stmt_s, -1, &stmt, 0);
    //fprintf(stderr, "stmt ptr %p\n", stmt);
    //fprintf(stderr, "err %d\n", res);
    if (res != SQLITE_OK) {
      fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
      sqlite3_close(db);
      return lean_io_result_mk_error(lean_sqlite3_stmt_box(stmt));
    }
    return lean_io_result_mk_ok(lean_sqlite3_stmt_box(stmt));
}
external l_res lean_sqlite3_bind_num(l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int res = sqlite3_bind_parameter_count(stmt);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_read_num(l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int res = sqlite3_column_count(stmt);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_step(l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    //fprintf(stderr, "stmt ptr %p\n", stmt);
    int res = sqlite3_step(stmt);
    if (res == SQLITE_ROW || res == SQLITE_DONE) {
      return lean_io_result_mk_ok(lean_box(res));
    } else {
      fprintf(stderr, "fail %d\n", res);
      return lean_io_result_mk_error(lean_box(res));
    }
}


external l_res lean_sqlite3_get_type(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int res = sqlite3_column_type(stmt, iCol);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_get_size(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int res = sqlite3_column_bytes(stmt, iCol);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_get_name(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    const char *res = sqlite3_column_name(stmt, iCol);
    return lean_io_result_mk_ok(lean_mk_string(res));
}


external l_res lean_sqlite3_read_i32(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int res = sqlite3_column_int(stmt, iCol);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_read_i64(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    sqlite3_int64 res = sqlite3_column_int64(stmt, iCol);
    return lean_io_result_mk_ok(lean_box(res)); // TODO wrong?
}
external l_res lean_sqlite3_read_dbl(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    double res = sqlite3_column_double(stmt, iCol);
    return lean_io_result_mk_ok(lean_box(res));
}
external l_res lean_sqlite3_read_txt(l_arg stmt_l, int iCol) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    const unsigned char *res = sqlite3_column_text(stmt, iCol);
    return lean_io_result_mk_ok(lean_mk_string((const char*) res));
    // TODO make copy of bytes ?
    //size_t len = sqlite3_column_bytes(stmt, iCol);
    //return lean_io_result_mk_ok(lean_mk_string_from_bytes((const char*) res, len));
}


external l_res lean_sqlite3_bind_i32(l_arg stmt_l, int iCol, int v) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int ok = sqlite3_bind_int(stmt, iCol, v);
    return lean_io_result_mk_ok(lean_box(ok));
}
external l_res lean_sqlite3_bind_i64(l_arg stmt_l, int iCol, long v) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int ok = sqlite3_bind_int64(stmt, iCol, v);
    return lean_io_result_mk_ok(lean_box(ok));
}
external l_res lean_sqlite3_bind_dbl(l_arg stmt_l, int iCol, float v) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int ok = sqlite3_bind_double(stmt, iCol, v);
    return lean_io_result_mk_ok(lean_box(ok));
}
external l_res lean_sqlite3_bind_txt(l_arg stmt_l, int iCol, const char* v) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int ok = sqlite3_bind_text(stmt, iCol, v, -1, NULL); // TODO instead of null pass a memory free / destructor
    return lean_io_result_mk_ok(lean_box(ok));
}
external l_res lean_sqlite3_bind_nll(l_arg stmt_l, int iCol, const char* v) {
    //int iCol = (iCol-1)/2; // unsigned -> signed
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int ok = sqlite3_bind_text(stmt, iCol, NULL, 0, NULL);
    return lean_io_result_mk_ok(lean_box(ok));
}
