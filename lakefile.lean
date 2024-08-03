import Lake
open Lake DSL

def ffiL := "leansqlite3"
def ffiI := "leansqlite3.c"
def ffiO := "leansqlite3.o"

package sqlite where
  --moreLinkArgs := #["-lsqlite3"]
  moreLinkArgs := #["-L/usr/lib/x86_64-linux-gnu/", "-lsqlite3"]

lean_lib Sqlite

@[default_target] lean_exe test where
  root := `Test

target ffi.o pkg : FilePath := do
  let srcJob ← inputTextFile <| pkg.dir / ffiI
  let oFile := pkg.buildDir / "c" / ffiO
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  -- ffiI
  buildO oFile srcJob weakArgs #["-fPIC"] "c++" getLeanTrace

extern_lib leansqlite3 pkg := do
  let name := nameToStaticLib ffiL
  let ffiO ← fetch <| pkg.target ``ffi.o
  buildStaticLib (pkg.nativeLibDir / name) #[ffiO]

--extern_lib lol pkg := do
--  IO.print "nativeLibDir="
--  IO.println pkg.nativeLibDir
--  let filepath: FilePath := pkg.dir / "sqlite-amalgamation-3450200" / "libsqlite3.so"
--  IO.print "filepath="
--  IO.println filepath
--  return (return filepath)
