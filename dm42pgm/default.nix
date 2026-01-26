{
  lib,
  stdenv,
  gcc-arm-embedded,
  perlPackages,

  src,
  free42-lib,

  dmcp5 ? true,
}:

stdenv.mkDerivation rec {
  pname = "DM42-mod";
  version = "unstable";

  inherit src;

  nativeBuildInputs = [
    gcc-arm-embedded
    perlPackages.ArchiveZip
  ];

  makeFlags = (lib.optional dmcp5 "DMCP5=1") ++ [ "TARGET=${pname}" ];

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

  prePatch = lib.optionalString dmcp5 "cat patch/dmcp5_*.patch | patch -p2";
  postPatch = "cp ${free42-lib}/{libfree42_bcd.a,libfree42_bcd_rel.a} lib";

  installPhase = ''
    mkdir -p $out
    find build -name '*.pgm' -or -name '*.pg5' -exec mv {} $out \;
  '';
}
