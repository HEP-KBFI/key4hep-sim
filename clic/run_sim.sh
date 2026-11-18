#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

df -h

export GENERATOR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NEV=${NEV:-100}
export SAMPLE=$1 #main card
export NUM=$2 #random seed
case "${SAMPLE}" in
    p8_ee_Z_qq_ecm91|p8_ee_Z_tautau_ecm91) COLLIDER=fccee ;;
    *) COLLIDER=clic ;;
esac

#Change these as needed
export OUTDIR=${OUTDIR:-/local/joosep/clic_edm4hep/v1.4.0/}
export CONFIG_DIR=${CONFIG_DIR:-${GENERATOR_ROOT}/clic}
export WORKDIR=${WORKDIR:-/scratch/local/$USER/${SAMPLE}_${SLURM_JOB_ID}}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p "$FULLOUTDIR/root"

mkdir -p $WORKDIR

# Ensure cleanup on exit, even if the job fails
cleanup() {
    if [ ! -z "$WORKDIR" ] && [ "$WORKDIR" != "/scratch/local/$USER" ] && [ "$WORKDIR" != "/scratch/local/$USER/" ]; then
        echo "Cleaning up scratch directory $WORKDIR"
        rm -Rf $WORKDIR
    fi
}
trap cleanup EXIT

cd $WORKDIR

cp -R "$CONFIG_DIR" ./

#prepare the gen-sim-reco script
echo "
#!/bin/bash
set -e
source '${GENERATOR_ROOT}/setup.sh'
source '${GENERATOR_ROOT}/stage_logging.sh'
key4hep_write_manifest software.txt
ls `pwd`
run_stage generation bash '${GENERATOR_ROOT}/generators/generate_events.sh' '${SAMPLE}' '${NUM}' '${NEV}' '${COLLIDER}'
cat generation.software.txt >> software.txt
run_stage simulation ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/CLIC/compact/CLIC_o3_v14/CLIC_o3_v14.xml --steeringFile clic/CLICPerformance/clicConfig/clic_steer.py
cd clic/CLICPerformance/clicConfig
run_stage reconstruction k4run $WORKDIR/clic/clicRec_e4h_input.py --gaudi-input $WORKDIR/out_SIM.root --gaudi-output $WORKDIR/out_RECO.root --num-events -1
" > sim.sh

cat sim.sh

#execute the gen-sim-reco step
export PYTHONPATH=$(pwd)/CLICPerformance:$PYTHONPATH
bash sim.sh

ls *.root

#Copy the outputs
cp out_RECO.root $FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.root

cp software.txt "$FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.software.txt"
