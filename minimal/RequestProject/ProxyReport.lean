/-
  Executable: write the modelled proxy run out as a receipt journal the
  dashboard can load and re-verify.

      lake exe proxy_report [outdir]      (default: dashboard/data)
-/

import RequestProject.Proxy.Export

def main (args : List String) : IO Unit := do
  let outdir := args.headD "dashboard/data"
  IO.FS.createDirAll outdir
  let logPath := System.FilePath.mk outdir / "lean-model.jsonl"
  let metaPath := System.FilePath.mk outdir / "lean-model-meta.json"
  IO.FS.writeFile logPath Proxy.Export.demoJsonl
  IO.FS.writeFile metaPath Proxy.Export.demoMetaJson
  IO.println s!"wrote {logPath} and {metaPath}"
