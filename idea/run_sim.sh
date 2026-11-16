#!/bin/bash
# Generate, simulate, digitize, and reconstruct FCC-ee IDEA events.
set -euo pipefail
set -x

NEV=${NEV:-100}
PROGRESS_INTERVAL=${PROGRESS_INTERVAL:-9999999}
GUN_PARTICLE=${GUN_PARTICLE:-}
GUN_ENERGY=${GUN_ENERGY:-10*GeV}
GUN_DISTRIBUTION=${GUN_DISTRIBUTION:-uniform}
ENABLE_GGTF=${ENABLE_GGTF:-true}
SAMPLE=${1:?Usage: run_sim.sh PROCESS_NAME RANDOM_SEED}
NUM=${2:?Usage: run_sim.sh PROCESS_NAME RANDOM_SEED}
OUTDIR=${OUTDIR:?OUTDIR must point at the production gen directory}
CONFIG_DIR=${CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
LOCAL_K4RECCALORIMETER=${LOCAL_K4RECCALORIMETER:-${CONFIG_DIR}/k4RecCalorimeter-local}
LOCAL_K4GEO=${LOCAL_K4GEO:-${CONFIG_DIR}/k4geo-local}
LOCAL_K4RECTRACKER=${LOCAL_K4RECTRACKER:-${CONFIG_DIR}/k4RecTracker-local}
WORKDIR=${WORKDIR:-/scratch/local/${USER}/${SAMPLE}_${SLURM_JOB_ID:-manual}}
TRACKING_MODEL=${TRACKING_MODEL:-${WORKDIR}/SimpleGatrIDEAv3o1.onnx}
FULLOUTDIR=${OUTDIR}/${SAMPLE}/root
LOGDIR=${LOGDIR:-${WORKDIR}/logs}

TUTORIAL_DIR=${CONFIG_DIR}/FCC-config/FCCee/FullSim/IDEA/IDEA_o1_v03
GEN_DIR=$(cd "${CONFIG_DIR}/.." && pwd)
PYTHIA_DIR=${GEN_DIR}/cld/CLDConfig

mkdir -p "${FULLOUTDIR}" "${WORKDIR}" "${LOGDIR}"

cleanup() {
    case "${WORKDIR}" in
        /scratch/local/${USER}/*) rm -rf -- "${WORKDIR}" ;;
        *) echo "Not removing unexpected WORKDIR: ${WORKDIR}" ;;
    esac
}
trap cleanup EXIT

run_with_progress() {
    local label=$1
    local log_file=$2
    shift 2

    "$@" > >(tee -a "${log_file}") 2>&1 &
    local command_pid=$!
    (
        local elapsed=0
        while kill -0 "${command_pid}" 2>/dev/null; do
            sleep "${PROGRESS_INTERVAL}"
            kill -0 "${command_pid}" 2>/dev/null || break
            elapsed=$((elapsed + PROGRESS_INTERVAL))
            local io_summary="unavailable"
            if [[ -r "/proc/${command_pid}/io" ]]; then
                io_summary=$(awk '
                    $1 == "read_bytes:" { read_bytes=$2 }
                    $1 == "write_bytes:" { write_bytes=$2 }
                    END { printf "read_bytes=%s write_bytes=%s", read_bytes, write_bytes }
                ' "/proc/${command_pid}/io")
            fi
            ps -p "${command_pid}" -o pid=,etime=,time=,pcpu=,pmem=,rss=,stat= \
                | awk -v label="${label}" -v elapsed="${elapsed}" -v io="${io_summary}" \
                    '{ printf "[progress] %s wall=%ss pid=%s elapsed=%s cpu_time=%s cpu=%.1f%% mem=%.1f%% rss_kb=%s state=%s %s\n", label, elapsed, $1, $2, $3, $4, $5, $6, $7, io }' \
                | tee -a "${log_file}"
        done
    ) &
    local monitor_pid=$!

    set +e
    wait "${command_pid}"
    local status=$?
    set -e
    kill "${monitor_pid}" 2>/dev/null || true
    wait "${monitor_pid}" 2>/dev/null || true
    return "${status}"
}

cd "${WORKDIR}"

source "${CONFIG_DIR}/setup.sh"
idea_use_local "${LOCAL_K4GEO}"
idea_use_local "${LOCAL_K4RECTRACKER}"
idea_use_local "${LOCAL_K4RECCALORIMETER}"

# Capture the rolling stack and exact local sources with every output file.
{
    printf 'stack_request=%s\nstack_view=%s\nstack_id=%s\nenable_ggtf=%s\n' \
        "${IDEA_STACK_REQUEST}" "${LCG_VIEW_DIR}" "${IDEA_STACK_ID}" "${ENABLE_GGTF}"
    for component in FCC-config k4geo-local k4RecTracker-local k4RecCalorimeter-local; do
        printf '%s=%s\n' "${component}" "$(git -C "${CONFIG_DIR}/${component}" rev-parse HEAD)"
    done
    sha256sum "${CONFIG_DIR}/run_sim.sh" "${CONFIG_DIR}/setup.sh" "${CONFIG_DIR}/pythia.py"
} > "${WORKDIR}/software_versions.txt"

DDSIM_ARGS=(
    --outputFile IDEA_sim.root
    --random.enableEventSeed
    --random.seed "${NUM}"
    --compactFile "${K4GEO}/FCCee/IDEA/compact/IDEA_o1_v03/IDEA_o1_v03.xml"
    --steeringFile "${TUTORIAL_DIR}/SteeringFile_IDEA_o1_v03.py"
)

if [[ "${SAMPLE}" == gun_* ]]; then
    if [[ -z "${GUN_PARTICLE}" ]]; then
        case "${SAMPLE}" in
            gun_mu_*) GUN_PARTICLE=mu- ;;
            gun_pi_*) GUN_PARTICLE=pi- ;;
            *) GUN_PARTICLE=e- ;;
        esac
    fi
    DDSIM_ARGS+=(
        --enableGun
        --gun.distribution "${GUN_DISTRIBUTION}"
        --gun.energy "${GUN_ENERGY}"
        --gun.particle "${GUN_PARTICLE}"
        --crossingAngleBoost 0.0
        --numberOfEvents "${NEV}"
    )
else
    cp "${PYTHIA_DIR}/pythia/${SAMPLE}.cmd" card.cmd
    printf '\nRandom:seed=%s\n' "${NUM}" >> card.cmd
    run_with_progress generation "${LOGDIR}/generation.log" k4run "${CONFIG_DIR}/pythia.py" \
        -n "${NEV}" \
        --Dumper.Filename out.hepmc \
        --Pythia8.PythiaInterface.pythiacard card.cmd
    DDSIM_ARGS+=(--inputFiles out.hepmc --numberOfEvents -1)
fi

run_with_progress simulation "${LOGDIR}/simulation.log" ddsim "${DDSIM_ARGS[@]}"

# Keep proxy tracks for the existing MLPF reader, alongside upstream's fitted
# tracks. Fitted-track supervision is a separate postprocessing development.
run_with_progress reconstruction "${LOGDIR}/reconstruction.log" k4run "${TUTORIAL_DIR}/run_digi_reco.py" \
    --IOSvc.Input IDEA_sim.root \
    --IOSvc.Output IDEA_sim_digi_reco.root \
    --addTruthTracks true --addRecoTracks "${ENABLE_GGTF}" \
    --trackingModel "${TRACKING_MODEL}"

if [[ -f ${TRACKING_MODEL} ]]; then
    sha256sum "${TRACKING_MODEL}" >> software_versions.txt
fi

test -s IDEA_sim_digi_reco.root
cp IDEA_sim_digi_reco.root "${FULLOUTDIR}/reco_${SAMPLE}_${NUM}.root"
cp software_versions.txt "${FULLOUTDIR}/reco_${SAMPLE}_${NUM}.software.txt"
