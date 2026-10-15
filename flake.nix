{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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
      free42,
      dm42pgm,
    }:
    let
      inherit (nixpkgs) lib;
      supportedSystems = import ./gcc-arm-embedded-xpack/platforms.nix;
      optionalOverrideAttrs =
        condition: attrs: package:
        if condition then package.overrideAttrs attrs else package;

      useFree42Input = free42.outPath != self.outPath;
      useDm42PgmInput = dm42pgm.outPath != self.outPath;
    in
    {
      packages = lib.genAttrs supportedSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                gcc-arm-embedded = final.callPackage ./gcc-arm-embedded-xpack { };
              })
            ];
          };
        in
        {
          gcc-arm-embedded-xpack = pkgs.gcc-arm-embedded;

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

      checks = lib.genAttrs supportedSystems (
        system: with self.packages.${system}; {
          dm42 = dm42.original;
          dm42n = dm42n.original;
        }
      );
    };
}
