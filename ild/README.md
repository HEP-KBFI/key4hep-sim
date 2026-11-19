# ILD at FCC-ee

`run_sim.sh SAMPLE SEED` produces full-simulation EDM4hep files for
`ILD_FCCee_v02` (2 T) with fitted `MarlinTrkTracks` and Pandora clusters and
PFOs. `ILDConfig` is pinned to `fc1c9f58f9912b4d1fb10da5defbaca2133d60a0`.

Build the shared runtime first (see the [top-level README](../README.md)).
ILD uses the k4geo and k4RecTracker builds from `../idea/` and the patched
MarlinTrkProcessors refitter, which `build_all.sh` installs and the runner
loads automatically.

Supported samples are `p8_ee_{qq,ttbar,WW_fullhad}_ecm365`,
`p8_ee_Z_{qq,tautau}_ecm91` and the particle guns `gun_{e,mu,pi,gamma,kaon0L}_*`.
The reconstruction energy follows the sample (91 or 365 GeV); a conflicting
`CMS_ENERGY` is rejected. Guns accept `GUN_THETA_MIN` and `GUN_THETA_MAX` in
DD4hep units, for example `45*degree`.

The runner stages the compact geometry and beam-pipe CAD assets into the work
directory with relative paths, because the GeoSvc reader of this DD4hep
version mishandles expanded absolute filenames; no geometry values change.
Each job reconstructs in a private copy of the ILDConfig steering directory
and keeps the native simulation hits and digitization relations in the output
for truth checks. The manifest records the ILDConfig, k4geo and k4RecTracker
commits, the staged geometry checksums and the exact ddsim and k4run commands.
