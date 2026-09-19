/-
  RequestProject.Protocol.Example

  A concrete two-peer network, used as a sanity check that the protocol
  definitions are not vacuous: the honest exchange really is accepted, and each
  protection really does bite.  Every claim here is closed by computation.
-/
import RequestProject.Protocol.Soundness

namespace P2P
namespace Example

/-- A toy back end: proof jobs succeed and are kernel-checked; executables exit
    with code 0. -/
def demoRuntime : Runtime where
  run := fun j _ =>
    match j with
    | .proveGoal _ _ _ => .proved ["propext", "Classical.choice", "Quot.sound"]
    | .checkProof _    => .proved []
    | .runExe _ _      => .exited 0 7
  kernelChecked := fun j _ =>
    match j with
    | .proveGoal _ _ _ => true
    | .checkProof _    => true
    | .runExe _ _      => true

/-- The prover node `alice`: admits `bob`, runs only the allow-listed
    `twin-checker` executable, and caps resource use. -/
def alice : Server where
  id := "alice"
  key := 11
  policy :=
    { admittedPeers  := ["bob"]
    , allowedExes    := ["twin-checker"]
    , allowExeCalls  := true
    , maxFuelPerCall := 1000
    , fuelBudget     := 10000 }
  clientKeys := [("bob", 42)]
  seen := []
  fuelUsed := 0

/-- The caller `bob`, provisioned for `alice`. -/
def bob : Client where
  id := "bob"
  callKeys := [("alice", 42)]
  verifyKeys := [("alice", 11)]
  nextNonce := 1

/-- An intruder that is not on alice's admission list. -/
def mallory : Client where
  id := "mallory"
  callKeys := [("alice", 42)]
  verifyKeys := [("alice", 11)]
  nextNonce := 1

def proofJob : Job := .proveGoal "RequestProject.Twin" "consistency_theorem" 990001

def exeJob : Job := .runExe "twin-checker" 4242

def forbiddenExeJob : Job := .runExe "rm-rf" 4242

/-- Bob's call for the proof job. -/
def bobProofCall : Option (Call × Client) := mkCall bob "alice" proofJob 100

/-- Honest exchange: alice serves the proof job and bob accepts the certificate. -/
theorem honest_proof_call_accepted :
    (match bobProofCall with
     | some (c, _) => accepts bob c (handle demoRuntime alice c).2
     | none => false) = true := by
  decide

/-- The certificate bob accepts says the kernel checked the result. -/
theorem honest_proof_call_kernel_checked :
    (match bobProofCall with
     | some (c, _) =>
       match (handle demoRuntime alice c).2 with
       | .certified cert _ => cert.kernelChecked
       | .rejected _ => false
     | none => false) = true := by
  decide

/-- Replay: presenting the very same call again is refused. -/
theorem honest_proof_call_replay_refused :
    (match bobProofCall with
     | some (c, _) =>
       let s' := (handle demoRuntime alice c).1
       accepts bob c (handle demoRuntime s' c).2
     | none => true) = false := by
  decide

/-- The allow-listed executable is served. -/
theorem allowed_exe_call_accepted :
    (match mkCall bob "alice" exeJob 100 with
     | some (c, _) => accepts bob c (handle demoRuntime alice c).2
     | none => false) = true := by
  decide

/-- An executable outside the allow list is never run. -/
theorem forbidden_exe_call_refused :
    (match mkCall bob "alice" forbiddenExeJob 100 with
     | some (c, _) => accepts bob c (handle demoRuntime alice c).2
     | none => true) = false := by
  decide

/-- A peer that is not admitted gets nothing, even with a valid shared key. -/
theorem unlisted_peer_gets_nothing :
    (match mkCall mallory "alice" proofJob 100 with
     | some (c, _) => accepts mallory c (handle demoRuntime alice c).2
     | none => true) = false := by
  decide

/-- Over-budget calls are refused. -/
theorem over_budget_call_refused :
    (match mkCall bob "alice" proofJob 5000 with
     | some (c, _) => accepts bob c (handle demoRuntime alice c).2
     | none => true) = false := by
  decide

/-- A forged certificate signed with the wrong key is not accepted. -/
theorem forged_certificate_refused :
    (match bobProofCall with
     | some (c, _) =>
       let fake : Certificate :=
         { server := "alice", client := "bob", nonce := c.body.nonce
         , job := c.body.job, outcome := .proved [], kernelChecked := true
         , fuelUsed := 0 }
       accepts bob c (.certified fake (macTag "alice" 99 fake))
     | none => true) = false := by
  decide

/-- Two peers answering the same job with the same outcome glue to `agreed`;
    a missing answer glues to `unknown`, never to `disagreed`. -/
theorem gluing_demo :
    glue (some { server := "alice", client := "bob", nonce := 1, job := proofJob
               , outcome := .proved [], kernelChecked := true, fuelUsed := 1 })
         (some { server := "carol", client := "bob", nonce := 2, job := proofJob
               , outcome := .proved [], kernelChecked := true, fuelUsed := 3 })
      = Gluing.agreed
    ∧ glue (some { server := "alice", client := "bob", nonce := 1, job := proofJob
                 , outcome := .proved [], kernelChecked := true, fuelUsed := 1 })
           none
      = Gluing.unknown := by
  decide

end Example
end P2P
