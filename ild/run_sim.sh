#!/bin/bash
# Run inside the IDEA AlmaLinux development container, with CVMFS mounted.
set -euo pipefail
SAMPLE=${1:?Usage: run_sim.sh PROCESS RANDOM_SEED}
NUM=${2:?Usage: run_sim.sh PROCESS RANDOM_SEED}
CONFIG_DIR=${CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
export ILD_CONFIG_DIR=${ILD_CONFIG_DIR:-${CONFIG_DIR}/ILDConfig}
NEV=${NEV:-100}
CMS_ENERGY=${CMS_ENERGY:-365}
OUTDIR=${OUTDIR:?Set OUTDIR to the production gen directory}
WORKDIR=${WORKDIR:?Set an empty WORKDIR; intermediate files are retained}
export IDEA_STACK_RELEASE=${IDEA_STACK_RELEASE:-Mon}
mkdir -p "${WORKDIR}" "${OUTDIR}/${SAMPLE}/root"
WORKDIR=$(realpath "${WORKDIR}")
OUTDIR=$(realpath "${OUTDIR}")
recipe_dir=${WORKDIR}/recipe
if [[ $(realpath "${BASH_SOURCE[0]}") != "${recipe_dir}/run_sim.sh" ]]; then
    mkdir "${recipe_dir}"
    cp "${CONFIG_DIR}"/*.py "${CONFIG_DIR}"/*.sh "${recipe_dir}/"
    export CONFIG_DIR
    exec bash "${recipe_dir}/run_sim.sh" "${SAMPLE}" "${NUM}"
fi
source "${CONFIG_DIR}/../idea/setup.sh"
geometry_assets=${K4GEO}
idea_use_local "${CONFIG_DIR}/../idea/k4geo-local"
idea_use_local "${CONFIG_DIR}/../idea/k4RecTracker-local"
test "$(git -C "${ILD_CONFIG_DIR}" rev-parse HEAD)" = fc1c9f58f9912b4d1fb10da5defbaca2133d60a0
git -C "${ILD_CONFIG_DIR}" diff --exit-code HEAD -- .
cd "${WORKDIR}"
trap 'status=$?; if (( status != 0 )); then echo "ILD job failed (${status}); logs retained in ${WORKDIR}" >&2; fi' EXIT
python "${recipe_dir}/stage_geometry.py" "${K4GEO}" "${WORKDIR}/geometry" --assets "${geometry_assets}"
export K4GEO=${WORKDIR}/geometry
{
    printf 'detector=ILD_FCCee_v02\nstack=%s\nstack_id=%s\nseed=%s\nevents=%s\ncms_energy=%s\n' \
        "${LCG_VIEW_DIR}" "${IDEA_STACK_ID}" "${NUM}" "${NEV}" "${CMS_ENERGY}"
    for repo in "${ILD_CONFIG_DIR}" "${CONFIG_DIR}/../idea/k4geo-local" "${CONFIG_DIR}/../idea/k4RecTracker-local"; do
        printf '%s=%s\n' "${repo}" "$(git -C "${repo}" rev-parse HEAD)"
        git -C "${repo}" diff | sha256sum
    done
    sha256sum "${recipe_dir}"/*.py "${recipe_dir}"/*.sh
    find geometry -type f \( -name '*.xml' -o -name '*.root' -o -name '*.stl' \) -print0 | sort -z | xargs -0 sha256sum
} > software.txt
sim_args=(--compactFile "${K4GEO}/FCCee/ILD_FCCee/compact/ILD_FCCee_v02/ILD_FCCee_v02.xml"
    --steeringFile "${ILD_CONFIG_DIR}/StandardConfig/production/ddsim_steer.py"
    --outputFile "${WORKDIR}/sim.edm4hep.root" --numberOfEvents "${NEV}"
    --random.enableEventSeed --random.seed "${NUM}" --crossingAngleBoost 0)
reco_args=(--detectorModel ILD_FCCee_v02 --inputFiles "${WORKDIR}/sim.edm4hep.root"
    --outputFileBase "${WORKDIR}/reco" --cmsEnergy "${CMS_ENERGY}"
    --noAIDA --noPFO --noBeamCalReco -n "${NEV}")
if [[ ${SAMPLE} == gun_* ]]; then
    case "${SAMPLE}" in
        gun_e_*) particle=e- ;;
        gun_mu_*) particle=mu- ;;
        gun_pi_*) particle=pi- ;;
        gun_gamma_*) particle=gamma ;;
        gun_kaon0L_*) particle=kaon0L ;;
        *) echo "Unknown particle-gun sample: ${SAMPLE}" >&2; exit 1 ;;
    esac
    sim_args+=(--enableGun --gun.particle "${GUN_PARTICLE:-${particle}}"
        --gun.energy "${GUN_ENERGY:-10*GeV}" --gun.distribution "${GUN_DISTRIBUTION:-uniform}")
    if [[ -n ${GUN_THETA_MIN:-} ]]; then
        sim_args+=(--gun.thetaMin "${GUN_THETA_MIN}")
    fi
    if [[ -n ${GUN_THETA_MAX:-} ]]; then
        sim_args+=(--gun.thetaMax "${GUN_THETA_MAX}")
    fi
    reco_args+=(--usingParticleGun)
else
    case "${SAMPLE}" in
        p8_ee_qq_ecm365|p8_ee_ttbar_ecm365|p8_ee_WW_fullhad_ecm365) ;;
        *) echo "Unsupported ILD physics sample: ${SAMPLE}" >&2; exit 1 ;;
    esac
    [[ ${CMS_ENERGY} == 365 ]] || { echo "365 GeV cards require CMS_ENERGY=365" >&2; exit 1; }
    cp "${CONFIG_DIR}/../cld/CLDConfig/pythia/${SAMPLE}.cmd" card.cmd
    printf '\nRandom:seed=%s\n' "${NUM}" >> card.cmd
    k4run "${CONFIG_DIR}/../idea/pythia.py" -n "${NEV}" --Dumper.Filename "${WORKDIR}/events.hepmc" \
        --Pythia8.PythiaInterface.pythiacard "${WORKDIR}/card.cmd" > generation.log 2>&1
    sim_args+=(--inputFiles "${WORKDIR}/events.hepmc")
fi
{
    printf 'simulation_command='; printf '%q ' ddsim "${sim_args[@]}"; printf '\n'
    printf 'reconstruction_command='; printf '%q ' k4run "${recipe_dir}/reconstruct.py" "${reco_args[@]}"; printf '\n'
    [[ ! -f card.cmd ]] || sha256sum card.cmd
} >> software.txt
ddsim "${sim_args[@]}" > simulation.log 2>&1
k4run "${recipe_dir}/reconstruct.py" "${reco_args[@]}" > reconstruction.log 2>&1
output=${OUTDIR}/${SAMPLE}/root/reco_${SAMPLE}_${NUM}.root
test -s reco_REC.edm4hep.root
cp reco_REC.edm4hep.root "${output}.partial"
mv "${output}.partial" "${output}"
cp software.txt "${output}.software.txt"
