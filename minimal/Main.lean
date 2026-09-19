/-
  RequestProject — merged formal model

This module is the single entry point of the merged project.  It pulls together

* the agent/twin model that was previously spread over several disconnected
  copies (`Agent`, `Twin`, `CreditUsage`, `APICapabilities`, `CommandExecution`,
  `ToolProvenance`, `ExecutionTrace`), repaired so that everything compiles and
  every statement is one that actually holds, and
* the protocol layer for **certified peer-to-peer calls to a Lean 4 prover
  or to executables it produced** (`Protocol.Core`, `Protocol.Server`,
  `Protocol.Client`, `Protocol.Soundness`, `Protocol.Example`), and
* the **logging proxy** that mediates and receipts every system, file and
  network call, together with the validated dashboard built on its journal
  (`Proxy.Core`, `Proxy.Monitor`, `Proxy.Dashboard`, `Proxy.Concrete`,
  `Proxy.Interop`, `Proxy.Example`, `Proxy.Export`).
-/
import Mathlib

import RequestProject.Agent
import RequestProject.APICapabilities
import RequestProject.CommandExecution
import RequestProject.CreditUsage
import RequestProject.ExecutionTrace
import RequestProject.ToolProvenance
import RequestProject.Twin

import RequestProject.Protocol.Core
import RequestProject.Protocol.Server
import RequestProject.Protocol.Client
import RequestProject.Protocol.Soundness
import RequestProject.Protocol.Example

import RequestProject.Proxy.Core
import RequestProject.Proxy.Monitor
import RequestProject.Proxy.Dashboard
import RequestProject.Proxy.Concrete
import RequestProject.Proxy.Interop
import RequestProject.Proxy.Example
import RequestProject.Proxy.Export

open scoped BigOperators
open scoped Real
open scoped Nat
open scoped Classical
open scoped Pointwise

set_option maxHeartbeats 8000000
set_option maxRecDepth 4000
set_option synthInstance.maxHeartbeats 20000
set_option synthInstance.maxSize 128

set_option relaxedAutoImplicit false
set_option autoImplicit false

set_option grind.warning false
