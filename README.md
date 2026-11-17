# Shared stable Key4hep runtime

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

From the particleflow root, build the development image as described in
[IDEA](idea/README.md), then:

```bash
git submodule update --init --recursive
apptainer exec --bind /cvmfs,"$PWD",/tmp \
  --env LD_PRELOAD=/usr/lib64/libffi.so.8 \
  mlpf/data/key4hep/gen/idea/idea-dev.sif \
  bash mlpf/data/key4hep/gen/build_all.sh
bash scripts/check_ild_runtime.sh
```

`build_all.sh` builds framework, MarlinReco, geometry, tracking, then calorimeter
reconstruction. CLD/CLIC alone need only `build_overlays.sh`. Builds use Ninja,
RelWithDebInfo and four workers (`BUILD_JOBS` overrides). Shared installations
are under `.local/2026-04-08/install/`, separate from old nightly builds.
A clean shell/container is required: rolling views and mixed releases are
rejected. Do not rebuild a shared prefix while jobs are running.

Each install records the stable setup checksum, framework identity and source
commit. Modified sources and mismatched builds are rejected on activation.
Jobs record the stable release and overlay commits in their software manifests.
Compiled files and the container are ignored by Git and must be built on each
execution host. The four primary productions in `particleflow_spec.yaml` select
this runtime and fresh workspace names. Archive old `snakemake_jobs/DETECTOR/`
completion markers before regenerating workflows for the new campaign.
Historical scan productions retain their original runtime settings.

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
