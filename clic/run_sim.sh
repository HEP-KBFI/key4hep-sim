#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

env
df -h

export NEV=${NEV:-100}
export SAMPLE=$1 #main card
export NUM=$2 #random seed

#Change these as needed
export OUTDIR=${OUTDIR:-/local/joosep/cld_edm4hep/v1.2.2_key4hep_2025-05-29_CLD_3edac3/}
export CONFIG_DIR=${CONFIG_DIR:-/home/joosep/particleflow/mlpf/data/key4hep/gen/clic}
export WORKDIR=${WORKDIR:-/scratch/local/$USER/${SAMPLE}_${SLURM_JOB_ID}}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p $FULLOUTDIR

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

cp $CONFIG_DIR/pythia/${SAMPLE}.cmd card.cmd
cp -R $CONFIG_DIR ./

#add seed to pythia card
echo "Random:seed=${NUM}" >> card.cmd
cat card.cmd

#prepare the gen-sim-reco script
echo "
#!/bin/bash
set -e
source /cvmfs/sw.hsf.org/key4hep/setup.sh -r 2025-05-29
env
ls `pwd`
k4run ./pythia.py -n $NEV --Dumper.Filename out.hepmc --Pythia8.PythiaInterface.pythiacard card.cmd
ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/CLIC/compact/CLIC_o3_v14/CLIC_o3_v14.xml --steeringFile clic/CLICPerformance/clicConfig/clic_steer.py
k4run clicRec_e4h_input.py --inputFiles out_SIM.root --outputBasename out_RECO --num-events -1
" > sim.sh

cat sim.sh

#execute the gen-sim-reco step
export PYTHONPATH=$(pwd)/CLICPerformance:$PYTHONPATH
bash sim.sh

ls *.root

#Copy the outputs
cp out_RECO_REC.edm4hep.root $FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.root
