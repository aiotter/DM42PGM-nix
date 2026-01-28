{
  lib,
  stdenv,
  src,
  gcc,
  gcc-arm-embedded,
}:

stdenv.mkDerivation {
  pname = "free42-mod";
  version = "unstable";

  inherit src;

  nativeBuildInputs = [
    gcc
    gcc-arm-embedded
  ];

  prePatch = "cp -r ${./src}/. .";
  patches = lib.fileset.toList ./patch;

  buildPhase = "cd console; ./armbuild";

  installPhase = ''
    mkdir -p $out
    mv libfree42_bcd.a libfree42_bcd_rel.a $out
  '';
}
