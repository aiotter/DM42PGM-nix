{
  lib,
  stdenv,
  src,
  version,
  makeFlags,
  dmcp5,
}:

stdenv.mkDerivation {
  __structuredAttrs = true;

  pname = "dm42pgm-objects";
  inherit src version makeFlags;

  prePatch = lib.optionalString dmcp5 "cat patch/dmcp5_*.patch | patch -p2";
  postPatch = ''
    patchShebangs --build bin

    # The official firmware is built from the code before license headers are added.
    # Removing these headers produced a binary identical to the official firmware.
    find . -type f \( -name '*.c' -o -name '*.cc' -o -name '*.h' -o -name '*.s' \) \
      -exec gawk -i inplace -f ${./strip-license-headers.awk} {} +

    # Upstream uses bundled Free42 static libraries, but we build them separately.
    # Remove the bundled copies here; the final firmware build supplies ours.
    rm lib/libfree42_bcd.a lib/libfree42_bcd_rel.a
  '';

  preBuild = ''
    cat > objects.mk <<'EOF'
    .PHONY: objects
    objects: $(OBJECTS)
    EOF
  '';

  makefile = "Makefile";
  buildFlags = [ "-f" "objects.mk" "objects" ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    runHook postInstall
  '';

  # Avoid unnecessary stripping of static libraries used by the final firmware link.
  dontStrip = true;
}
