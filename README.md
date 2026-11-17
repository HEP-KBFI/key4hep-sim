# key4hep-sim

Full Geant4 simulation and reconstruction recipes for CLD, CLIC, IDEA and ILD
at FCC-ee, using pinned detector sources and a common stable Key4hep runtime.
The upcoming simulation software release is **v1.4.0**; its tag is not yet created.

## Shared stable runtime

CLD, CLIC, ILD and IDEA use `setup.sh` with stable **2026-04-08**, GCC 14.2,
Gaudi 40r2, EDM4hep 1.0 and PODIO 1.7. All use the same two local overlays:

| Package | Released version | Pinned commit | Reason |
|---|---|---|---|
| k4FWCore | v01-06 (1.6) | `2747ab63f5a408f0904c5d7e644fd9078394b8f1` | Collection-metadata APIs for current k4RecCalorimeter; retains PodioDataSvc for CLD/CLIC |
| MarlinReco | v01-38-01 (1.38.1) | `fe8e9e2d08b47048e639c072b7bce97f9847f7d1` | Upstream TOF fix for tracks without subtracks (`359f74f9`) |

Neither package needs source patches. Newer k4FWCore releases requiring Gaudi
41 are unsuitable for this stable base. IDEA/ILD additionally use the pinned
geometry/tracker forks; IDEA uses the calorimeter fork. The tracker fork has a
small EDM4hep 1.0 TrackState lookup compatibility helper, preserving explicit
IP-state selection, and a PODIO 1.7 test-writer compatibility change.

## Build from a standalone checkout

Requirements: Linux, readable `/cvmfs/sw.hsf.org`, Apptainer with fakeroot
(or an equivalent AlmaLinux 9 build environment), Git, and internet access for
submodules and the IDEA tracking model. Reserve several GB for source/build
files and considerably more space for simulation outputs. The development
image installs the headers needed by the stable Geant4 CMake configuration.

The commands below target `v1.4.0` once its tag is published. Until then, use
`--branch idea-upstream-2026-11` in the clone command to test the release branch.

```bash
git clone --branch v1.4.0 --recurse-submodules https://github.com/HEP-KBFI/key4hep-sim.git key4hep-sim-v1.4.0
cd key4hep-sim-v1.4.0
git submodule update --init --recursive
apptainer build --fakeroot idea/idea-dev.sif idea/AlmaLinux9.def
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif bash build_all.sh
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif bash check_runtime.sh
```

In a particleflow checkout, run the same commands from
`mlpf/data/key4hep/gen/`. Its `scripts/check_ild_runtime.sh` wrapper runs the
same native check. Build once on the execution host before submitting jobs.

`build_all.sh` builds framework, MarlinReco, geometry, tracking, then calorimeter
reconstruction. CLD/CLIC alone need only `build_overlays.sh`. Builds use Ninja,
RelWithDebInfo and four workers (`BUILD_JOBS` overrides). Shared installations
are under `.local/2026-04-08/install/`, separate from old nightly builds.
A clean shell/container is required: rolling views and mixed releases are
rejected. `KEY4HEP_RELEASE` defaults to `2026-04-08`; main's legacy
`KEY4HEP_VERSION` name is accepted when it agrees. Other dated releases need
their own builds and compatibility tests. Do not rebuild a shared prefix while
jobs are running.

Each install records the stable setup checksum, framework identity and source
commit. Modified sources and mismatched builds are rejected on activation.
Jobs record the stable release and overlay commits in their software manifests.
Compiled files and the container are ignored by Git and must be built on each
execution host. In particleflow, the four primary productions select this
runtime and fresh workspace names. Archive old `snakemake_jobs/DETECTOR/`
completion markers before regenerating those workflows. Historical scan
productions retain their original runtime settings.

## Generate events

Run each job inside the same development image, with a private, empty work
directory and a shared output directory. Start from a clean host shell.
For example, from this repository root:

```bash
detector=cld  # cld, idea or ild; use clic with the 380 GeV sample below
sample=p8_ee_qq_ecm365
mkdir -p "output/v1.4.0/$detector" "work/v1.4.0/$detector"
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif env NEV=3 OUTDIR="$PWD/output/v1.4.0/$detector" \
  WORKDIR="$PWD/work/v1.4.0/$detector" bash "$detector/run_sim.sh" "$sample" 12345
```

| Detector | Geometry | Collision sample examples |
|---|---|---|
| CLD | CLD_o2_v07 | `p8_ee_qq_ecm365`, `p8_ee_ttbar_ecm365`, `p8_ee_WW_fullhad_ecm365` |
| IDEA | IDEA_o1_v03 | Same FCC-ee samples and cards as CLD |
| ILD | ILD_FCCee_v02 | Same three FCC-ee samples, 365 GeV, 2 T |
| CLIC | CLIC_o3_v14 | `p8_ee_qq_ecm380`, `p8_ee_ttbar_ecm380`, `p8_ee_WW_fullhad_ecm380` |

Outputs are `OUTDIR/SAMPLE/root/reco_SAMPLE_SEED.root` plus a software manifest.
Use distinct seeds and work directories for concurrent jobs. IDEA downloads its
GGTF model unless `TRACKING_MODEL` points to a cached copy. The IDEA/ILD recipes
preserve evidence outside production scratch; inspect logs on any failure.
See [IDEA](idea/README.md) and [ILD](ild/README.md) for tracking and target caveats.

### Shared FCC-ee generation

**CLD, IDEA and ILD use exactly the same cards and generator steering.**
`pythia/fccee` is a symlink to the pinned `cld/CLDConfig/pythia` directory: there
are no detector-specific FCC-ee card copies. Update that submodule to change
cards for all three. `generators/generate_events.sh` stages a private `card.cmd`,
adds the seed, invokes `pythia/generate.py` with the same event service, and
records source/staged card hashes in the output software manifest.
The cards supply FCC-ee 2025 vertex widths; no additional GenAlg smearing is
applied. CLIC shares the generator steering but uses `pythia/clic` for its
380 GeV collision settings. Comparing 365 and 380 GeV is not a fixed-energy
detector comparison.

The merge of `main` retains optional CLD BHWIDE and MadGraph LHE inputs:
`bhwide_ecm91` and `mg5_bhabha_ecm91`. To compile BHWIDE against the same stack:

```bash
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 idea/idea-dev.sif \
  bash -c 'set -e; source setup.sh; make -C generators/bhwide -j4'
```

`BHWIDE_PATH` can select an existing executable. MadGraph requires `mg5_aMC`
and `envsubst`; `MG5_TEMPLATE_DIR` (or main's `SIMDIR/mg5`) selects templates.
These background interfaces are separate from the three-sample FCC-ee dataset
qualification. The MadGraph template uses 45.5 GeV per beam for 91 GeV collisions.
Its adapter is regression-tested; native MadGraph event generation has not
been qualified in this update. BHWIDE compiled and generated three events
through the shared Pythia interface.

## License

Repository-owned code is **Apache-2.0**; see [LICENSE](LICENSE) and
[NOTICE](NOTICE). Submodules and external software retain their upstream terms
and attribution. In particular, the optional BHWIDE distribution has its own
terms; this repository's license does not relicense third-party code.

## Compatibility validation

On 17 November 2026, both overlays and the complete geometry, tracker and
calorimeter packages compiled against stable 2026-04-08. All **97 k4FWCore
CTest tests** and **8 tracker tests** passed, including explicit IP-state
lookup and both TrackMerger fixture modes. Configure the framework with
`BUILD_TESTING=ON` to build its tests; run `ctest --test-dir BUILD_DIR
--output-on-failure` inside the same development container.

Full simulation and reconstruction completed for three qq events per detector
(365 GeV for CLD/ILD/IDEA, 380 GeV for CLIC). All four converted to Parquet with
finite input and target arrays. ILD retains Pandora/TOF reconstruction; IDEA
retains fitted GGTF/GenFit tracking and the complete calorimeter package.
The ILD converter accepts absent/empty optional hit encodings; strict CLD/CLIC
metadata validation remains enabled. Local logs and data are under
`reports/stable-key4hep-qualification/` in the particleflow checkout.

These are software compatibility smoke tests. They do not establish tracking
efficiency, clustering quality or target/truth jet agreement, and do not
replace the larger detector qualification or the Tallinn 10k-event campaign.

## Preparing a release

Run `python3 -m unittest discover -s tests -v` without a physics stack. Run
`check_runtime.sh` and the four detector smoke jobs in the built container.
Verify all submodule commits are public and that `git status --short` is clean.
Tag the tested commit, not a rolling dependency branch. Release source users
must clone recursively; GitHub's source archive does not bundle submodules.
The planned tag is `v1.4.0`; it has not been created.
