# v1.4.0

Joint release of the CLD, CLIC, IDEA and ILD full-simulation recipes.

- One stable runtime for all detectors: Key4hep 2026-04-08 with locally built
  k4FWCore v01-06 and MarlinReco v01-38-01 overlays (`setup.sh`, `build_all.sh`).
- Fitted IDEA tracking (GGTF track finding and GenFit fitting from the pinned
  k4RecTracker fork, including the circle-seed orientation and fitted-charge
  fixes) alongside the existing dual-readout calorimeter truth patches.
- New ILD at FCC-ee recipe (`ILD_FCCee_v02`) with Clupatra tracking, a patched
  MarlinTrkProcessors refitter that drops failed refits, and Pandora.
- One FCC-ee card set and generator steering for CLD, IDEA and ILD; CLIC shares
  the steering with its 380 GeV cards and uses the FCC-ee Z cards at 91 GeV.
- Pythia supplies the FCC-ee 2025 beam spot; no additional vertex smearing.
- All runners pass the job seed to ddsim, publish outputs atomically, write a
  `reco_SAMPLE_SEED.software.txt` manifest and clean production scratch.
- The IDEA tracking model is downloaded once at build time.
- CLD's BHWIDE and MadGraph Bhabha inputs are retained (45 GeV per beam).
- Standalone build and runtime checks, build-identity validation, and
  Apache-2.0 licensing for repository-owned code.

Datasets produced with earlier releases use proxy IDEA tracks or different
vertex smearing and must be regenerated, not relabelled.
