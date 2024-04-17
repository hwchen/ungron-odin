{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils}:
    flake-utils.lib.eachDefaultSystem (system: let
      odin-overlay = self: super: {
        odin = super.odin.overrideAttrs (old: rec {
          version = "nightly-2024-03-31-0d8dadb";
          src = super.fetchFromGitHub {
            owner = "odin-lang";
            repo = "Odin";
            rev = "0d8dadb0840ced094383193b7fc22dd86d41e403";
            sha256 = "sha256-saAUd6gGJWu8rnA0NR4R0UwDvdvjfXlbNfqPhOJpFBM=";
          };

          nativeBuildInputs = with super; [ makeWrapper which ];

          LLVM_CONFIG = "${super.llvmPackages_17.llvm.dev}/bin/llvm-config";
          postPatch = ''
            sed -i 's/^GIT_SHA=.*$/GIT_SHA=/' build_odin.sh
            sed -i 's/LLVM-C/LLVM/' build_odin.sh
            patchShebangs build_odin.sh
          '';

          installPhase = old.installPhase + "cp -r vendor $out/bin/vendor";
        });
      };

      ols-overlay = self: super: {
        ols = super.ols.overrideAttrs (old: rec {
          version = "nightly-2024-03-31-b398c8c";
          src = super.fetchFromGitHub {
            owner = "DanielGavin";
            repo = "ols";
            rev = "b398c8c817c2b28888e86ebdae84b8deb00a49e0";
            sha256 = "sha256-EgtqdqDu46254QMwgayBgHzCORMOc5+Vfl6NoAMN+U0=";
          };

          installPhase = old.installPhase;
        });
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (odin-overlay)
          (ols-overlay)
        ];
        };

        lib = pkgs.lib;
        in {
        devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
        pkgs.odin
        pkgs.ols
        ];
      };
    });
}
