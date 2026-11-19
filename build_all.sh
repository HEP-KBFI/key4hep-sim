#!/bin/bash
set -euo pipefail
GENERATOR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "${GENERATOR_ROOT}/build_overlays.sh"
bash "${GENERATOR_ROOT}/build_marlintrkprocessors.sh"
for component in k4geo k4rectracker k4reccalorimeter; do
    bash "${GENERATOR_ROOT}/idea/build_${component}.sh"
done
bash "${GENERATOR_ROOT}/idea/fetch_tracking_model.sh"
