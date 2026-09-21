{
  description = "lean-worker — formal twin of an AI agent on Aleph Cloud (Lean 4)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lean4.url = "github:leanprover/lean4";
    mathlib4.url = "github:leanprover-community/mathlib4";
    gokujo.url = "github:mfng/gokujo";  # placeholder, will use local
    pipelight.url = "github:pipelight/pipelight";
  };

  outputs = { self, nixpkgs, flake-utils, lean4, mathlib4, gokujo, pipelight }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lean = pkgs.lean4;
      leanc = pkgs.leanc;
      lake = pkgs.lake;
      nix = pkgs.nix;
    in {
      devShells.default = pkgs.mkShell {
        name = "lean-worker";
        buildInputs = with pkgs; [
          lean
          leanc
          lake
          git
          jq
          curl
          nix
        ];
        LEAN_PATH = "${self.packages.${system}.RequestProject}/share/lean";
        shellHook = ''
          echo "lean-worker dev shell ready"
          echo "Run: lake build    # standard Lake build"
          echo "Run: gokujo check  # gokujo single-file build + proof gate"
          echo "Run: gokujo bootstrap -o gokujo  # compile gokujo itself"
          echo "Run: gokujo html -o gokujo.html  # self-contained manual"
        '';
      };

      packages.RequestProject = pkgs.stdenv.mkDerivation {
        name = "lean-worker-RequestProject";
        src = self;
        buildInputs = with pkgs; [ lean leanc lake ];
        buildPhase = ''
          cd minimal
          lake -d build RequestProject
        '';
        installPhase = ''
          mkdir -p $out/share/lean
          cp -r minimal/.lake/build/lib/RequestProject $out/share/lean/
        '';
      };

      packages.gokujo = pkgs.stdenv.mkDerivation {
        name = "gokujo";
        src = self;
        buildInputs = with pkgs; [ lean leanc ];
        buildPhase = ''
          cd minimal
          # Stage 1: build without mathlib (fast, for CI)
          if [ -f Gokujo.lean ]; then
            lean --make Gokujo.lean -o gokujo-stage1
          fi
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp minimal/gokujo-stage1 $out/bin/gokujo 2>/dev/null || true
        '';
      };

      # Two-stage build: fast no-mathlib check, then full mathlib build
      checks = {
        "stage1-no-mathlib" = self.packages.${system}.gokujo;
        "stage2-full" = self.packages.${system}.RequestProject;
      };

      # pipelight.dev integration
      devPackages = {
        "pipelight-verify" = pipelight.packages.${system}.verify;
      };
    });
}