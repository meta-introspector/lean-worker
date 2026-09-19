/-
  RequestProject.Proxy.Interop

  Shared test vectors that pin the Lean model and the runtime wrapper together.

  The encoding and the hash below are checked here by the Lean kernel, and the
  identical vectors are asserted by `proxy/test_interop.py` against the Python
  implementation used by the real interceptor and by the dashboard verifier.
  If either side ever drifts, one of the two checks fails.
-/
import RequestProject.Proxy.Concrete

set_option maxRecDepth 10000

namespace Proxy
namespace Interop

/-- A sample receipt body: an allowed 128-byte read at the head of the chain. -/
def sampleBody : ReceiptBody :=
  { index    := 0
  , monitor  := "sandbox-proxy"
  , caller   := "agent-A"
  , seq      := 1
  , call     := ⟨.read, .file "/workspace/data.txt", 128⟩
  , decision := .allowed
  , outcome  := some (.ok 128 7)
  , prevHash := 0 }

example : encodeBody sampleBody =
    "0|sandbox-proxy|agent-A|1|read|file:/workspace/data.txt|128|allow|ok:128:7|0" := by
  decide +kernel

example : hashString "0|17|abc" = 1321732947816318877 := by decide +kernel

example : fnvHasher.hash 0 sampleBody = 6012787140634071986 := by decide +kernel

/-- A denied spawn, to pin the denial encoding as well. -/
def deniedBody : ReceiptBody :=
  { index    := 3
  , monitor  := "sandbox-proxy"
  , caller   := "agent-A"
  , seq      := 4
  , call     := ⟨.spawn, .proc "curl", 0⟩
  , decision := .denied "forbidden by policy"
  , outcome  := none
  , prevHash := 42 }

example : encodeBody deniedBody =
    "3|sandbox-proxy|agent-A|4|spawn|proc:curl|0|deny:forbidden by policy|-|42" := by
  decide +kernel

end Interop
end Proxy
