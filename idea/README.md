# IDEA event generation

This pipeline uses `IDEA_o1_v03` with upstream simulation and reconstruction
checked on **16 November 2026**, plus local MLPF patches. The submodules pin:

| Component | Upstream base | Local changes |
|---|---|---|
| FCC-config | `955329110fe0dd51003f01d5e63176ed282c537d` | Fast optical transport; both readout truth links and named cluster channel energies |
| k4geo | `4013b50b4b951f6ec0ebff1c941ce02be0df4a2c` | Preserve Cherenkov-photon counts by charged parent in hit contributions |
| k4RecCalorimeter | `f0085b42a0461fb780c1fb8818f24d3e7463060c` | Optical digi-to-sim links; merge equal cell IDs; channel-energy metadata; empty-cell guard; energy-weight truth across merged readouts |
| k4RecTracker | `c1cceda0c74f62e1451b2a41282ca9e23fa88bfd` | Ordered-hit circle-seed orientation and actual fitted-charge output; includes November GGTF and failed-fit fixes |

All component branches are `idea-upstream-2026-11`. Upstream's cellID-based
truth matching, indexed truth lookup, fast topoclustering and phi-wrapping fixes
are retained. The tracker includes a compatibility helper for the explicit
TrackState locations in stable EDM4hep 1.0.

## Build

All four detector recipes use **stable Key4hep 2026-04-08 (GCC 14.2)**,
with locally compiled **k4FWCore v01-06** and **MarlinReco v01-38-01**.
The framework supplies the collection-metadata APIs required by the current
calorimeter code. MarlinReco includes the upstream TOF crash fix required by
ILD. See the [shared build instructions](../README.md) for exact pins, build
commands, cache checks and compatibility-test results.

Build the development image once, then compile the shared runtime and detector
packages from a clean shell at the particleflow repository root:

```bash
apptainer build --fakeroot mlpf/data/key4hep/gen/idea/idea-dev.sif \
  mlpf/data/key4hep/gen/idea/AlmaLinux9.def
git submodule update --init --recursive
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  mlpf/data/key4hep/gen/idea/idea-dev.sif \
  bash mlpf/data/key4hep/gen/build_all.sh
```

Builds and installations live under `gen/.local/2026-04-08/`; previous nightly
builds are separate. `BUILD_JOBS` defaults to 4. Each installation records its
source commit and the stable-stack/framework identity. The runner refuses stale
or modified source installations. ROOT software manifests record the stable
release, stack checksum, framework and Marlin pins, detector commits and model
checksum. Preserve these records with production.

## Run

The commands preload the container's `libffi.so.8` to avoid CVMFS library
loading stalls observed on this host.

For a one-event electron smoke test, keeping logs and intermediate files:

```bash
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 mlpf/data/key4hep/gen/idea/idea-dev.sif \
  env NEV=1 OUTDIR=/tmp/idea-smoke/output WORKDIR=/tmp/idea-smoke/work \
  PROGRESS_INTERVAL=60 \
  bash mlpf/data/key4hep/gen/idea/run_sim.sh gun_e_10gev 424242
```

The runner produces upstream GGTF/GenFit `FittedTracks` and
`FittedTracksWithFilteredHits`, alongside `TracksFromGenParticles` and its truth
association. **MLPF postprocessing defaults to quality-selected `FittedTracks`.** Tracker-hit
simulation links provide training labels at 75% majority purity, without
replacing measured kinematics. Invalid fits are removed using reconstructed
quality; low-purity tracks and secondaries remain inputs without a primary
representative label. The oracle `ycand` remains a pipeline check, not a physics
baseline.

Set `ENABLE_GGTF=false` for a proxy-only diagnostic run. `TRACKING_MODEL` can
point to a cached GGTF ONNX file; otherwise upstream downloads its default
`SimpleGatrIDEAv3o1.onnx` model into the work directory. Validate that model on
the intended event energy and topology before treating tracking as established.
`GGTF_INFERENCE_THREADS` defaults to 4; `GGTF_SESSION_RECREATE_EVENTS` defaults
to 25 to bound ONNX Runtime's retained allocations for varying event hit counts.

Samples beginning with `gun_` use the DD4hep particle gun. Defaults are 10 GeV
`e-`, except `gun_mu_*` selects `mu-` and `gun_pi_*` selects `pi-`. Override with
`GUN_PARTICLE`, `GUN_ENERGY` and `GUN_DISTRIBUTION`. Other samples use the common
FCC-ee cards and the shared `../pythia/generate.py` steering, which uses
k4FWCore event services and writes HepMC3 directly. Stage logs are under `${WORKDIR}/logs`; `LOGDIR` overrides this.

On the Tallinn site the batch entry point remains:

```bash
APPTAINERENV_LD_PRELOAD=/usr/lib64/libffi.so.8 \
  pixi run -m configs/tallinn/pixi.toml gen_idea
```

The batch runtime also uses this local image through `particleflow_spec.yaml`:
the development image supplies the dependencies used to build the overlays.
The generated `.sif` is ignored by Git and must be built on a fresh checkout. Final ROOT files follow
`${OUTDIR}/${process}/root/reco_${process}_${seed}.root`.

The new `particleflow_spec.yaml` production workspace is
`IDEA_o1_v03_key4hep_2026-04-08_core1.6_beamspot2025`, with TFDS version
**0.4.0**. Regenerate reconstruction, Parquet and TFDS: development
`FittedTracks` produced before the tracking fix need refitting. Stored simulation or GGTF candidates can be reused.
The published 0.2.1/0.3.0 data and intermediate upstream-update recipe
use proxy tracks and must not be relabelled as fitted data.

## Check the local truth patch

After building, run the synthetic regression using the installed Gaudi plugin:

```bash
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 mlpf/data/key4hep/gen/idea/idea-dev.sif bash -c '
  set -euo pipefail
  config_dir="$PWD/mlpf/data/key4hep/gen/idea"
  source "$config_dir/setup.sh"
  idea_use_local "$config_dir/k4geo-local"
  idea_use_local "$config_dir/k4RecCalorimeter-local"
  python "$config_dir/tests/check_truth_links.py" /tmp/idea-truth-check
'
```

This checks copied cluster cells, equal IDs in two readouts, unequal channel
energies, absent truth contributions and empty digitized cells. Also run an
actual simulation/reconstruction smoke test before starting a campaign. IDEA
option 2 is available in the upstream sources but is not selected by this runner.

For the generated electron file, check collection presence, fitted-track quality,
channel/cluster/cell energy closure and cluster truth-weight closure with
`tests/check_reco.py /tmp/idea-smoke/output/gun_e_10gev/root/reco_gun_e_10gev_424242.root`
in the same IDEA environment. Use `--proxy-only` if GGTF was disabled.

## Upstream-update validation (16 November 2026, before the fitted reader)

- All three C++ packages built and installed in the GCC 16 nightly view.
- One 365 GeV ttbar event generated to HepMC3 with the local Pythia steering.
- The synthetic truth-link regression passed for copied cells, shared cell IDs,
  unequal channel energies, missing truth and empty channels.
- A 10 GeV electron (`seed=424242`) completed full simulation and reconstruction.
  The event has one proxy track and 102 clusters. Channel sums and cluster-cell
  energies close; energy-weighted truth coverage is 99.5997%. Small unlabelled
  satellite clusters are permitted by the SiPM noise model; individual truth
  fractions are checked to remain within [0, 1] to floating-point precision.
- ROOT-to-Parquet postprocessing and the MLPF loader passed, with finite input
  tensors `(103, 19)` and target/oracle tensors `(103, 14)`.
- The focused Python/configuration suite passed 35 tests; one historical-data
  test was skipped because its local Parquet fixture is absent.

**Tracking limitation:** the upstream model at its default thresholds returned
zero GGTF candidates for this electron event. GenFit was configured and ran,
but had no tracks to fit. This validates execution and the proxy-track data
path in the intermediate upstream-update recipe, not realistic tracking or PF performance. Current
0.4.x postprocessing uses only fitted inputs, so an event with no fitted tracks
has an empty track input. `check_reco.py` always reports
track counts; pass `--require-fitted-tracks` when testing an event expected to
exercise the fitter. Validate the model and thresholds on representative
particle guns and 365 GeV jets before adopting fitted tracks for training.

## Use fitted tracks for MLPF

Existing updated ROOT files can be postprocessed directly:

```bash
uv run python mlpf/data/key4hep/postprocessing.py \
  --detector idea --idea-track-source fitted \
  --input /path/to/reco.root --outpath /path/to/new-fitted-parquet
```

This reads `FittedTracks`, selects its unique IP state, and requires finite
parameters, nonnegative chi2, positive NDF and associated hits. The inputs do
not use `TracksFromGenParticles` or the truth-parametrized dN/dx collection.
`FittedTracks` retains original measurement references, allowing hit-truth
matching; the filtered-hit output instead contains fitted-hit clones without
corresponding original sim-hit links.

Input selection has no truth cuts. MC information is used only for labels:
one direct charged status-1 particle must own at least 75% of distinct track
measurements. Unlinked measurements count against purity. Tracks matched to
secondaries do not acquire an ancestor's charge or momentum. Duplicate primary
matches choose one representative by purity, hit count and fit quality; input
order and measured parameters are preserved.

The postprocessor records source, collection, quality/truth policies and
raw/rejected/matched track counts in Parquet. The 0.4.x TFDS builders validate
this provenance and rejects legacy or mixed inputs. The preparation helper
also preserves provenance instead of relabelling proxy data.

Before the tracking fix, the three-event ttbar validation retained 47 of 50 stored fitted tracks
(21/11/15), with 40 direct primary labels (18/10/12). ROOT-to-Parquet, finite
MLPF tensors, and an actual 0.4.0 ArrayRecord TFDS build/read passed. Fitting
outliers remain in the accepted measured inputs; tracking performance still
needs validation, and ycand remains a target oracle. The postprocessing-only change did not require new simulation; the 0.4.0
tracking fix additionally requires refitting unpatched tracks.

`ENABLE_GGTF=false` is now suitable only for explicit legacy proxy diagnostics;
postprocessing such outputs requires `--idea-track-source truth_seeded` and
legacy builders/loader overrides. The fitted path never falls back implicitly.

## GenFit orientation and charge fix (0.4.0)

The local tracker uses the signed angular progression of the full ordered hit
path for the circle-seed direction, rather than the direction from the fitted
PCA to the second hit. It serializes GENFIT's fitted charge, including the
helix covariance and calorimeter extrapolation, rather than retaining the
seed charge after a q/p sign change.

On the same 100 ttbar events and 3,046 stored GGTF candidates, refitting reduced
nearly reversed primary representatives from 137/1,335 (10.26%) to 3/1,349
(0.22%). Accepted track inputs increased from 1,543 to 1,567. No MC information
is used in either correction. Overall direction alignment improved from
69.51% to 80.58%, so the 95% quality gate is still not met. Three low-pT
reversals and other fit outliers remain; the oracle baseline is unchanged.

The tracker includes `test_FastCircleSeed`, enabled by `BUILD_TESTING=ON`, with
synthetic arc tests and measured hit coordinates from a reversed candidate.
These tests need no external event file or tracking model. The refit study,
native charge audit and before/after ROOT files are in the parent project's
`reports/idea-tracking-fix-20261117/` directory.

## Generator correction from particleflow PR #527

The shared CLDConfig cards now use energy-dependent FCC-ee 2025 vertex widths.
The current-service IDEA/ILD wrapper applies no additional GenAlg spatial or
timing smear. At 365 GeV the card widths are 26.17 µm, 31.1 nm and 1.198 mm
in x, y and z. Generate fresh ROOT files in the `beamspot2025` workspace; older
ROOT/Parquet/TFDS outputs retain their original vertex distribution. The
November native stack and local component pins are unchanged by this merge.
