#!/bin/bash
# Generate, simulate, digitize, and reconstruct FCC-ee IDEA events.
set -euo pipefail
set -x

NEV=${NEV:-100}
PROGRESS_INTERVAL=${PROGRESS_INTERVAL:-9999999}
GUN_PARTICLE=${GUN_PARTICLE:-}
GUN_ENERGY=${GUN_ENERGY:-10*GeV}
GUN_DISTRIBUTION=${GUN_DISTRIBUTION:-uniform}
SAMPLE=${1:?Usage: run_sim.sh PROCESS_NAME RANDOM_SEED}
NUM=${2:?Usage: run_sim.sh PROCESS_NAME RANDOM_SEED}
OUTDIR=${OUTDIR:?OUTDIR must point at the production gen directory}
CONFIG_DIR=${CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
LOCAL_K4RECCALORIMETER=${LOCAL_K4RECCALORIMETER:-${CONFIG_DIR}/k4RecCalorimeter-local}
LOCAL_K4GEO=${LOCAL_K4GEO:-${CONFIG_DIR}/k4geo-local}
WORKDIR=${WORKDIR:-/scratch/local/${USER}/${SAMPLE}_${SLURM_JOB_ID:-manual}}
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

# KEY4HEP_STACK can remain set in a partial or stale shell environment even
# when required helpers such as k4_local_repo are unavailable. Test the actual
# commands used by this workflow and source the pinned release when needed.
if ! command -v k4_local_repo >/dev/null 2>&1 || \
   ! command -v k4run >/dev/null 2>&1 || \
   ! command -v ddsim >/dev/null 2>&1; then
    # Key4HEP's setup script probes optional unset variables and is not
    # compatible with nounset. Clear a stale stack marker as the setup script
    # otherwise assumes initialization has already completed.
    set +u
    unset KEY4HEP_STACK
    source /cvmfs/sw.hsf.org/key4hep/setup.sh -r 2026-04-08
    set -u
fi

# Load the local k4geo Geant4 plugin before simulation. It preserves detected
# Cherenkov-photon counts by charged parent in SimCalorimeterHit contributions.
if [[ -d "${LOCAL_K4GEO}/install-local" ]]; then
    previous_dir=${PWD}
    cd "${LOCAL_K4GEO}"
    k4_local_repo install-local
    cd "${previous_dir}"
else
    echo "Missing local k4geo installation: ${LOCAL_K4GEO}/install-local" >&2
    echo "Build it with ${CONFIG_DIR}/build_k4geo.sh" >&2
    exit 1
fi

# Prefer the locally patched k4RecCalorimeter. Entering its source directory is
# required because k4_local_repo resolves the install path relative to $PWD.
if [[ -d "${LOCAL_K4RECCALORIMETER}/install-local" ]]; then
    previous_dir=${PWD}
    cd "${LOCAL_K4RECCALORIMETER}"
    k4_local_repo install-local
    cd "${previous_dir}"
else
    echo "Missing local k4RecCalorimeter installation: ${LOCAL_K4RECCALORIMETER}/install-local" >&2
    echo "Build it with ${CONFIG_DIR}/build_k4reccalorimeter.sh" >&2
    exit 1
fi

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
    run_with_progress generation "${LOGDIR}/generation.log" k4run "${PYTHIA_DIR}/pythia.py" \
        -n "${NEV}" \
        --Dumper.Filename out.hepmc \
        --Pythia8.PythiaInterface.pythiacard card.cmd
    DDSIM_ARGS+=(--inputFiles out.hepmc --numberOfEvents -1)
fi

run_with_progress simulation "${LOGDIR}/simulation.log" ddsim "${DDSIM_ARGS[@]}"

# Required by the DCH digitization. The tracking model is fetched by the
# official reconstruction job itself.
wget -nv --no-clobber \
    https://fccsw.web.cern.ch/fccsw/filesForSimDigiReco/IDEA/DataAlgFORGEANT.root

run_with_progress reconstruction "${LOGDIR}/reconstruction.log" k4run "${TUTORIAL_DIR}/run_digi_reco.py" \
    --IOSvc.Input IDEA_sim.root \
    --IOSvc.Output IDEA_sim_digi_reco.root

test -s IDEA_sim_digi_reco.root
cp IDEA_sim_digi_reco.root "${FULLOUTDIR}/reco_${SAMPLE}_${NUM}.root"
