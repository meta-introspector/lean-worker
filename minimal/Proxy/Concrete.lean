/-
  RequestProject.Proxy.Concrete

  A concrete instance of the abstract chain: a canonical text encoding of a
  receipt body and a 64-bit FNV-1a-style hash over its Unicode code points.

  This is the encoding the runtime wrapper (`proxy/logging_proxy.py`) and the
  dashboard verifier (`dashboard/app.js`) implement byte for byte, so a receipt
  produced by the real interceptor is hashed exactly as the model hashes it, and
  the dashboard re-verifies exactly the chain the model specifies.

  The hash is a real, small, non-cryptographic function, so it is *not* claimed
  to be collision free: the theorems of `Proxy.Core` that need that property
  take it as an explicit hypothesis.  Everything checked here by computation is
  checked on the concrete encoding.
-/
import Proxy.Dashboard

namespace Proxy

/-- `2 ^ 64`. -/
def twoPow64 : Nat := 18446744073709551616

/-- 64-bit FNV-1a, run over the code points of a string.  (The wrapper and the
    dashboard iterate code points too, so all three agree exactly.) -/
def hashString (s : String) : Nat :=
  s.toList.foldl (fun h c => (Nat.xor h c.toNat * 1099511628211) % twoPow64)
    14695981039346656037

/-! ### Canonical encoding -/

def encodeOp : Op → String
  | .read => "read" | .write => "write" | .stat => "stat"
  | .connect => "connect" | .send => "send" | .recv => "recv"
  | .spawn => "spawn"

def encodeResource : Resource → String
  | .file path   => "file:" ++ path
  | .net host pt => "net:" ++ host ++ ":" ++ toString pt
  | .proc exe    => "proc:" ++ exe

def encodeCall (c : Syscall) : String :=
  encodeOp c.op ++ "|" ++ encodeResource c.resource ++ "|" ++ toString c.nbytes

def encodeDecision : Decision → String
  | .allowed       => "allow"
  | .denied reason => "deny:" ++ reason

def encodeOutcome : Option Outcome → String
  | none                  => "-"
  | some (.ok bytes dig)  => "ok:" ++ toString bytes ++ ":" ++ toString dig
  | some (.error code)    => "err:" ++ toString code

/-- The canonical line that gets hashed and signed. -/
def encodeBody (b : ReceiptBody) : String :=
  String.intercalate "|"
    [ toString b.index, b.monitor, b.caller, toString b.seq
    , encodeCall b.call, encodeDecision b.decision, encodeOutcome b.outcome
    , toString b.prevHash ]

/-- The concrete hasher used by the runtime wrapper and the dashboard. -/
def fnvHasher : Hasher :=
  { hash := fun prev b => hashString (toString prev ++ "|" ++ encodeBody b) }

/-- The genesis value of the concrete chain. -/
def genesis0 : Nat := 0

end Proxy
