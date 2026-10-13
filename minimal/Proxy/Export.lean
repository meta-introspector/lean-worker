/-
  RequestProject.Proxy.Export

  Emit the journal of the modelled run (`Proxy.Demo`) in exactly the JSON-lines
  shape the runtime wrapper writes, so the dashboard can display, and re-verify,
  the model's own trace next to the live one.

  The `sig` field of an exported receipt is the string `"model"`: in Lean the
  signature is the idealised tag of `Protocol.Core` (holding the key *is* the
  ability to tag), whereas the wrapper instantiates it with HMAC-SHA256.  The
  chain hashes, however, are the real ones, so the exported file verifies under
  exactly the same chain rule as the live journal.
-/
import Proxy.Example

namespace Proxy
namespace Export

/-- Escape the characters JSON forbids in a string literal. -/
def jsonEscape (s : String) : String :=
  s.foldl (fun acc c =>
    acc ++ (match c with
            | '"'  => "\\\""
            | '\\' => "\\\\"
            | '\n' => "\\n"
            | '\t' => "\\t"
            | _    => String.singleton c)) ""

def quote (s : String) : String := "\"" ++ jsonEscape s ++ "\""

def resourceJson : Resource → String
  | .file path   => "{\"kind\":\"file\",\"path\":" ++ quote path ++ "}"
  | .net host pt =>
      "{\"kind\":\"net\",\"host\":" ++ quote host ++ ",\"port\":" ++ toString pt ++ "}"
  | .proc exe    => "{\"kind\":\"proc\",\"exe\":" ++ quote exe ++ "}"

def callJson (c : Syscall) : String :=
  "{\"op\":" ++ quote (encodeOp c.op) ++
  ",\"resource\":" ++ resourceJson c.resource ++
  ",\"nbytes\":" ++ toString c.nbytes ++ "}"

/-- 64-bit values travel as decimal strings (they do not fit in a JSON double;
    see the note in `proxy/receipts.py`). -/
def bigNum (n : Nat) : String := quote (toString n)

def outcomeJson : Option Outcome → String
  | none                  => "null"
  | some (.ok bytes dig)  =>
      "{\"status\":\"ok\",\"bytes\":" ++ toString bytes ++ ",\"digest\":" ++ bigNum dig ++ "}"
  | some (.error code)    => "{\"status\":\"err\",\"code\":" ++ toString code ++ "}"

def bodyJson (b : ReceiptBody) : String :=
  let decision := match b.decision with | .allowed => "\"allow\"" | .denied _ => "\"deny\""
  let reason := match b.decision with
    | .allowed      => "null"
    | .denied r     => quote r
  "{\"index\":" ++ toString b.index ++
  ",\"monitor\":" ++ quote b.monitor ++
  ",\"caller\":" ++ quote b.caller ++
  ",\"seq\":" ++ toString b.seq ++
  ",\"call\":" ++ callJson b.call ++
  ",\"decision\":" ++ decision ++
  ",\"reason\":" ++ reason ++
  ",\"outcome\":" ++ outcomeJson b.outcome ++
  ",\"prev_hash\":" ++ bigNum b.prevHash ++ "}"

def receiptJson (r : Receipt) : String :=
  "{\"body\":" ++ bodyJson r.body ++
  ",\"hash\":" ++ bigNum r.hash ++
  ",\"sig\":\"model\"" ++
  ",\"line\":" ++ quote (encodeBody r.body) ++ "}"

/-- The whole journal, oldest first, one receipt per line. -/
def logJsonl (l : Log) : String :=
  String.intercalate "\n" (l.reverse.map receiptJson) ++ "\n"

/-- The journal of the modelled run in `Proxy.Demo`. -/
def demoJsonl : String := logJsonl Demo.proxyN.log

/-- Summary of the modelled run, in the same shape as the wrapper's meta file. -/
def demoMetaJson : String :=
  "{\"monitor\":" ++ quote Demo.proxy0.id ++
  ",\"genesis\":" ++ toString Demo.proxy0.genesis ++
  ",\"tip\":" ++ bigNum (tip Demo.proxy0.genesis Demo.proxyN.log) ++
  ",\"receipts\":" ++ toString Demo.proxyN.log.length ++
  ",\"bytes_moved\":" ++ toString Demo.dash.bytesMoved ++
  ",\"allowed\":" ++ toString Demo.dash.allowedCount ++
  ",\"denied\":" ++ toString Demo.dash.deniedCount ++
  ",\"source\":\"lean-model\"}\n"

end Export
end Proxy
