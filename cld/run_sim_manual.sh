#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo "Usage: run_sim_manual.sh SAMPLE SEED" >&2; exit 2; }
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export CONFIG_DIR=${CONFIG_DIR:-${SIMDIR:-${SCRIPT_DIR}/CLDConfig}}
export RUN_SIM_IN_SINGULARITY=1
mkdir -p "${OUTDIR:?Set OUTDIR}" "${WORKDIR:?Set an empty WORKDIR}"
exec bash "$SCRIPT_DIR/run_sim.sh" "$@"
