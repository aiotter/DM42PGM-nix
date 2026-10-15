{ lib, fetchzip }:

fetchzip rec {
  pname = "gcc-arm-none-eabi-source";
  version = "10.3-2021.10";
  url = "https://developer.arm.com/-/media/Files/downloads/gnu-rm/${version}/gcc-arm-none-eabi-${version}-src.tar.bz2";
  hash = "sha256-eaQStkUA7IkFWivHApKrLDq5mUM14hQSuNPa8OKXYiM=";

  passthru.gccVersion = "10.3.1";

  meta = {
    description = "Source distribution of GNU Arm Embedded Toolchain";
    homepage = "https://developer.arm.com/downloads/-/gnu-rm";
    license = with lib.licenses; [ gpl3Plus lgpl3Plus bsd2 ];
  };
}
