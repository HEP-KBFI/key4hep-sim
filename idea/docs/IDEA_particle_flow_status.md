# Current state of particle-flow reconstruction for IDEA

Source: Sanghyun Ko, *Pandora (reconstruction) experience with the IDEA
detector*, Particle Flow Reconstruction Workshop, 2 September 2025
([presentation](https://indico.cern.ch/event/1567387/contributions/6603716/attachments/3126713/5546576/250902_PFworkshop.pdf)).

## Executive summary

Particle-flow reconstruction for IDEA is at an early integration and
proof-of-concept stage. A basic path from simulated detector hits to Pandora
tracks and clusters has been established for the option-1 detector, and an
existing Pandora/LCContent algorithm gives promising preliminary
track-to-cluster association. It is not yet a complete PFA: realistic pattern
recognition and track fitting, robust charged/neutral separation, shower
reclustering, bremsstrahlung recovery, calibrated energy regression, and final
particle-flow object construction remain work in progress.

The effort is intentionally building small, reusable components rather than
porting the complete CLD Pandora chain. IDEA's drift chamber and dual-readout
calorimeter differ too much from the highly segmented silicon/calorimeter
detectors for which the standard LCContent chain was designed.

## What works today

- **Full simulation:** IDEA option 1, with a monolithic scintillation/Cherenkov
  fiber dual-readout calorimeter, is integrated with Key4HEP and sufficiently
  optimized to produce useful full-simulation samples. Option 2 adds a crystal
  dual-readout ECAL; its DD4hep geometry exists, but simulation cost still
  needs optimization.

- **Calorimeter digitization and calibration:** scintillation and Cherenkov
  channels are digitized and equalized using 20 GeV electrons. The simulated
  electromagnetic response is reasonably linear, so no energy-dependent
  rescaling is presently required. The quoted idealized Geant4 stochastic
  resolutions are approximately 11.6%/sqrt(E) for electromagnetic showers and
  20.6%/sqrt(E) for hadronic showers; these still need validation with beam-test
  data and include idealized assumptions.

- **Initial clustering:** IDEA calorimeter hits are grouped with a topological
  clustering algorithm in Gaudi/k4RecCalorimeter. Seeds exceed 4 sigma of the
  noise, clusters grow through neighboring cells above 2 sigma, and a final
  pass includes adjacent cells above 0 sigma. User-defined topology handles
  the unusual fiber geometry and keeps scintillation and Cherenkov channels
  separable.

- **Pandora interface:** topological clusters built outside Pandora are copied
  into `pandora::Cluster` objects by an external-clustering algorithm. Their
  calorimeter hits, together with tracks, then become inputs to selected
  Pandora algorithms.

- **Preliminary track-cluster association:** the geometrical association from
  LCContent has been reused successfully. For 10 GeV electrons in the barrel,
  the reported matching efficiency is about 99%, using a 3 mm transverse
  distance cut. This result uses truth-seeded tracks and has not yet been
  established for low-pT particles, dense jets, or the full particle mixture.

## Important limitations

- **Tracking is not yet realistic.** GenFit2/Kalman-filter integration for the
  IDEA drift chamber is ongoing. Current particle-reconstruction studies use
  `TracksFromGenParticles`: track parameters come from generator particles and
  associated simulated tracker hits are attached to them. This bypasses the
  central pattern-recognition problem and makes present matching performance an
  optimistic proof of principle.

- **Trajectory extrapolation is too simple.** Tracks are propagated to the
  calorimeter as helices. In option 1, the solenoid lies between the drift
  chamber and calorimeter, so the magnetic field changes along the path. The
  approximation produces a charge-dependent phi bias between extrapolated
  tracks and cluster centers. Extrapolation using the local field is needed.

- **The standard LCContent chain cannot be applied wholesale.** IDEA has a
  drift chamber, extreme transverse fiber granularity, little or no
  calorimeter longitudinal segmentation, and dual scintillation/Cherenkov
  readout. Algorithms must be selected or developed specifically for those
  features.

- **Performance has only been demonstrated in simple cases.** Most examples
  use single electrons or pions around 10--20 GeV. Validation must expand to
  electrons, muons, photons, charged pions, neutral kaons, low-pT particles,
  overlapping showers, and jets.

## Main reconstruction work still needed

1. Complete drift-chamber digitization, cluster counting/dN/dx, realistic
   pattern recognition, and GenFit2 track fitting.
2. Implement field-aware extrapolation through the solenoid and validate
   track-cluster association over momentum, angle, particle type, and dense
   environments.
3. Recover electron bremsstrahlung and other upstream radiation through
   superclustering or reclustering along track tangents.
4. Merge satellite clusters from secondary hadronic interactions while
   retaining fine initial clusters for resolving nearby particles and pi0s.
5. Add energy regression for tower-edge gaps and non-uniform response using
   shower shape and impact position.
6. Exploit the Cherenkov-to-scintillation response for cluster-level
   electromagnetic/hadronic identification, dual-readout correction, and
   selecting the appropriate downstream reconstruction path.
7. Develop and validate final charged/neutral assignment and particle-flow
   object construction, followed by jet-level benchmarks.

## Longer-term opportunity: timing

Because the fiber calorimeter has little longitudinal segmentation, timing may
provide effective depth information. The presentation explores waveform
deconvolution and photon-propagation corrections; at 10 GHz sampling, 100 ps
corresponds to roughly 4 cm of longitudinal information. Simulations show
qualitatively distinct electromagnetic, hadronic, punch-through, and MIP-like
patterns. This is promising for pattern recognition, but remains a simulation
proof of concept that must be demonstrated with data and realistic optical
dispersion.

## Bottom line

IDEA has the beginnings of a modular Pandora-based particle-flow chain, not a
finished particle-flow reconstruction. The most mature pieces are full
simulation, dual-readout digitization, topology-aware clustering, the bridge
from external clusters into Pandora, and simple geometrical track-cluster
matching. The critical path to a credible end-to-end PFA is realistic tracking
and extrapolation, followed by IDEA-specific shower recovery and particle
identification and validation on multi-particle events and jets.
