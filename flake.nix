{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Pinned nixpkgs for gcc-arm-embedded v10.3
    nixpkgs-gcc-arm-embedded-10.url = "github:NixOS/nixpkgs/dd613136ee91f67e5dba3f3f41ac99ae89c5406b";

    # Use self as a dummy default for both source inputs.
    # Unless overridden, the packages use their own pinned sources.
    # Use --override-input to use your own sources.
    free42 = {
      follows = "";
      flake = false;
    };

    dm42pgm = {
      follows = "";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-gcc-arm-embedded-10,
      free42,
      dm42pgm,
    }:
    let
      inherit (nixpkgs) lib;
      optionalOverrideAttrs =
        condition: attrs: package:
        if condition then package.overrideAttrs attrs else package;

      useFree42Input = free42.outPath != self.outPath;
      useDm42PgmInput = dm42pgm.outPath != self.outPath;
    in
    {
      packages = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: { inherit gcc-arm-embedded; })
            ];
          };

          # Pin gcc-arm-embedded to v10.3.
          # This is the only version that builds successfully without changing any Makefile flags.
          gcc-arm-embedded =
            (import nixpkgs-gcc-arm-embedded-10 {
              # No prebuilt aarch64-darwin binary is available. We use the x86_64-darwin binary via Rosetta.
              system = if pkgs.stdenv.isDarwin then "x86_64-darwin" else system;
            }).gcc-arm-embedded-10;
        in
        {
          default = pkgs.symlinkJoin {
            name = "DM42PGM";
            paths = with self.packages.${system}; [ dm42 dm42n ];
          };

          free42-lib = optionalOverrideAttrs useFree42Input { src = free42; } (pkgs.callPackage ./free42 { });

          dm42 = optionalOverrideAttrs useDm42PgmInput { src = dm42pgm; } (
            pkgs.callPackage ./dm42pgm {
              inherit (self.packages.${system}) free42-lib;
              dmcp5 = false;
            }
          );

          dm42n = self.packages.${system}.dm42.override { dmcp5 = true; };
        }
      );

      checks = lib.genAttrs lib.systems.flakeExposed (
        system: with self.packages.${system}; {
          dm42 = dm42.overrideAttrs { doCheck = true; };
          dm42n = dm42n.overrideAttrs { doCheck = true; };
        }
      );
    };
}
