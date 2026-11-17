"""Generate HepMC3 input with current k4Gen and k4FWCore services.

Use the shared FCC-ee cards with the current event service for IDEA and ILD.
The cards define the beam spot; no additional GenAlg vertex smearing is applied.
"""

from Gaudi.Configuration import INFO
from Configurables import (
    EventDataSvc,
    EventHeaderCreator,
    GenAlg,
    HepMCFileWriter,
    PythiaInterface,
)
from k4FWCore import ApplicationMgr

pythia = PythiaInterface(
    "PythiaInterface",
    pythiacard="card.cmd",
    doEvtGenDecays=False,
    printPythiaStatistics=True,
)
generator = GenAlg("Pythia8", SignalProvider=pythia)
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
