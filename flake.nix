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
          pkgs = import nixpkgs { inherit system; };
          dmcpToolchain = pkgs.callPackage ./dmcp-toolchain { };
        in
        {
          dmcp-stdenv = dmcpToolchain.stdenv;
          dmcp-gcc = dmcpToolchain.gcc;

          default = pkgs.symlinkJoin {
            name = "DM42PGM";
            paths = with self.packages.${system}; [
              dm42
              dm42n
            ];
          };

          free42-lib = optionalOverrideAttrs useFree42Input { src = free42; } (
            pkgs.callPackage ./free42 { stdenv = dmcpToolchain.stdenv; }
          );

          dm42 = optionalOverrideAttrs useDm42PgmInput { src = dm42pgm; } (
            pkgs.callPackage ./dm42pgm {
              stdenv = dmcpToolchain.stdenv;
              inherit (self.packages.${system}) free42-lib;
              dmcp5 = false;
            }
          );

          dm42n = self.packages.${system}.dm42.override { dmcp5 = true; };
        }
      );

      checks = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          checkHash =
            firmwarePackage:
            pkgs.testers.runCommand {
              name = "${firmwarePackage.name}-firmware-hash";
              hash = firmwarePackage.expectedFirmwareHash;
              script = ''cp ${firmwarePackage}/* "$out"'';
            };
        in
        with self.packages.${system};
        {
          dm42 = checkHash dm42.original;
          dm42n = checkHash dm42n.original;
        }
      );
    };
}
