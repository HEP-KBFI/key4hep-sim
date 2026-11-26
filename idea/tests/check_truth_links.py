"""Exercise the built CreateTruthLinks plugin on copied dual-readout cells.

Run in the IDEA environment: python check_truth_links.py /tmp/idea-truth-check
"""

from pathlib import Path
import subprocess
import sys

import edm4hep
import podio
from podio import root_io


def write_input(path):
    frame = podio.Frame()
    particles = edm4hep.MCParticleCollection()
    for pdg in (211, 22):
        particle = particles.create()
        particle.setPDG(pdg)
        particle.setGeneratorStatus(1)
    contributions = edm4hep.CaloHitContributionCollection()
    simhits = edm4hep.SimCalorimeterHitCollection()
    channels = [edm4hep.CalorimeterHitCollection() for _ in range(2)]
    links = [edm4hep.CaloHitSimCaloHitLinkCollection() for _ in range(2)]
    copied = edm4hep.CalorimeterHitCollection()
    clusters = edm4hep.ClusterCollection()
    # Event cells: same cellID in two readouts; different IDs; an unlabelled
    # positive channel; and empty channels, which must produce no links.
    for cell_id, known_second_channel in ((25, True), (89, True), (153, False)):
        for channel, energy in enumerate((2.0, 6.0)):
            hit = channels[channel].create()
            hit.setCellID(cell_id if cell_id != 89 else cell_id + channel * 32)
            hit.setEnergy(energy)
            sim = simhits.create()
            sim.setCellID(hit.getCellID())
            sim.setEnergy(10.0)
            if channel == 0 or known_second_channel:
                contribution = contributions.create()
                contribution.setParticle(particles[channel])
                contribution.setEnergy(10.0)
                sim.addToContributions(contribution)
            link = links[channel].create()
            link.setFrom(hit)
            link.setTo(sim)
        cluster = clusters.create()
        cluster.setEnergy(8.0)
        if cell_id == 89:
            for channel in range(2):
                cell = copied.create()
                cell.setCellID(cell_id + channel * 32)
                cell.setEnergy((2.0, 6.0)[channel])
                cluster.addToHits(cell)
        else:
            cell = copied.create()
            cell.setCellID(cell_id)
            cell.setEnergy(8.0)
            cluster.addToHits(cell)

    for channel in range(2):
        hit = channels[channel].create()
        hit.setCellID(217)
        sim = simhits.create()
        sim.setEnergy(0.0)
        link = links[channel].create()
        link.setFrom(hit)
        link.setTo(sim)
    for name, collection in (
        ("MCParticles", particles),
        ("Contributions", contributions),
        ("SimHits", simhits),
        ("Cherenkov", channels[0]),
        ("Scintillation", channels[1]),
        ("CherenkovLinks", links[0]),
        ("ScintillationLinks", links[1]),
        ("CopiedCells", copied),
        ("Clusters", clusters),
    ):
        frame.put(collection, name)
    writer = root_io.Writer(str(path))
    writer.write_frame(frame, "events")
    writer.finish()


def check_output(path):
    reader = root_io.Reader(str(path))
    frames = list(reader.get("events"))
    assert len(frames) == 1
    frame = frames[0]
    weights = {}
    for link in frame.get("ClusterTruth"):
        weights[link.getFrom().id().index, link.getTo().getPDG()] = link.getWeight()
    expected = {
        (0, 211): 0.25,
        (0, 22): 0.75,
        (1, 211): 0.25,
        (1, 22): 0.75,
        (2, 211): 0.25,
    }
    assert weights.keys() == expected.keys(), weights
    for key, value in expected.items():
        assert abs(weights[key] - value) < 1e-6, (key, weights[key], value)
    assert len(frame.get("CellTruth")) == 5
    print(
        "Copied-cell, dual-channel, missing-truth and empty-cell truth-link checks passed"
    )


if __name__ == "__main__":
    workdir = Path(sys.argv[1]).resolve()
    workdir.mkdir(parents=True, exist_ok=True)
    write_input(workdir / "input.root")
    job = workdir / "truth_job.py"
    job.write_text("""from k4FWCore import IOSvc, ApplicationMgr
from Configurables import CreateTruthLinks, EventDataSvc
io = IOSvc("IOSvc", Input="input.root", Output="output.root")
truth = CreateTruthLinks("Truth", cell_hit_links=["CherenkovLinks", "ScintillationLinks"],
    clusters=["Clusters"], mcparticles="MCParticles", minCellEnergy=0.,
    cell_mcparticle_links="CellTruth", cluster_mcparticle_links="ClusterTruth")
app = ApplicationMgr(TopAlg=[truth], ExtSvc=[EventDataSvc("EventDataSvc")], EvtSel="NONE", EvtMax=1)
""")
    subprocess.run(["k4run", str(job)], cwd=workdir, check=True)
    check_output(workdir / "output.root")
