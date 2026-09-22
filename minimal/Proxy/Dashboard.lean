/-
  RequestProject.Proxy.Dashboard

  The live view on top of the logging proxy.

  The dashboard has exactly one source of data: the receipt chain written by
  `Proxy.Monitor`.  Before anything is displayed the whole chain is re-verified
  — every link recomputed, every signature checked.  If verification fails the
  dashboard shows *nothing*; it never shows partial, unverified or synthesised
  data.  When it does show something, every row on screen is a receipt that is
  really in the log, and the counters on screen are computed from exactly those
  rows.

  The theorems here are the "only validated real data, with receipts" claim:

    * `view_rows_backed_by_receipts` — no row without a receipt;
    * `view_rows_signed` — every displayed row is signed by the monitor;
    * `view_hides_nothing` — and no receipt without a row;
    * `view_empty_on_tamper` — one altered byte and the dashboard goes dark;
    * `ledger_ok_runAll` / `view_bytes_within_budget` — the byte counter on
      screen is the real number of bytes the proxy let through, and it is
      within the configured budget.
-/
import Proxy.Monitor

namespace Proxy

open P2P (verifyTag)

/-- Re-verification of the journal: links recomputed and signatures checked. -/
def validated (H : Hasher) (genesis key : Nat) (l : Log) : Bool :=
  chainOk H genesis l && signedOk key l

/-- What the dashboard displays. -/
structure View where
  /-- Did the journal verify?  When `false` there is nothing to show. -/
  verified    : Bool
  /-- The published commitment to the history. -/
  tipHash     : Nat
  /-- One row per receipt, newest first. -/
  rows        : List ReceiptBody
  allowedCount : Nat
  deniedCount  : Nat
  bytesMoved   : Nat
  deriving Repr

/-- Bytes actually moved through the proxy, according to the receipts. -/
def allowedBytes : Log → Nat
  | []        => 0
  | r :: rest =>
      (if r.body.decision = .allowed then r.body.call.nbytes else 0) + allowedBytes rest

/-- Number of receipts that record an allowed call. -/
def allowedCount (l : Log) : Nat :=
  (l.filter (fun r => r.body.decision == .allowed)).length

/-- Number of receipts that record a denial. -/
def deniedCount (l : Log) : Nat :=
  (l.filter (fun r => r.body.decision != .allowed)).length

/-- Render the dashboard.  Unverified journal ⇒ empty dashboard. -/
def view (H : Hasher) (genesis key : Nat) (l : Log) : View :=
  if validated H genesis key l then
    { verified     := true
    , tipHash      := tip genesis l
    , rows         := l.map Receipt.body
    , allowedCount := allowedCount l
    , deniedCount  := deniedCount l
    , bytesMoved   := allowedBytes l }
  else
    { verified     := false
    , tipHash      := tip genesis l
    , rows         := []
    , allowedCount := 0
    , deniedCount  := 0
    , bytesMoved   := 0 }

/-- The dashboard of a running proxy. -/
def monitorView (H : Hasher) (m : Monitor) : View :=
  view H m.genesis m.key m.log

/-! ### Only real data -/

/-- Every row on screen is the body of a receipt that is really in the log. -/
theorem view_rows_backed_by_receipts (H : Hasher) (genesis key : Nat) (l : Log) :
    ∀ b ∈ (view H genesis key l).rows, ∃ r ∈ l, r.body = b := by
  intro b hb
  unfold view at hb
  by_cases hv : validated H genesis key l
  · simp only [hv, if_true, List.mem_map] at hb
    obtain ⟨r, hr, hrb⟩ := hb
    exact ⟨r, hr, hrb⟩
  · simp [hv] at hb

/-- Every row on screen carries the monitor's signature: rows are receipts, not
    reports. -/
theorem view_rows_signed (H : Hasher) (genesis key : Nat) (l : Log) :
    ∀ b ∈ (view H genesis key l).rows,
      ∃ r ∈ l, r.body = b ∧ verifyTag r.body.monitor key r.body r.sig = true := by
  intro b hb
  unfold view at hb
  by_cases hv : validated H genesis key l
  · simp only [hv, if_true, List.mem_map] at hb
    obtain ⟨r, hr, hrb⟩ := hb
    have hs : signedOk key l = true := by
      have hval := hv
      simp only [validated, Bool.and_eq_true] at hval
      exact hval.2
    refine ⟨r, hr, hrb, ?_⟩
    simp only [signedOk, List.all_eq_true] at hs
    exact hs r hr
  · simp [hv] at hb

/-- A displayed dashboard is showing a verified journal. -/
theorem view_verified_iff (H : Hasher) (genesis key : Nat) (l : Log) :
    (view H genesis key l).verified = true ↔ validated H genesis key l = true := by
  unfold view
  by_cases hv : validated H genesis key l <;> simp [hv]

/-- Tamper with the journal — edit, reorder, delete, or resign an entry so that
    a link or a signature no longer checks — and the dashboard goes dark rather
    than showing anything. -/
theorem view_empty_on_tamper (H : Hasher) (genesis key : Nat) (l : Log)
    (h : validated H genesis key l = false) :
    (view H genesis key l).rows = [] ∧
    (view H genesis key l).verified = false ∧
    (view H genesis key l).bytesMoved = 0 := by
  simp [view, h]

/-- And nothing is hidden either: when the journal verifies, every receipt in it
    has its row. -/
theorem view_hides_nothing (H : Hasher) (genesis key : Nat) (l : Log)
    (h : validated H genesis key l = true) :
    (view H genesis key l).rows = l.map Receipt.body := by
  simp [view, h]

/-- The published commitment shown next to the data really is the tip of the
    chain that produced the rows. -/
theorem view_tip (H : Hasher) (genesis key : Nat) (l : Log) :
    (view H genesis key l).tipHash = tip genesis l := by
  unfold view
  by_cases hv : validated H genesis key l <;> simp [hv]

/-! ### The counters are real

The dashboard's byte counter is recomputed from the receipts; the invariant
below says it agrees with the proxy's own accounting, so the number on screen
is the number of bytes the proxy actually let through. -/

/-- The receipts account for exactly the bytes the proxy has spent. -/
def LedgerOk (m : Monitor) : Prop := allowedBytes m.log = m.bytesUsed

theorem step_ledgerOk {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    (h : LedgerOk m) : LedgerOk (step H sys m r).1 := by
  unfold LedgerOk at h ⊢
  unfold step
  by_cases ha : admits m r <;>
    simp [ha, allowedBytes, appendReceipt, receiptFor, h, Nat.add_comm]

theorem runAll_ledgerOk (H : Hasher) (sys : System) :
    ∀ (rs : List Request) (m : Monitor), LedgerOk m → LedgerOk (runAll H sys m rs)
  | [],      _, h => h
  | _ :: rs, _, h => runAll_ledgerOk H sys rs _ (step_ledgerOk h)

/-- The bytes reported on a verified dashboard are the bytes the proxy really
    moved, and they are inside the configured budget. -/
theorem view_bytes_within_budget (H : Hasher) (m : Monitor)
    (hledger : LedgerOk m) (hbudget : m.bytesUsed ≤ m.policy.byteBudget)
    (hv : validated H m.genesis m.key m.log = true) :
    (monitorView H m).bytesMoved = m.bytesUsed ∧
    (monitorView H m).bytesMoved ≤ m.policy.byteBudget := by
  unfold LedgerOk at hledger
  refine ⟨?_, ?_⟩ <;> simp [monitorView, view, hv, hledger, hbudget]

/-- End to end: run any trace through the proxy from a clean, verified start,
    and the dashboard shows exactly one signed, chain-linked row per intercepted
    call — no more, no fewer. -/
theorem view_of_trace (H : Hasher) (sys : System) (m : Monitor) (rs : List Request)
    (hchain : chainOk H m.genesis m.log = true) (hsig : signedOk m.key m.log = true) :
    (monitorView H (runAll H sys m rs)).verified = true ∧
    (monitorView H (runAll H sys m rs)).rows.length = m.log.length + rs.length := by
  have hc := runAll_chainOk H sys rs m hchain
  have hs := runAll_signedOk H sys rs m hsig
  have hv : validated H (runAll H sys m rs).genesis (runAll H sys m rs).key
      (runAll H sys m rs).log = true := by
    simp [validated, hc, hs]
  refine ⟨by simpa [monitorView] using (view_verified_iff _ _ _ _).mpr hv, ?_⟩
  rw [monitorView, view_hides_nothing _ _ _ _ hv]
  simp [runAll_log_length]

end Proxy
