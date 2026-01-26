{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Pinned nixpkgs for gcc-arm-embedded v10.3
    nixpkgs-gcc-arm-embedded-10.url = "github:NixOS/nixpkgs/dd613136ee91f67e5dba3f3f41ac99ae89c5406b";

    free42 = {
      url = "github:swissmicros/free42";
      flake = false;
    };

    dm42pgm = {
      url = "github:swissmicros/DM42PGM";
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
          default = self.packages.${system}.dm42pgm;

          free42-lib = pkgs.callPackage ./free42 {
            src = free42;
          };

          dm42pgm = pkgs.callPackage ./dm42pgm {
            src = dm42pgm;
            dmcp5 = true;
            inherit (self.packages.${system}) free42-lib;
          };
        }
      );
    };
}
