"""Check the actual NumPy and SciPy BLAS libraries without a single-thread cap."""

import json
import subprocess
import sys

import numpy as np
from scipy.linalg.blas import dgemm
from threadpoolctl import threadpool_info

left = np.full((8, 8), 2.0)
right = np.ones((8, 8))
assert np.all(left @ right == 16)
assert np.all(dgemm(1.0, left, right) == 16)
pools = [pool for pool in threadpool_info() if pool["internal_api"] == "openblas"]
assert pools, "No OpenBLAS libraries exercised"
print(json.dumps(pools, indent=2), flush=True)
for pool in pools:
    assert pool["num_threads"] > 1, "A single-thread cap would hide the fork bug"
    for _ in range(20):
        subprocess.run([sys.argv[1], pool["filepath"]], check=True, timeout=15)
