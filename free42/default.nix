{
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

  patches = [ ./free42.patch ];

  buildPhase = "cd console; ./armbuild";

  installPhase = ''
    mkdir -p $out
    mv libfree42_bcd.a libfree42_bcd_rel.a $out
  '';
}
