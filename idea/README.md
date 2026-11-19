# IDEA

`run_sim.sh SAMPLE SEED` generates, simulates, digitizes and reconstructs
`IDEA_o1_v03` events with the pinned FCC-config steering and local patches:

| Component | Branch `idea-upstream-2026-11` | Local changes |
|---|---|---|
| FCC-config | fork of `955329110fe0dd51003f01d5e63176ed282c537d` | Fast optical transport; readout truth links and named channel energies |
| k4geo | fork of `4013b50b4b951f6ec0ebff1c941ce02be0df4a2c` | Cherenkov-photon counts kept per charged parent in hit contributions |
| k4RecCalorimeter | fork of `f0085b42a0461fb780c1fb8818f24d3e7463060c` | Optical digi-to-sim links, merged cell IDs, channel-energy metadata, energy-weighted truth |
| k4RecTracker | fork of `c1cceda0c74f62e1451b2a41282ca9e23fa88bfd` | Circle-seed orientation from the ordered hit path; GENFIT's fitted charge in the output; EDM4hep 1.0 TrackState lookup |

Build everything with the [shared instructions](../README.md); `build_all.sh`
also downloads the GGTF model `SimpleGatrIDEAv3o1.onnx` into `.local/models/`.

## Options

| Variable | Default | Meaning |
|---|---|---|
| `ENABLE_GGTF` | `true` | Run GGTF track finding and GenFit fitting (`FittedTracks`). `false` keeps only the truth-seeded proxy tracks, for diagnostics. |
| `TRACKING_MODEL` | `.local/models/SimpleGatrIDEAv3o1.onnx` | GGTF ONNX model; the job refuses to start without it. |
| `PROGRESS_INTERVAL` | off | Seconds between progress lines with CPU, memory and I/O of the running stage. |
| `LOGDIR` | `WORKDIR/logs` | Stage log directory. |
| `GUN_PARTICLE`, `GUN_ENERGY`, `GUN_DISTRIBUTION` | by sample, `10*GeV`, `uniform` | Particle-gun settings for `gun_*` samples. |

Example smoke test from a particleflow checkout:

```bash
apptainer exec --bind /cvmfs,"$PWD",/tmp --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  mlpf/data/key4hep/gen/idea/idea-dev.sif \
  env NEV=1 OUTDIR=/tmp/idea-smoke/output WORKDIR=/tmp/idea-smoke/work PROGRESS_INTERVAL=60 \
  bash mlpf/data/key4hep/gen/idea/run_sim.sh gun_e_10gev 424242
```

## Output

The reconstruction writes fitted `FittedTracks` (with original hit references,
used by MLPF) and `FittedTracksWithFilteredHits`, the proxy
`TracksFromGenParticles` with its truth association, dual-readout
`TopoClusterAll` clusters with cell and MC-particle links, and the optical
digi-to-sim links. Clusters carry the raw Cherenkov plus scintillation energy
with the two channel sums as shape parameters. The manifest records the stack,
component commits, generator cards and the tracking model checksum.

MLPF postprocessing selects `FittedTracks` at the interaction point and
derives training labels from tracker-hit truth links; see
`docs/datasets/idea.md` in particleflow. Proxy-only outputs need
`--idea-track-source truth_seeded` there and are not interchangeable with
fitted data.

## Checks

`tests/check_truth_links.py WORKDIR` runs the installed `CreateTruthLinks`
plugin on synthetic dual-readout cells (copied cells, shared cell IDs, unequal
channel energies, missing truth, empty cells). `tests/check_reco.py FILE`
verifies collection presence, fitted-track quality, channel and cluster energy
closure and truth-weight closure on a reconstructed file; add
`--require-fitted-tracks` for events that must contain fitted tracks, or
`--proxy-only` for `ENABLE_GGTF=false` output. Run both inside the IDEA
environment:

```bash
source idea/setup.sh
for p in k4geo k4RecTracker k4RecCalorimeter; do idea_use_local "idea/$p-local"; done
python idea/tests/check_truth_links.py /tmp/idea-truth-check
python idea/tests/check_reco.py /tmp/idea-smoke/output/gun_e_10gev/root/reco_gun_e_10gev_424242.root
```

Successful execution does not establish tracking efficiency or particle-flow
performance; validate the model and the clustering on representative samples
before physics use. The September 2025 status summary is kept in
`docs/IDEA_particle_flow_status.md` for reference.
