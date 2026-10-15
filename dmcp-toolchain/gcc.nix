{
  lib,
  stdenv,
  fetchpatch,
  source,
  bison,
  flex,
  m4,
  perl,
  gmp,
  mpfr,
  libmpc,
  zlib,
}:

stdenv.mkDerivation {
  pname = "dmcp-gcc-compiler";
  inherit (source) version;
  outputs = [
    "out"
    "buildSupport"
  ];
  srcs = map (component: "${source}/src/${component}.tar.bz2") [
    "gcc"
    "binutils"
    "newlib"
  ];
  sourceRoot = "gcc";

  nativeBuildInputs = [
    bison
    flex
    m4
    perl
  ];
  buildInputs = [
    gmp
    mpfr
    libmpc
    zlib
  ];
  strictDeps = true;
  # GCC 10 passes translated diagnostic strings to its own printf-like callbacks.
  hardeningDisable = [ "format" ];
  enableParallelBuilding = true;
  enableParallelInstalling = false;
  dontDisableStatic = true;
  dontStrip = true;
  dontPatchELF = true;

  env = {
    CFLAGS = "-O2 -std=gnu11";
    CXXFLAGS = "-O2 -std=gnu++11";
    M4 = lib.getExe m4;
  };

  postUnpack = ''
    cp -r binutils/{bfd,binutils,gas,ld,opcodes,libctf,etc} "$sourceRoot/"
    # Binutils needs matching libiberty declarations and implementations.
    cp -r binutils/include/. "$sourceRoot/include/"
    rm -r "$sourceRoot/libiberty"
    cp -r binutils/libiberty "$sourceRoot/"
    cp -rn binutils/config/. "$sourceRoot/config/"
    cp -n binutils/{test-driver,ylwrap} "$sourceRoot/"
    cp -r newlib/{newlib,libgloss} "$sourceRoot/"
  '';
  patches = [
    ./libcxx-headers.patch
  ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    (fetchpatch {
      name = "apple-silicon.patch";
      url = "https://raw.githubusercontent.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/e39be910534fe4946d93622dbc86c7bb7a7bbe73/patches/gcc-10.3.1-apple-silicon.patch.diff";
      hash = "sha256-Zt0KGC1NMKjd8HA9lzi6NdMkkFH3Eet7nTXvjnj7bFw=";
    })
  ];

  preConfigure = ''
    mkdir build
    cd build
    configureScript=../configure
  '';
  configureFlags = [
    "--build=${stdenv.buildPlatform.config}"
    "--host=${stdenv.hostPlatform.config}"
    "--target=arm-none-eabi"
    "--enable-languages=c,c++"
    # Both calculators use this CPU/ABI.
    "--with-arch=armv7e-m"
    "--with-mode=thumb"
    "--with-fpu=fpv4-sp-d16"
    "--with-float=hard"
    "--disable-libstdcxx-pch"
    "--disable-nls"
    "--disable-shared"
    "--disable-tls"
    "--disable-werror"
    "--with-newlib"
    "--with-native-system-header-dir=/include"
    "--with-system-zlib"
    "--with-sysroot=${builtins.placeholder "out"}/arm-none-eabi"
    # The official startup code omits TM clone registration.
    "--disable-tm-clone-registry"
    "--disable-multilib"
  ];
  makeFlags = [
    "MAKEINFO=true"
    "M4=${lib.getExe m4}"
  ];
  buildFlags = [
    "all-binutils"
    "all-gas"
    "all-ld"
    "all-gcc"
  ];
  installTargets = [
    "install-binutils"
    "install-gas"
    "install-ld"
    "install-gcc"
  ];

  postInstall = ''
    # libgcc uses GCC's generated target headers and configuration, not its objects.
    mkdir -p "$buildSupport/gcc"
    cp gcc/*.{h,def} gcc/libgcc.mvars "$buildSupport/gcc/"
    cp -r gcc/include "$buildSupport/gcc/"
  '';
  passthru = {
    isGNU = true;
    langC = true;
    langCC = true;
  };
  meta = {
    inherit (source.meta) homepage license;
    description = "GNU Arm Embedded C/C++ compiler and Binutils for DMCP applications";
    platforms = lib.systems.flakeExposed;
  };
}
