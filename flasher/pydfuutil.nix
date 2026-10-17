{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  pyusb,
}:

buildPythonPackage rec {
  pname = "pydfuutil";
  version = "0.11.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-hwQ0E/R85Q7YK7yY09+NT48Sovew5uxIqz7WgAMtKqA=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];
  dependencies = [ pyusb ];
  doCheck = false;
  pythonImportsCheck = [
    "pydfuutil.dfu"
    "pydfuutil.dfuse"
  ];

  meta = {
    description = "Python implementation of dfu-util's USB DFU protocol";
    homepage = "https://github.com/o-murphy/pydfuutil";
    license = with lib.licenses; [
      lgpl3Only
      gpl3Plus
    ];
  };
}
