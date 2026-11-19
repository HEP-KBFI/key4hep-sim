"""Check collection and energy invariants in a one-particle IDEA smoke file."""

import argparse
import math

from podio import root_io


def check_file(path, proxy_only=False, require_fitted_tracks=False):
    reader = root_io.Reader(path)
    events = list(reader.get("events"))
    assert events, "No reconstructed events"
    for frame in events:
        collections = set(frame.getAvailableCollections())
        required = {
            "TracksFromGenParticles",
            "TracksFromGenParticlesAssociation",
            "TopoClusterAll",
            "TopoClusterAllCells",
            "ClusterMCParticleLinks",
            "DRcaloSiPMreadoutDigiHit_cheren_link",
            "DRcaloSiPMreadoutDigiHit_scint_link",
        }
        if not proxy_only:
            required |= {"FittedTracks", "FittedTracksWithFilteredHits"}
        assert required <= collections, required - collections
        assert len(frame.get("TracksFromGenParticles")) > 0
        if not proxy_only:
            if require_fitted_tracks:
                assert len(frame.get("FittedTracks")) > 0, (
                    "No successfully fitted tracks"
                )
            print(
                f"GGTF tracks={len(frame.get('PrefitTracks'))}; fitted tracks={len(frame.get('FittedTracks'))}"
            )
            for track in frame.get("FittedTracks"):
                assert track.getChi2() >= 0 and track.getNdf() > 0
                assert track.trackStates_size() > 0
        clusters = frame.get("TopoClusterAll")
        assert len(clusters) > 0
        channel_totals = [0.0, 0.0]
        for cluster in clusters:
            shape = list(cluster.getShapeParameters())
            assert len(shape) == 3, shape
            assert all(math.isfinite(value) for value in shape)
            assert math.isclose(
                cluster.getEnergy(), shape[1] + shape[2], rel_tol=1e-5, abs_tol=1e-7
            )
            assert math.isclose(
                cluster.getEnergy(),
                sum(hit.getEnergy() for hit in cluster.getHits()),
                rel_tol=1e-5,
                abs_tol=1e-7,
            )
            for i in range(2):
                channel_totals[i] += shape[i + 1]
        assert all(energy > 0 for energy in channel_totals), channel_totals
        weights = {}
        for link in frame.get("ClusterMCParticleLinks"):
            weight = link.getWeight()
            assert math.isfinite(weight) and 0.0 <= weight <= 1.00001, weight
            index = link.getFrom().id().index
            weights[index] = weights.get(index, 0.0) + weight
        # SiPM dark counts can produce unlabelled satellite clusters. Require
        # bounded per-cluster fractions and near-complete energy coverage,
        # rather than incorrectly attributing noise to the generated particle.
        assert all(0.0 <= weight <= 1.0001 for weight in weights.values()), weights
        total_energy = sum(cluster.getEnergy() for cluster in clusters)
        known_energy = sum(
            cluster.getEnergy() * weights.get(cluster.id().index, 0.0)
            for cluster in clusters
        )
        known_fraction = known_energy / total_energy
        assert known_fraction >= 0.99, known_fraction
        print(
            f"Checked {len(clusters)} clusters; channel energies C/S={channel_totals}; truth energy coverage={known_fraction:.6f}"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("--proxy-only", action="store_true")
    parser.add_argument(
        "--require-fitted-tracks",
        action="store_true",
        help="Also require successful tracking in this event",
    )
    args = parser.parse_args()
    check_file(args.input, args.proxy_only, args.require_fitted_tracks)
