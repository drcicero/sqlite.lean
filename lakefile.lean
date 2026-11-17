import Lake
open Lake DSL

def ffiL := "leansqlite3"
def ffiI := "leansqlite3.c"
def ffiO := "leansqlite3.o"

package sqlite where
  --moreLinkArgs := #["-L.lake/build/lib", "-lsqlite3"]
  moreLinkArgs := #["/usr/lib/x86_64-linux-gnu/libsqlite3.so", "-Wl,--allow-shlib-undefined"]

lean_lib Sqlite

@[default_target] lean_exe test where
  root := `Test

target ffi.o pkg : System.FilePath := do
  let srcJob ← inputTextFile <| pkg.dir / ffiI
  let oFile := pkg.buildDir / "c" / ffiO
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  -- ffiI
  -- #["-I", (← IO.getEnv "C_INCLUDE_PATH").getD ""]
  buildO oFile srcJob weakArgs #["-fPIC"] "c++" getLeanTrace

extern_lib leansqlite3 pkg := do
  let name := nameToStaticLib ffiL
  let ffiO ← ffi.o.fetch
  buildStaticLib (pkg.staticLibDir / name) #[ffiO]

--extern_lib lol pkg := do
--  IO.print "nativeLibDir="
--  IO.println pkg.staticLibDir
--  let filepath: FilePath := pkg.dir / "sqlite-amalgamation-3450200" / "libsqlite3.so"
--  IO.print "filepath="
--  IO.println filepath
--  return (return filepath)
