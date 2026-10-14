{
  lib,
  python3Packages,
  fetchPypi,
}:
let
  # tavily-python SDK is a runtime dep of tavily-cli but isn't in nixpkgs yet.
  # Vendor the build here so the CLI derivation stays self-contained.
  tavily-python = python3Packages.buildPythonPackage rec {
    pname = "tavily-python";
    version = "0.7.26";
    pyproject = true;

    src = fetchPypi {
      pname = "tavily_python";
      inherit version;
      sha256 = "sha256-NiAnKBRPzh7wzs4zgA+Y483rX2AOZnjFCxIyuGai9Qk=";
    };

    build-system = with python3Packages; [ setuptools ];

    dependencies = with python3Packages; [
      requests
      tiktoken
      httpx
    ];

    pythonImportsCheck = [ "tavily" ];

    # Upstream ships no test suite in the sdist.
    doCheck = false;

    meta = {
      description = "Python SDK for the Tavily search/extract API";
      homepage = "https://github.com/tavily-ai/tavily-python";
      license = lib.licenses.mit;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "tavily-cli";
  version = "0.1.4";
  pyproject = true;

  src = fetchPypi {
    pname = "tavily_cli";
    inherit version;
    sha256 = "sha256-+uN+mvoTuUvq9fTRj/07aMy8qsjZG0NOEurN5WR+lbg=";
  };

  build-system = with python3Packages; [ hatchling ];

  dependencies = with python3Packages; [
    click
    httpx
    rich
    tavily-python
  ];

  pythonImportsCheck = [ "tavily_cli" ];

  doCheck = false;

  meta = {
    description = "Official Tavily CLI — search, extract, crawl, map, and research the web from the terminal (tvly)";
    homepage = "https://github.com/tavily-ai/tavily-cli";
    license = lib.licenses.mit;
    mainProgram = "tvly";
  };
}
