import RequestProject.Tracker.Gokujo

/-!
# `gokujo`, the executable

The root `main` `lake` needs, kept out of `Gokujo.lean` so that the library can be
imported by other programs that have a `main` of their own.
-/

def main (argv : List String) : IO UInt32 := gokujoMain argv
