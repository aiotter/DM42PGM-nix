{
  lib,
  stdenv,

  gcc,
  gcc-arm-embedded,

  src,
  pname ? "free42",
  version ? lib.fileContents "${src}/gtk/VERSION",
}:

stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    gcc
    gcc-arm-embedded
  ];

  buildPhase = "cd console; ./armbuild";

  installPhase = ''
    mkdir -p $out
    mv libfree42_bcd.a libfree42_bcd_rel.a $out
  '';
}
