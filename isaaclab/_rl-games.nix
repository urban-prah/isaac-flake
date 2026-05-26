{
  lib,
  python311Packages,
  fetchFromGitHub,
}:
python311Packages.buildPythonPackage {
  pname = "rl-games";
  version = "1.6.1";
  pyproject = true;
  build-system = [python311Packages.poetry-core];
  src = fetchFromGitHub {
    owner = "isaac-sim";
    repo = "rl_games";
    rev = "python3.11";
    sha256 = "sha256-EFV2sqwZHN1vMw5WxA7kqygeC96sfDeJmwJmwNCRfvw=";
  };

  propagatedBuildInputs = with python311Packages; [
    torch
    numpy
    tensorboard
    tensorboardx
    setproctitle
    psutil
    pyyaml
    watchdog
  ];

  pythonImportsCheck = ["rl_games"];

  meta = {
    description = "TensorFlow/PyTorch implementations of RL algorithms";
    homepage = "https://github.com/Denys88/rl_games";
    license = lib.licenses.mit;
    maintainers = [];
  };
}
