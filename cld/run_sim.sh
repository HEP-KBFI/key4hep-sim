#!/usr/bin/env bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export GENERATOR_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# Preserve main's optional container entry point, using the qualified dev image.
if [[ ${RUN_SIM_IN_SINGULARITY:-0} == 1 ]]; then
    export RUN_SIM_IN_SINGULARITY=0
    exec apptainer exec --bind "/cvmfs,$GENERATOR_ROOT,/tmp,${OUTDIR:?Set OUTDIR},${WORKDIR:?Set WORKDIR}" \
        --env LD_PRELOAD=/usr/lib64/libffi.so.8 "$GENERATOR_ROOT/idea/idea-dev.sif" \
        bash "$SCRIPT_DIR/run_sim.sh" "$@"
fi
NEV=${NEV:-100}
SAMPLE=${1:?Usage: run_sim.sh SAMPLE SEED}
NUM=${2:?Set random seed}
CONFIG_DIR=${CONFIG_DIR:-${GENERATOR_ROOT}/cld/CLDConfig}
OUTDIR=${OUTDIR:?Set OUTDIR}
WORKDIR=${WORKDIR:?Set an empty WORKDIR}
mkdir -p "$OUTDIR/$SAMPLE/root" "$WORKDIR"
OUTDIR=$(realpath "$OUTDIR")
WORKDIR=$(realpath "$WORKDIR")
[[ -z $(ls -A "$WORKDIR") ]] || { echo "WORKDIR must be empty: $WORKDIR" >&2; exit 1; }
cd "$WORKDIR"
# Retain manual-run evidence; production scratch is disposable after publishing.
cleanup() {
    case "$WORKDIR" in /scratch/local/${USER}/*) rm -rf -- "$WORKDIR" ;; esac
}
trap cleanup EXIT
source "$GENERATOR_ROOT/setup.sh"
source "$GENERATOR_ROOT/stage_logging.sh"
key4hep_write_manifest software.txt
cp -R "$CONFIG_DIR" CLDConfig
export PYTHONPATH="$PWD/CLDConfig/CLDConfig:${PYTHONPATH:-}"
sim_args=(--outputFile out_SIM.root --compactFile "$K4GEO/FCCee/CLD/compact/CLD_o2_v07/CLD_o2_v07.xml"
    --steeringFile CLDConfig/CLDConfig/cld_steer.py)
if [[ $SAMPLE == gun_* ]]; then
    case $SAMPLE in
        gun_e_*) particle=e- ;; gun_mu_*) particle=mu- ;; gun_pi_*) particle=pi- ;;
        *) echo "Unsupported CLD gun: $SAMPLE" >&2; exit 1 ;;
    esac
    sim_args+=(--enableGun --gun.distribution "${GUN_DISTRIBUTION:-uniform}" --gun.energy "${GUN_ENERGY:-10*GeV}"
        --gun.particle "${GUN_PARTICLE:-$particle}" --crossingAngleBoost 0.0
        --random.enableEventSeed --random.seed "$NUM" --numberOfEvents "$NEV")
else
    run_stage generation bash "$GENERATOR_ROOT/generators/generate_events.sh" "$SAMPLE" "$NUM" "$NEV" fccee
    cat generation.software.txt >> software.txt
    sim_args+=(--inputFiles out.hepmc --numberOfEvents "$NEV")
fi
run_stage simulation ddsim "${sim_args[@]}"
(
    cd CLDConfig/CLDConfig
    run_stage reconstruction k4run CLDReconstruction.py --inputFiles ../../out_SIM.root --outputBasename out_RECO --num-events -1
)
output="$OUTDIR/$SAMPLE/root/reco_${SAMPLE}_${NUM}.root"
cp CLDConfig/CLDConfig/out_RECO_REC.edm4hep.root "$output.partial"
mv "$output.partial" "$output"
cp software.txt "${output%.root}.software.txt"
