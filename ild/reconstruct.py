"""Run upstream ILD reconstruction while retaining the MLPF truth audit inputs."""

import os
import runpy
import shutil
import sys
from pathlib import Path

source = Path(os.environ["ILD_CONFIG_DIR"]) / "StandardConfig/production"
production = Path.cwd() / "production"
# Each job needs a private working directory: upstream writes cdb.log and
# detector diagnostics relative to its steering directory. Symlink immutable
# input assets, while keeping newly created files inside this job.
shutil.copytree(
    source,
    production,
    copy_function=os.symlink,
    ignore=shutil.ignore_patterns("__pycache__", "*.log", "core*"),
)
os.chdir(production)
sys.path.insert(0, str(production))
import py_utils  # noqa: E402

# Preserve native simulation hits and digitization relations so that
# target attribution can be checked against the original ROOT identities.
py_utils.get_drop_collections = lambda calib, cmds: []
runpy.run_path(str(production / "ILDReconstruction.py"), run_name="__main__")
