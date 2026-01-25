{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # pin to gcc-arm-embedded@10.3 (the only version I found to build the package without modifying Makefile flags)
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
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          gcc-arm =
            (import nixpkgs-gcc-arm-embedded-10 {
              # No prebuilt aarch64-darwin binary is available. We use the x86_64-darwin binary via Rosetta.
              system = if pkgs.stdenv.isDarwin then "x86_64-darwin" else system;
            }).gcc-arm-embedded-10;
        in
        {
          default = self.packages.${system}.dm42pgm;

          free42 = pkgs.stdenv.mkDerivation {
            pname = "free42-mod";
            version = "unstable";

            src = free42;

            nativeBuildInputs = with pkgs; [
              gcc
              gcc-arm
            ];

            patches = [ ./free42.patch ];

            buildPhase = "cd console; ./armbuild";

            installPhase = ''
              mkdir -p $out
              mv libfree42_bcd.a libfree42_bcd_rel.a $out
            '';
          };

          dm42pgm = pkgs.stdenv.mkDerivation rec {
            pname = "DM42-mod";
            version = "unstable";

            src = dm42pgm;

            nativeBuildInputs = with pkgs; [
              gcc-arm
              perlPackages.ArchiveZip
            ];

            DMCP5 = true;
            makeFlags = [ "TARGET=${pname}" ];

            # Workaround flags for building with the latest gcc-arm-embedded.
            # Note: the build currently succeeds, but the resulting binary is rejected by DM42n.
            # CFLAGS = "-fno-align-functions -fno-align-jumps -fno-align-loops -fno-align-labels -fshort-enums -flto";
            # LDFLAGS = "-fno-align-functions -fno-align-jumps -fno-align-loops -fno-align-labels -fshort-enums -flto";
            # preBuild = ''
            #   makeFlagsArray+=(
            #     CC="arm-none-eabi-gcc -std=gnu11"
            #     CXX="arm-none-eabi-g++ -std=gnu++17"
            #   )
            # '';

            prePatch = "cat ${dm42pgm}/patch/*.patch | patch -p2";
            postPatch = "cp ${self.packages.${system}.free42}/* lib";

            installPhase = ''
              mkdir -p $out
              find build -name '*.pgm' -or -name '*.pg5' -exec mv {} $out \;
            '';
          };
        }
      );
    };
}
