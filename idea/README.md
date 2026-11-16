# IDEA event generation

This pipeline uses `IDEA_o1_v03` with upstream simulation and reconstruction
checked on **16 November 2026**, plus local MLPF patches. The submodules pin:

| Component | Upstream base | Local changes |
|---|---|---|
| FCC-config | `955329110fe0dd51003f01d5e63176ed282c537d` | Fast optical transport; both readout truth links and named cluster channel energies |
| k4geo | `4013b50b4b951f6ec0ebff1c941ce02be0df4a2c` | Preserve Cherenkov-photon counts by charged parent in hit contributions |
| k4RecCalorimeter | `f0085b42a0461fb780c1fb8818f24d3e7463060c` | Optical digi-to-sim links; merge equal cell IDs; channel-energy metadata; empty-cell guard; energy-weight truth across merged readouts |
| k4RecTracker | `c1cceda0c74f62e1451b2a41282ca9e23fa88bfd` | Local build-directory ignores only; includes November GGTF and failed-fit fixes |

All component branches are `idea-upstream-2026-11`. Upstream's cellID-based
truth matching, indexed truth lookup, fast topoclustering and phi-wrapping fixes
are retained. The old April-stack API fallbacks are removed.

## Build

Use AlmaLinux 9 with CVMFS, CMake/Ninja and development headers. The default is
the current **LCG devkey-head GCC 16** view, sourced by `setup.sh`. The GCC 14
view available during this update contained dangling DD4hep links. The old
Key4HEP `2026-04-08` release is not supported by these sources.

The standard runtime image lacks some Geant4 development dependencies. To make
a local development image from it:

```bash
apptainer build --fakeroot mlpf/data/key4hep/gen/idea/idea-dev.sif \
  mlpf/data/key4hep/gen/idea/AlmaLinux9.def
```

Then, from a clean shell at the repository root:

```bash
git submodule update --init --recursive
apptainer exec --bind /cvmfs,"$PWD" mlpf/data/key4hep/gen/idea/idea-dev.sif \
  bash mlpf/data/key4hep/gen/idea/build_all.sh
```

The build order is geometry, tracking, calorimeter reconstruction. Every package
uses its own `build-local` and `install-local` directories. `BUILD_JOBS` defaults
to 4. To select a specific available nightly view, set `IDEA_STACK_RELEASE`
(`Mon`, `Tue`, etc.) and optionally `IDEA_STACK_COMPILER`; use the same values
for building and running.

The LCG view is rolling, even when selected by weekday. Each installation saves
a checksum of the view's setup script. The runner refuses installations built
against a different view checksum; rebuild all components after the nightly
changes. Each output ROOT file has a `.software.txt` companion recording the
view, checksum, component commits and tracking-model checksum. Archive these records with production.
The helper explicitly selects the local geometry XML as well as its plugins.

## Run

On this host, importing DDG4 with the 16 November GCC 16 view stalled while
reading its nightly `libffi` from CVMFS. Preloading the container's compatible
`libffi.so.8` allowed the import to complete. The commands below include that
local workaround; it does not replace or modify the CVMFS stack.

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
association. **The existing MLPF postprocessor still consumes the truth-seeded
collection.** Fitted-track supervision and reader support remain separate work;
the oracle `ycand` remains a pipeline check, not a physics baseline.

Set `ENABLE_GGTF=false` for a proxy-only diagnostic run. `TRACKING_MODEL` can
point to a cached GGTF ONNX file; otherwise upstream downloads its default
`SimpleGatrIDEAv3o1.onnx` model into the work directory. Validate that model on
the intended event energy and topology before treating tracking as established.
`GGTF_INFERENCE_THREADS` defaults to 4; `GGTF_SESSION_RECREATE_EVENTS` defaults
to 25 to bound ONNX Runtime's retained allocations for varying event hit counts.

Samples beginning with `gun_` use the DD4hep particle gun. Defaults are 10 GeV
`e-`, except `gun_mu_*` selects `mu-` and `gun_pi_*` selects `pi-`. Override with
`GUN_PARTICLE`, `GUN_ENERGY` and `GUN_DISTRIBUTION`. Other samples use the common
CLD Pythia cards with the local `pythia.py`, which uses current k4FWCore
event services and writes HepMC3 directly. Stage logs are under `${WORKDIR}/logs`; `LOGDIR` overrides this.

On the Tallinn site the batch entry point remains:

```bash
APPTAINERENV_LD_PRELOAD=/usr/lib64/libffi.so.8 \
  pixi run -m configs/tallinn/pixi.toml gen_idea
```

The batch runtime also uses this local image through `particleflow_spec.yaml`:
the current stack needs ICU libraries absent from the stock runtime image.
The generated `.sif` is ignored by Git and must be built on a fresh checkout. Final ROOT files follow
`${OUTDIR}/${process}/root/reco_${process}_${seed}.root`.

The new `particleflow_spec.yaml` production workspace is
`IDEA_o1_v03_upstream_20261116`, with TFDS version **0.3.0**. Regenerate simulation,
reconstruction, Parquet and TFDS; do not relabel old files. Existing 0.2.1 data
belongs to the previous campaign. The updated geometry/materials/field and
proxy-track selection change the distribution even though the tensor schema
and truth-seeded provenance remain compatible.

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

## Local validation (16 November 2026)

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
path, not realistic tracking or PF performance. `check_reco.py` always reports
track counts; pass `--require-fitted-tracks` when testing an event expected to
exercise the fitter. Validate the model and thresholds on representative
particle guns and 365 GeV jets before adopting fitted tracks for training.
