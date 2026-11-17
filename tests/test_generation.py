"""Run with python -m unittest discover -s tests; no physics stack required."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GenerationContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.executable(
            "k4run",
            "import json,sys\nfrom pathlib import Path\n"
            "Path('arguments.json').write_text(json.dumps(sys.argv[1:]))\n"
            "Path(sys.argv[sys.argv.index('--Dumper.Filename')+1]).write_text('HepMC mock')\n",
        )
        self.env = os.environ | {"PATH": f"{self.bin}:{os.environ['PATH']}"}

    def executable(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)
        return path

    def generate(self, sample, collider="fccee", env=None, work=None):
        return subprocess.run(
            ["bash", str(ROOT / "generators/generate_events.sh"), sample, "12345", "2", collider],
            cwd=work or self.work,
            env=env or self.env,
            capture_output=True,
            text=True,
        )

    def test_fccee_uses_identical_cards_and_event_service(self):
        for sample in ("p8_ee_qq_ecm365", "p8_ee_ttbar_ecm365", "p8_ee_WW_fullhad_ecm365"):
            source = ROOT / "pythia/fccee" / f"{sample}.cmd"
            original = source.read_bytes()
            staged = []
            for detector in ("cld", "idea", "ild"):
                work = self.work / sample / detector
                work.mkdir(parents=True)
                result = self.generate(sample, work=work)
                self.assertEqual(result.returncode, 0, result.stderr)
                staged.append((work / "card.cmd").read_bytes())
                arguments = json.loads((work / "arguments.json").read_text())
                self.assertEqual(arguments[0], str(ROOT / "pythia/generate.py"))
                self.assertIn(hashlib.sha256(original).hexdigest(), (work / "generation.software.txt").read_text())
            self.assertEqual(staged, [original + b"\nRandom:seed=12345\n"] * 3)
            self.assertEqual(source.read_bytes(), original)

    def test_clic_retains_its_380gev_card(self):
        result = self.generate("p8_ee_qq_ecm380", collider="clic")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Beams:eCM = 380", (self.work / "card.cmd").read_text())

    def test_unknown_card_and_collider_fail_before_generation(self):
        for sample, collider in (("unknown", "fccee"), ("../escape", "fccee"), ("p8_ee_qq_ecm365", "unknown")):
            self.assertNotEqual(self.generate(sample, collider).returncode, 0)
        self.assertFalse((self.work / "arguments.json").exists())

    def test_bhwide_lhe_adapter_survives_main_merge(self):
        binary = self.executable(
            "mock-bhwide",
            "from pathlib import Path\nimport sys\nPath(sys.argv[sys.argv.index('--lhe')+1]).write_text('LHE mock')\n",
        )
        result = self.generate("bhwide_ecm91", env=self.env | {"BHWIDE_PATH": str(binary)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.work / "events.lhe").read_text(), "LHE mock")
        self.assertIn(f"Beams:LHEF = {self.work}/events.lhe", (self.work / "card.cmd").read_text())
        self.assertIn("Main:numberOfEvents = 2", (self.work / "card.cmd").read_text())

    def test_madgraph_template_and_lhe_adapter_survive_main_merge(self):
        self.executable(
            "envsubst",
            "import os,sys\nfrom string import Template\nsys.stdout.write(Template(sys.stdin.read()).substitute(os.environ))\n",
        )
        self.executable(
            "mg5_aMC",
            "from pathlib import Path\n"
            "p=Path('mg5_bhabha_ecm91/Events/mg5_bhabha_ecm91_seed12345/unweighted_events.lhe.gz')\n"
            "p.parent.mkdir(parents=True)\np.write_text('LHE mock')\n",
        )
        result = self.generate("mg5_bhabha_ecm91")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.work / "events.lhe.gz").read_text(), "LHE mock")
        self.assertIn("set iseed 12345", (self.work / "mg5_bhabha_ecm91.mg5").read_text())
        self.assertIn("set nevents 2", (self.work / "mg5_bhabha_ecm91.mg5").read_text())
        self.assertIn("set ebeam1 45.5", (self.work / "mg5_bhabha_ecm91.mg5").read_text())
        self.assertIn("set ebeam2 45.5", (self.work / "mg5_bhabha_ecm91.mg5").read_text())

    def test_all_runners_use_common_generation(self):
        for detector in ("cld", "clic", "idea", "ild"):
            script = (ROOT / detector / "run_sim.sh").read_text()
            self.assertIn("/generators/generate_events.sh", script)
            self.assertNotIn("Pythia8.PythiaInterface.pythiacard", script)
            self.assertNotIn("setup.sh -r", script)


if __name__ == "__main__":
    unittest.main()
