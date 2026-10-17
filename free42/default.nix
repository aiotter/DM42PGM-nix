{
  lib,
  stdenv,
  fetchFromGitHub,

  gcc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "free42";
  version = lib.fileContents "${finalAttrs.src}/gtk/VERSION";

  src = fetchFromGitHub {
    owner = "swissmicros";
    repo = "free42";
    rev = "a7c705e476cfd6d83d7d8b90042999f386367813";
    hash = "sha256-mXMvnaGlDsT+MK0OJUqJ/SazelfCiB+ZbApvlzg1tf0=";
  };

  depsBuildBuild = [ gcc ];

  postPatch = ''
    patchShebangs --build console/armbuild
  '';

  buildPhase = "cd console; ./armbuild";

  installPhase = ''
    mkdir -p $out
    mv libfree42_bcd.a libfree42_bcd_rel.a $out
  '';
})
