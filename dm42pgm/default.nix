{
  lib,
  stdenv,
  fetchFromGitHub,

  perlPackages,

  free42-lib,

  dmcp5 ? true,
}:

stdenv.mkDerivation (
  finalAttrs:
  let
    firmwareFileName = "${finalAttrs.pname}-${finalAttrs.version}.${if dmcp5 then "pg5" else "pgm"}";
  in
  rec {
    __structuredAttrs = true;

    pname = "DM42";
    version = builtins.head (
      builtins.match ''.*#define[[:space:]]+DM42_VERSION[[:space:]]+"([^"]+)".*'' (
        builtins.readFile "${finalAttrs.src}/dm/main.h"
      )
    );

    src = fetchFromGitHub {
      owner = "swissmicros";
      repo = "DM42PGM";
      rev = "3270592f2be6f6d0316e1a0f482a1faecc14aaa9";
      hash = "sha256-mZvL6kVjaf2FN2s8MfSx9ZNFLD4MFe/r4/zNjifpZcA=";
    };

    passthru = {
      # NAR hashes of the official firmware files for testers.runCommand.
      expectedFirmwareHash =
        if dmcp5 then
          "sha256-wHRDXODOyOjL9DCfI0Gi/saGWFuCKXJH4BsaYRYOEUw="
        else
          "sha256-y5gI8B+uw3HIRyZjZb0brGV/HgbLPHCvjVLUzUOjE80=";

      inherit free42-lib firmwareFileName;

      # Keep the official sources available for checks when overrideAttrs replaces src or free42-lib.
      original = finalAttrs.finalPackage.overrideAttrs (previousAttrs: {
        inherit src;
        passthru = previousAttrs.passthru // {
          free42-lib = finalAttrs.passthru.free42-lib.original;
        };
      });
    };

    nativeBuildInputs = [
      perlPackages.ArchiveZip
    ];

    makeFlags = [
      # The official DM42n firmware uses libfree42_bcd.a.
      "LIBS=lib/${if dmcp5 then "libfree42_bcd.a" else "libfree42_bcd_rel.a"} lib/gcc111libbid_hard.a"
      "DMCP5=${lib.optionalString dmcp5 "1"}"
      "TARGET=${finalAttrs.pname}-${finalAttrs.version}"
    ];

    prePatch = lib.optionalString dmcp5 "cat patch/dmcp5_*.patch | patch -p2";
    postPatch = ''
      patchShebangs --build bin

      # The official firmware is built from the code before license headers are added.
      # Removing these headers produced a binary identical to the official firmware.
      find . -type f \( -name '*.c' -o -name '*.cc' -o -name '*.h' -o -name '*.s' \) \
        -exec gawk -i inplace -f ${./strip-license-headers.awk} {} +

      cp ${finalAttrs.passthru.free42-lib}/{libfree42_bcd.a,libfree42_bcd_rel.a} lib
    '';

    installPhase = ''
      mkdir -p $out
      cp build/${firmwareFileName} "$out/"
    '';
  }
)
