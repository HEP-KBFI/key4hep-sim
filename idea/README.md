# IDEA event generation

This directory runs the official `IDEA_o1_v03` full-simulation,
digitization, and reconstruction workflow from the pinned `FCC-config`
submodule. The detector XML and plugins are supplied by the `K4GEO`
installation in the Key4HEP nightly environment.

From the repository root on the Tallinn site:

```bash
git submodule update --init --recursive
pixi run -m configs/tallinn/pixi.toml gen_idea
```

To restrict or batch the Snakemake jobs, set the same variables accepted by
the generic `gen` task, for example `BATCH=1/10` or `CORES=4`.

The `gun_e_10gev` sample is a one-event, 10 GeV electron-gun validation. Any
process name beginning with `gun_` selects the DD4hep particle gun instead of
Pythia. For local tests, its settings can be overridden with
`GUN_PARTICLE`, `GUN_ENERGY`, and `GUN_DISTRIBUTION`:

```bash
NEV=1 GUN_PARTICLE=pi- GUN_ENERGY='5*GeV' \
OUTDIR=/tmp/idea-gun/output WORKDIR=/tmp/idea-gun/work \
bash mlpf/data/key4hep/gen/idea/run_sim.sh gun_pi_5gev 424242
```

Stage logs are written to `${WORKDIR}/logs/generation.log` (for Pythia
samples), `${WORKDIR}/logs/simulation.log`, and
`${WORKDIR}/logs/reconstruction.log`. The progress heartbeat is included in
these files. Set `LOGDIR` to put them elsewhere.

IDEA uses local builds of k4geo and k4RecCalorimeter. The k4geo patch retains
detected Cherenkov-photon counts grouped by their charged Geant4 parent and
writes them as `SimCalorimeterHitContribution`s. The optical SiPM digitizer
then writes digi-hit to sim-hit links, allowing `CreateTruthLinks` to combine
scintillation and Cherenkov truth contributions. Build the local packages
with:

```bash
bash mlpf/data/key4hep/gen/idea/build_k4geo.sh
bash mlpf/data/key4hep/gen/idea/build_k4reccalorimeter.sh
```

`run_sim.sh` activates both installations and fails early with the relevant
build instruction if either is missing. Existing simulation files must be
regenerated: older `DRcaloSiPMreadoutSimHit` collections contain no Cherenkov
MC-particle contributions.

The final files follow the common Key4HEP layout:

```text
${workspace_dir}/gen/${process_name}/root/reco_${process_name}_${seed}.root
```

This campaign is intentionally marked `generation_only` in
`particleflow_spec.yaml`. The current official IDEA reconstruction produces
fitted tracks and dual-readout topoclusters, but it does not yet produce the
particle-flow collections and truth associations required by the shared MLPF
postprocessor.
