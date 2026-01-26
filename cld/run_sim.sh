#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

env
df -h

export NEV=500
export NUM=$1 #random seed
export SAMPLE=$2 #main card

#Change these as needed
export OUTDIR=/local/joosep/cld_edm4hep/key4hep_2025-05-29_CLD_b3b459/
export SIMDIR=/home/joosep/key4hep-sim/cld/CLDConfig/CLDConfig
export WORKDIR=/scratch/local/$USER/${SAMPLE}_${SLURM_JOB_ID}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p $FULLOUTDIR

mkdir -p $WORKDIR
cd $WORKDIR

cp $SIMDIR/${SAMPLE}.cmd card.cmd
cp $SIMDIR/pythia.py ./
cp $SIMDIR/cld_steer.py ./
cp -R $SIMDIR/PandoraSettingsCLD ./
cp -R $SIMDIR/CLDReconstruction.py ./

echo "Random:seed=${NUM}" >> card.cmd
cat card.cmd

echo "
#!/bin/bash
set -e
source /cvmfs/sw.hsf.org/key4hep/setup.sh -r 2025-05-29
env
k4run pythia.py -n $NEV --Dumper.Filename out.hepmc --Pythia8.PythiaInterface.pythiacard card.cmd
ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/FCCee/CLD/compact/CLD_o2_v07/CLD_o2_v07.xml --steeringFile cld_steer.py
k4run CLDReconstruction.py --inputFiles out_SIM.root --outputBasename out_RECO --num-events -1
" > sim.sh

cat sim.sh

singularity exec -B /cvmfs -B /scratch -B /local /home/software/singularity/alma9.simg bash sim.sh

#Copy the outputs
cp out_RECO_edm4hep.root $FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.root

rm -Rf $WORKDIR
