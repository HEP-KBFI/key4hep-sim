# ILD@FCC-ee generation

`run_sim.sh PROCESS SEED` produces full-simulation EDM4hep ROOT files for
`ILD_FCCee_v02`, with fitted `MarlinTrkTracks` and Pandora clusters/PFOs.
`ILDConfig` is pinned to `fc1c9f58f9912b4d1fb10da5defbaca2133d60a0`.

Use the AlmaLinux development image, stable Key4hep 2026-04-08 and the
[shared local overlays](../README.md), including k4FWCore v1.6 and
MarlinReco v1.38.1. Geometry and tracking use the matched builds of
`../idea/k4geo-local` and `../idea/k4RecTracker-local`. See
`docs/datasets/ild.md` in particleflow for build, execution, postprocessing,
target-policy and qualification instructions. Initialize this repository's
submodules recursively.

Required environment variables are `OUTDIR` and a fresh `WORKDIR`; `NEV`
defaults to 100. The runner snapshots its scripts, stages the complete geometry
and CAD assets, preserves logs/intermediate files, and writes a software
manifest next to the final ROOT file. Reconstruction jobs have private working
directories. Failures do not delete scratch data or publish partial ROOT files.

The recipe is experimental. Detector-quality qualification is separate from
successful execution and TFDS integration.

The collision recipe supports ttbar, qq and WW fullhad at 365 GeV, and
`p8_ee_Z_qq_ecm91` / `p8_ee_Z_tautau_ecm91` at 91 GeV. It selects the matching
reconstruction energy automatically; a conflicting `CMS_ENERGY` is rejected.
