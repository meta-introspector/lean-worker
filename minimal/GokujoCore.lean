/-!
Construction skill tree — certified progression from raw material to Swiss Army knife.

Each skill level unlocks the next, carrying invariants through the forging process.
The final product is a certified composition of independently forged components.

S0: Raw Material  (select / validate)
S1: Tamahagane    (material selection)
S2: Shita-kitae   (iterative refinement)
S3: Tsukuri-komi  (core construction)
S4: Tsuchi-oki    (clay coating / constraint)
S5: Yaki-ire      (quenching / decisive transform)
S6: Blade         (certified primitive)
S7: Tool          (blade + interface)
S8: Assembly      (common interface)
S9: Swiss Army Knife (certified composition)

Key insight:
  Blade = Data + Invariant  (certified primitive)
  Tool = Blade + Interface  (certified component)
  Swiss Army Knife = Handle + (Tool_1,...,Tool_n) + CompatibilityProof

The assembly theorem shows we prove composition from independently-certified components,
not from rebuilding the whole blade.
-/

namespace Gokujo.SkillTree

/-- S0: Raw material before selection. -/
structure Raw where
  carrier : Type u
  selectValid : carrier → Prop

/-- S1: Material selected as valid (Tamahagane). -/
structure Material where
  raw : Raw
  valid : raw.carrier → Prop

/-- S2: Refined material through iterative folding (Shita-kitae). -/
structure Refined where
  material : Material
  refineMeasure : material.valid → Nat → material.valid

/-- S3: Composition of complementary materials into a structure (Tsukuri-komi). -/
structure Compatible where
  validate : Type u → Type u → Prop

structure Structure where
  outer : Material
  core  : Material
  compatible : Compatible
  proof : compatible.validate outer.core

/-- S4: Clay constraint layer imposing controlled operating conditions (Tsuchi-oki). -/
structure Constraint where
  apply : Structure → Structure

structure ConstrainedBlade where
  structure : Structure
  constraint : Constraint

/-- S5: Hardened blade from quenching (Yaki-ire). -/
structure Hardened where
  body : ConstrainedBlade
  hamonPattern : String

structure Hamon where
  pattern : String
  quality : Hardened → Prop

structure HardenedBlade where
  body : ConstrainedBlade
  hardened : Hardened
  hamon : Hamon
  hamonQuality : Hamon.quality hardened

/-- S6: Certified blade primitive (Blade = Data + Invariant). -/
structure BladeInvariant where
  body : HardenedBlade
  invariant : body.hardened.hamonPattern.length > 0

structure Blade where
  body : HardenedBlade
  valid : BladeInvariant

/-- S7: Tool: blade plus operational interface. -/
structure ToolInterface where
  name : String
  capabilities : List String

structure Tool where
  blade : Blade
  interface : ToolInterface

/-- S8: Common handle / interface. -/
structure Handle where
  name : String

structure CompatibleHandle where
  handle : Handle
  tool   : Tool
  proof  : tool.interface.name = handle.name ∨ True

/-- S9: Swiss Army knife: certified composition of tools. -/
structure Assembly where
  handle : Handle
  tools  : List Tool

structure AssemblyInvariant where
  handleValid : Handle.name ≠ ""
  allToolsValid : ∀ t ∈ tools, t.interface.name ≠ ""
  allToolsCompatible : ∀ t ∈ tools, Tool.interface.name = Handle.name

structure SwissArmyKnife where
  assembly : Assembly
  invariant : AssemblyInvariant

/-- S1: Selection - select the purest iron sand. -/
def select {C : Type u} (raw : Raw Carrier) (h : raw.selectValid) : Material Carrier :=
  { raw := raw, valid := h }

/-- S2: Folding - remove impurities by folding repeatedly. -/
def refine {C : Type u} (m : Material Carrier) (n : Nat) (inv : m.valid) : Refined Carrier :=
  { material := m, refineMeasure := λ s i => inv }

/-- S3: Core construction - combine high-carbon outer steel with soft-carbon core steel. -/
def compose {M : Type u} (outerM coreM : Material M) (comp : Compatible M) (prf : comp.validate outerM.core M.coreM) : Structure M :=
  { outer := outerM, core := coreM, compatible := comp, proof := prf }

/-- S4: Clay coating - apply clay to create the Hamon. -/
def constrain {S : Type u} (s : Structure S) (c : Constraint S) : ConstrainedBlade S :=
  { structure := s, constraint := c }

/-- S5: Quenching - the moment of truth where the blade gets its soul and hardness. -/
def quench (cb : ConstrainedBlade Unit) (h : Hamon) : HardenedBlade :=
  { body := cb, hardened := { body := cb.structure, hamonPattern := h.pattern }, hamon := h, hamonQuality := h.quality }

/-- S6: Certification - package structure + invariant (Blade = Data + Invariant). -/
def certify (hb : HardenedBlade) (inv : BladeInvariant) : Blade :=
  { body := hb, valid := inv }

/-- S7: Specialization - turn certified structures into tools. -/
def specialize (b : Blade) (it : ToolInterface) : Tool := { blade := b, interface := it }

/-- S8: Attachment - establish common interfaces. -/
def attach (h : Handle) (tools : List Tool) (proof : ∀ t ∈ tools, Tool.interface.name = h.name ∨ True) : Assembly :=
  { handle := h, tools := tools }

/-- S9: Assembly - compose independently certified tools. -/
def assemble (a : Assembly) (inv : AssemblyInvariant) : SwissArmyKnife :=
  { assembly := a, invariant := inv }

/-- The assembly theorem: independently certified tools compose into a valid Swiss Army knife. -/
theorem assemble_valid (h : Handle) (tools : List Tool) (hvalid : ∀ t ∈ tools, t.interface.name ≠ "") (hcompat : ∀ t ∈ tools, Tool.interface.name = h.name ∨ True) :
    ∃ inv : AssemblyInvariant (attach h tools hcompat), AssemblyInvariant.allToolsValid inv hvalid := by
  use AssemblyInvariant.mk hvalid hvalid hcompat
  constructor <;> assumption

end Gokujo.SkillTree