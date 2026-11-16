"""Generate HepMC3 input with current k4Gen and k4FWCore services.

The shared CLD steering still uses the removed k4DataSvc API. Keep its physics
cards and vertex-smearing settings, but use the current event service for IDEA.
"""

from Gaudi.Configuration import INFO
from GaudiKernel import SystemOfUnits as units
from Configurables import (
    EventDataSvc,
    EventHeaderCreator,
    GaussSmearVertex,
    GenAlg,
    HepMCFileWriter,
    PythiaInterface,
)
from k4FWCore import ApplicationMgr

smear = GaussSmearVertex(
    "GaussSmearVertex",
    xVertexSigma=0.5 * units.mm,
    yVertexSigma=0.5 * units.mm,
    zVertexSigma=40.0 * units.mm,
    tVertexSigma=180.0 * units.picosecond,
)
pythia = PythiaInterface(
    "PythiaInterface",
    pythiacard="card.cmd",
    doEvtGenDecays=False,
    printPythiaStatistics=True,
)
generator = GenAlg("Pythia8", SignalProvider=pythia, VertexSmearingTool=smear)
generator.hepmc.Path = "hepmc"
writer = HepMCFileWriter("Dumper", Filename="out.hepmc")
writer.hepmc.Path = "hepmc"

application = ApplicationMgr(
    EvtSel="NONE",
    EvtMax=100,
    OutputLevel=INFO,
    ExtSvc=[EventDataSvc("EventDataSvc"), "RndmGenSvc"],
    TopAlg=[EventHeaderCreator("EventHeaderCreator"), generator, writer],
)
