# key4hep-sim

Full Geant4 simulation and reconstruction recipes for the CLD, CLIC, IDEA and
ILD detectors, using pinned detector sources and one stable Key4hep runtime.
The release is **v1.4.0** (see `VERSION` and `RELEASE_NOTES.md`).

## Runtime

All four recipes source `setup.sh`, which activates the stable Key4hep release
**2026-04-08** (GCC 14.2, Gaudi 40r2, EDM4hep 1.0, PODIO 1.7) and two locally
built overlays:

| Package | Version | Pinned commit | Reason |
|---|---|---|---|
| k4FWCore | v01-06 | `2747ab63f5a408f0904c5d7e644fd9078394b8f1` | Collection-metadata APIs needed by the IDEA calorimeter code; keeps PodioDataSvc for CLD/CLIC |
| MarlinReco | v01-38-01 | `fe8e9e2d08b47048e639c072b7bce97f9847f7d1` | TOF fix for ILD tracks without subtracks |

IDEA and ILD additionally use the pinned k4geo and k4RecTracker forks, IDEA the
k4RecCalorimeter fork, and ILD a patched MarlinTrkProcessors refitter. Neither
overlay needs source patches. `KEY4HEP_RELEASE` selects the release (the
legacy `KEY4HEP_VERSION` is accepted when it agrees); other dated releases need
their own builds. Rolling views and shells with another release active are
rejected.

## Build

Requirements: Linux, readable `/cvmfs/sw.hsf.org`, Apptainer with fakeroot,
Git and internet access for submodules and the IDEA tracking model. Clone
recursively; GitHub source archives do not bundle submodules.

```bash
git clone --branch v1.4.0 --recurse-submodules https://github.com/HEP-KBFI/key4hep-sim.git
cd key4hep-sim
apptainer build --fakeroot idea/idea-dev.sif idea/AlmaLinux9.def
apptainer exec --bind /cvmfs,"$PWD",/tmp --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif bash build_all.sh
apptainer exec --bind /cvmfs,"$PWD",/tmp --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif bash check_runtime.sh
```

`build_all.sh` builds the two overlays, the patched ILD refitter, and the IDEA
geometry, tracker and calorimeter packages, then downloads the IDEA GGTF
tracking model once into `.local/models/`. CLD and CLIC alone need only
`build_overlays.sh`. Builds use Ninja with `BUILD_JOBS` workers (default 4) and
install under `.local/<release>/install/`, which Git ignores. Each installation
records the stack checksum and source commit; `setup.sh` refuses stale or
modified installations. `LD_PRELOAD` of the container's `libffi` avoids CVMFS
library loading stalls. Build once per execution host, from a clean shell, and
do not rebuild while jobs are running.

In a particleflow checkout, run the same commands from `mlpf/data/key4hep/gen/`.

## Generate events

Run each job inside the development image with a private, empty work directory:

```bash
detector=cld   # cld, idea, ild, or clic
sample=p8_ee_qq_ecm365
mkdir -p "output/$detector" "work/$detector"
apptainer exec --bind /cvmfs,"$PWD",/tmp --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  idea/idea-dev.sif env NEV=10 OUTDIR="$PWD/output/$detector" WORKDIR="$PWD/work/$detector" \
  bash "$detector/run_sim.sh" "$sample" 12345
```

| Detector | Geometry | Collision samples |
|---|---|---|
| CLD | CLD_o2_v07 | FCC-ee cards: `p8_ee_{qq,ttbar,WW_fullhad}_ecm365`, `p8_ee_Z_{qq,tautau}_ecm91`, ZZ/ZH cards, BHWIDE and MadGraph Bhabha inputs |
| IDEA | IDEA_o1_v03 | Same FCC-ee cards as CLD |
| ILD | ILD_FCCee_v02 (2 T) | `p8_ee_{qq,ttbar,WW_fullhad}_ecm365`, `p8_ee_Z_{qq,tautau}_ecm91` |
| CLIC | CLIC_o3_v14 | `p8_ee_{qq,ttbar,WW_fullhad,ZZ_fullhad}_ecm380`, plus the FCC-ee Z cards at 91 GeV |

Every runner takes `SAMPLE SEED` and reads `NEV` (default 100), `OUTDIR` and
`WORKDIR` from the environment. The runners behave the same way:

- The job seed is passed to Pythia and to ddsim, so a job is reproducible.
- The output is `OUTDIR/SAMPLE/root/reco_SAMPLE_SEED.root`, published through a
  `.partial` rename, with `reco_SAMPLE_SEED.software.txt` beside it recording
  the release, overlay commits, detector sources and card checksums.
- A `WORKDIR` under `/scratch/local/$USER/` is removed on exit; any other work
  directory keeps its logs and intermediate files for inspection.
- Samples starting with `gun_` use the DD4hep particle gun (`gun_e_*`,
  `gun_mu_*`, `gun_pi_*`; ILD also `gun_gamma_*` and `gun_kaon0L_*`), with
  `GUN_PARTICLE`, `GUN_ENERGY` and `GUN_DISTRIBUTION` overrides and no
  crossing-angle boost. Collision samples use each detector's steering-file
  crossing angle.
- Setting `LOGDIR` writes `generation.log`, `simulation.log` and
  `reconstruction.log` there instead of the job's standard output.

See [IDEA](idea/README.md) and [ILD](ild/README.md) for detector-specific
options. The particleflow repository drives these runners through Snakemake;
`cld/run_sim_manual.sh` is a standalone SLURM entry point.

### Shared FCC-ee generation

CLD, IDEA and ILD use exactly the same cards and generator steering.
`pythia/fccee` links to the pinned `cld/CLDConfig/pythia` directory; update
that submodule to change cards for all three. `generators/generate_events.sh`
stages a private `card.cmd`, appends the seed, runs `pythia/generate.py` and
records the card checksums in the manifest. The cards supply the FCC-ee 2025
beam-spot widths; no additional vertex smearing is applied. CLIC uses the same
steering with its own `pythia/clic` cards at 380 GeV, and the FCC-ee Z cards at
91 GeV. ILD selects the matching reconstruction energy from the sample name.

BHWIDE (`bhwide_ecm91`) and MadGraph (`mg5_bhabha_ecm91`, 45 GeV per beam)
provide optional LHE inputs. Compile BHWIDE against the same stack with
`source setup.sh; make -C generators/bhwide -j4`, or point `BHWIDE_PATH` at an
executable. MadGraph needs `mg5_aMC` and `envsubst`; `MG5_TEMPLATE_DIR`
selects the templates.

## Tests

```bash
python3 -m unittest discover -s tests -v   # no physics stack needed
```

`check_runtime.sh` verifies the built runtime inside the container. Before
tagging a release, also run one short collision job per detector.

## License

Repository-owned code is Apache-2.0 (`LICENSE`, `NOTICE`). Submodules and the
Key4hep software stack retain their own licenses.
