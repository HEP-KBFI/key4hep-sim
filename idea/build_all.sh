#!/bin/bash
set -euo pipefail
CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for component in k4geo k4rectracker k4reccalorimeter; do
    bash "${CONFIG_DIR}/build_${component}.sh"
done
