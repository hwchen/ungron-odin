{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils}:
    flake-utils.lib.eachDefaultSystem (system: let
      odin-overlay = self: super: {
        odin = super.odin.overrideAttrs (old: rec {
          version = "nightly-2024-05-17-98f8624";
          src = super.fetchFromGitHub {
            owner = "odin-lang";
            repo = "Odin";
            rev = "98f8624447a4755f94a0320806a1675f4b47038e";
            sha256 = "sha256-eRv5kaUAtEJ9Omo97qNEBL1oy5sCErFHfPhaBEyzkDU=";
          };

          nativeBuildInputs = with super; [ makeWrapper which ];

          LLVM_CONFIG = "${super.llvmPackages_18.llvm.dev}/bin/llvm-config";
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
          version = "nightly-2024-05-16-e6c1cac";
          src = super.fetchFromGitHub {
            owner = "DanielGavin";
            repo = "ols";
            rev = "e6c1cacab21e6368a4e818a06d02682235aa50eb";
            sha256 = "sha256-qUNJ0WlCc965YtnwokaEe4CEmWTiYZ/gR6Kp/in/qcQ=";
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
        pkgs.poop
        pkgs.hyperfine
        ];
      };
    });
}
