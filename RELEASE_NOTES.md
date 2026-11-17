# v1.4.0 (unreleased)

This branch merges `main` through `93150fd` and prepares a common release for
CLD, CLIC, IDEA and ILD. The planned tag is `v1.4.0`; it has not been created.

- Stable Key4hep 2026-04-08 / GCC 14.2 for all four recipes.
- Released local k4FWCore v1.6 supplies collection metadata while retaining
  CLD/CLIC's event-service compatibility; released MarlinReco v1.38.1 fixes
  the ILD TOF crash. Both upstream releases build without source changes.
- Tracker compatibility with stable EDM4hep 1.0 and PODIO 1.7, preserving
  explicit IP-state lookup and fitted-track kinematics.
- One FCC-ee card source (`pythia/fccee`) and one generator steering/service
  for CLD, IDEA and ILD. CLIC uses the same steering with its 380 GeV cards.
- ILD and CLIC support the shared Z→qq/tautau cards at 91 GeV for the
  joint 50k-event campaign; ILD reconstruction uses the matching beam energy.
- FCC-ee 2025 beam spot comes from Pythia alone; no additional vertex smear.
- Main's CLD BHWIDE/MadGraph background adapters are retained. The 91 GeV
  MadGraph template now sets each beam to 45.5 GeV.
- Standalone build and runtime checks, source/build identity validation,
  card hashes in software manifests, and isolated job work directories.
- Apache-2.0 license for repository-owned code; dependency terms remain
  separate as described in NOTICE.

See README.md for build/run instructions. Compatibility validation includes
97 k4FWCore tests, eight native tracker tests, six standalone generation tests,
three qq simulation/reconstruction events per detector, and additional smoke
runs of the merged recipes. Native generation with the shared steering passed
for qq, ttbar, WW fullhad and BHWIDE. MadGraph's adapter has a mocked regression
test; native MadGraph generation is not qualified here.

The small compatibility samples do not qualify detector physics performance.
IDEA fitted-track efficiency and target/truth jet behavior still require the
larger dataset studies. Rebuild local native libraries and regenerate datasets
in fresh campaign directories when migrating from the nightly runtime.
