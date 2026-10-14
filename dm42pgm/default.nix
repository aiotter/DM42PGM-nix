{
  lib,
  stdenv,

  gcc-arm-embedded,
  perlPackages,

  src,
  free42-lib,

  dmcp5 ? true,

  pname ? "DM42",
  version ? builtins.head (
    builtins.match ''.*#define[[:space:]]+DM42_VERSION[[:space:]]+"([^"]+)".*'' (
      builtins.readFile "${src}/dm/main.h"
    )
  ),
}:

stdenv.mkDerivation rec {
  __structuredAttrs = true;

  inherit pname version src;

  nativeBuildInputs = [
    gcc-arm-embedded
    perlPackages.ArchiveZip
  ];

  makeFlags = (lib.optional dmcp5 "DMCP5=1") ++ [
    # The official DM42n firmware uses libfree42_bcd.a.
    "LIBS=lib/${if dmcp5 then "libfree42_bcd.a" else "libfree42_bcd_rel.a"} lib/gcc111libbid_hard.a"
    "TARGET=${pname}-${version}"
  ];

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
  postPatch = ''
    # The official firmware is built from the code before license headers are added.
    # Removing these headers produced a binary identical to the official firmware.
    find . -type f \( -name '*.c' -o -name '*.cc' -o -name '*.h' -o -name '*.s' \) \
      -exec gawk -i inplace -f ${./strip-license-headers.awk} {} +

    cp ${free42-lib}/{libfree42_bcd.a,libfree42_bcd_rel.a} lib
  '';

  installPhase = ''
    mkdir -p $out
    cp build/${pname}-${version}.${if dmcp5 then "pg5" else "pgm"} "$out/"
  '';
}
