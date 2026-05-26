{
  lib,
  python311Packages,
  fetchFromGitHub,
}:
python311Packages.buildPythonPackage {
  pname = "rsl-rl-lib";
  version = "3.1.2";
  pyproject = true;
  build-system = [python311Packages.setuptools];
  src = fetchFromGitHub {
    owner = "leggedrobotics";
    repo = "rsl_rl";
    rev = "v3.1.2";
    sha256 = "sha256-0bdX6MHkzvIoWXBzs4v3/uNe8LOR3RMeznSuZqwTLHI=";
  };

  propagatedBuildInputs = with python311Packages; [
    torch
    torchvision
    tensordict
    numpy
    gitpython
    onnx
  ];

  pythonImportsCheck = ["rsl_rl"];

  meta = {
    description = "Fast and simple RL algorithms implemented in PyTorch";
    homepage = "https://github.com/leggedrobotics/rsl_rl";
    license = lib.licenses.bsd3;
    maintainers = [];
  };
}
