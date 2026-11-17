#include <lean/lean.h>
#include <sqlite3.h>
#include <stdio.h>

#define internal inline static
#define external extern "C"
#define l_arg lean_obj_arg
#define b_l_arg b_lean_obj_arg
#define l_res lean_obj_res

///////////////////////////////////////////////////////////////////////////////
// sqlite3 class

static lean_external_class* g_sqlite3_external_class = NULL;
internal void lean_sqlite3_finalizer(void* db) {
    // close_v2 defers the close until all statements are finalized
    sqlite3_close_v2((sqlite3*) db);
}
internal void lean_sqlite3_foreach(void* mod, b_l_arg fn) {
    // intentionally left blank
}
internal lean_object* lean_sqlite3_box(sqlite3* db) {
    return lean_alloc_external(g_sqlite3_external_class, db);
}
internal sqlite3* lean_sqlite3_unbox(b_l_arg db) {
    return (sqlite3*) (lean_get_external_data(db));
}

///////////////////////////////////////////////////////////////////////////////
// sqlite3_stmt class

static lean_external_class* g_sqlite3_stmt_external_class = NULL;
internal void lean_sqlite3_stmt_finalizer(void* stmt) {
    sqlite3_finalize((sqlite3_stmt*) stmt);
}
internal void lean_sqlite3_stmt_foreach(void* mod, b_l_arg fn) {
    // intentionally left blank
}
internal lean_object* lean_sqlite3_stmt_box(sqlite3_stmt* stmt) {
    return lean_alloc_external(g_sqlite3_stmt_external_class, stmt);
}
internal sqlite3_stmt* lean_sqlite3_stmt_unbox(b_l_arg stmt) {
    return (sqlite3_stmt*) (lean_get_external_data(stmt));
}

external l_res lean_sqlite3_initialize() {
    g_sqlite3_external_class = lean_register_external_class(
        lean_sqlite3_finalizer,
        lean_sqlite3_foreach);
    g_sqlite3_stmt_external_class = lean_register_external_class(
        lean_sqlite3_stmt_finalizer,
        lean_sqlite3_stmt_foreach);
    return lean_io_result_mk_ok(lean_box(0));
}

///////////////////////////////////////////////////////////////////////////////
// functions
// tutorial https://zetcode.com/db/sqlitec/

internal l_res lean_sqlite3_error(const char *what, int rc, const char *msg) {
    char buf[1024];
    snprintf(buf, sizeof buf, "sqlite %s error %d: %s", what, rc, msg);
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(buf)));
}

#define SQLITE_ASSERT(term, msg, stmt) do { \
    int rc = term; \
    if (rc != SQLITE_OK) \
      return lean_sqlite3_error(msg, rc, sqlite3_errmsg(sqlite3_db_handle(stmt))); \
  } while (0)

#define UNIT lean_io_result_mk_ok(lean_box(0))

external l_res lean_sqlite3_version() {
    return lean_io_result_mk_ok(lean_mk_string(sqlite3_libversion()));
}
external l_res lean_sqlite3_open(b_l_arg filename) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open(lean_string_cstr(filename), &db);
    if (rc != SQLITE_OK) {
        l_res err = lean_sqlite3_error("open", rc, db ? sqlite3_errmsg(db) : sqlite3_errstr(rc));
        sqlite3_close(db);
        return err;
    }
    return lean_io_result_mk_ok(lean_sqlite3_box(db));
}
external l_res lean_sqlite3_prep(b_l_arg db_l, b_l_arg stmt_l) {
    sqlite3 *db = lean_sqlite3_unbox(db_l);
    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db, lean_string_cstr(stmt_l), -1, &stmt, NULL);
    if (rc != SQLITE_OK) return lean_sqlite3_error("prep", rc, sqlite3_errmsg(db));
    // NULL stmt means the input was empty or only a comment
    if (stmt == NULL) return lean_sqlite3_error("prep", rc, "empty statement");
    return lean_io_result_mk_ok(lean_sqlite3_stmt_box(stmt));
}
external l_res lean_sqlite3_bind_num(b_l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint32(sqlite3_bind_parameter_count(stmt)));
}
external l_res lean_sqlite3_read_num(b_l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint32(sqlite3_column_count(stmt)));
}
external l_res lean_sqlite3_step(b_l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    int rc = sqlite3_step(stmt);
    if (rc == SQLITE_DONE) return lean_io_result_mk_ok(lean_box(0));
    if (rc == SQLITE_ROW)  return lean_io_result_mk_ok(lean_box(1));
    return lean_sqlite3_error("step", rc, sqlite3_errmsg(sqlite3_db_handle(stmt)));
}
external l_res lean_sqlite3_boot(b_l_arg stmt_l) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    SQLITE_ASSERT(sqlite3_reset(stmt), "boot", stmt);
    return UNIT;
}


external l_res lean_sqlite3_get_type(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint32(sqlite3_column_type(stmt, iCol)));
}
external l_res lean_sqlite3_get_size(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint32(sqlite3_column_bytes(stmt, iCol)));
}
external l_res lean_sqlite3_get_name(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    const char *res = sqlite3_column_name(stmt, iCol);
    return lean_io_result_mk_ok(lean_mk_string(res ? res : ""));
}


external l_res lean_sqlite3_read_i32(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint32(sqlite3_column_int(stmt, iCol)));
}
external l_res lean_sqlite3_read_i64(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_uint64(sqlite3_column_int64(stmt, iCol)));
}
external l_res lean_sqlite3_read_dbl(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    return lean_io_result_mk_ok(lean_box_float(sqlite3_column_double(stmt, iCol)));
}
external l_res lean_sqlite3_read_txt(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    // column_text must be called before column_bytes; NULL columns give NULL
    const char *res = (const char*) sqlite3_column_text(stmt, iCol);
    if (res == NULL) return lean_io_result_mk_ok(lean_mk_string(""));
    size_t len = sqlite3_column_bytes(stmt, iCol);
    return lean_io_result_mk_ok(lean_mk_string_from_bytes(res, len));
}


external l_res lean_sqlite3_bind_i32(b_l_arg stmt_l, uint32_t iCol, uint32_t v) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    SQLITE_ASSERT(sqlite3_bind_int(stmt, iCol, v), "bind i32", stmt);
    return UNIT;
}
external l_res lean_sqlite3_bind_i64(b_l_arg stmt_l, uint32_t iCol, uint64_t v) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    SQLITE_ASSERT(sqlite3_bind_int64(stmt, iCol, v), "bind i64", stmt);
    return UNIT;
}
external l_res lean_sqlite3_bind_dbl(b_l_arg stmt_l, uint32_t iCol, double v) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    SQLITE_ASSERT(sqlite3_bind_double(stmt, iCol, v), "bind double", stmt);
    return UNIT;
}
external l_res lean_sqlite3_bind_txt(b_l_arg stmt_l, uint32_t iCol, b_l_arg v) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    // TRANSIENT: sqlite copies the string, since the Lean string may be freed before step
    SQLITE_ASSERT(sqlite3_bind_text(stmt, iCol, lean_string_cstr(v), lean_string_size(v) - 1, SQLITE_TRANSIENT), "bind txt", stmt);
    return UNIT;
}
external l_res lean_sqlite3_bind_nll(b_l_arg stmt_l, uint32_t iCol) {
    sqlite3_stmt *stmt = lean_sqlite3_stmt_unbox(stmt_l);
    SQLITE_ASSERT(sqlite3_bind_null(stmt, iCol), "bind null", stmt);
    return UNIT;
}
