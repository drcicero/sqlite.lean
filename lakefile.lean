import Lake
open Lake DSL

package sqlite where
  moreLinkArgs := #["-L", "/usr/lib/x86_64-linux-gnu/", "-lsqlite3"]

lean_lib Sqlite

@[default_target] lean_exe test where
  root := `Test

target lean4sqlite3.o pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "lean4sqlite3.o"
  let srcJob ← inputFile <| pkg.dir / "lean4sqlite3.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO "ffi.cpp" oFile srcJob weakArgs #["-fPIC"] "c++" getLeanTrace

extern_lib liblean4sqlite3 pkg := do
  let name := nameToStaticLib "lean4sqlite3"
  let ffiO ← fetch <| pkg.target ``lean4sqlite3.o
  buildStaticLib (pkg.nativeLibDir / name) #[ffiO]
