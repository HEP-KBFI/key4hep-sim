"""Stage FCC-ee compact files with portable CAD paths, without changing geometry."""

import argparse
import shutil
from pathlib import Path


def stage_geometry(source, destination, assets=None):
    source, destination = Path(source), Path(destination)
    if destination.exists():
        raise FileExistsError(destination)
    shutil.copytree(source / "FCCee", destination / "FCCee")
    shutil.copytree(source / "fieldmaps", destination / "fieldmaps")
    stl_path = Path("FCCee/MDI/compact/stl_files/Pipe_240430")
    if not (destination / stl_path).exists() and assets is not None:
        shutil.copytree(Path(assets) / stl_path, destination / stl_path)
    cad = destination / "FCCee/MDI/compact/MDI_o1_CADBased_v01/Beampipe_CADimport_o1_v03.xml"
    text = cad.read_text()
    old = "${K4GEO}/FCCee/MDI/compact/stl_files/"
    if text.count(old) != 6:
        raise ValueError("Unexpected upstream CAD references; review geometry staging")
    import re

    for name in re.findall(r'ref="\$\{K4GEO\}/FCCee/MDI/compact/stl_files/([^\"]+)"', text):
        if not (destination / "FCCee/MDI/compact/stl_files" / name).is_file():
            raise FileNotFoundError(f"Missing ILD CAD asset: {name}; provide an installed k4geo asset directory")
    # GeoSvc's CAD reader in the qualified DD4hep version prepends the XML
    # directory even to an expanded absolute filename. Relative paths work in
    # both GeoSvc and DDSim and select exactly the same six STL assets.
    cad.write_text(text.replace(old, "../stl_files/"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("--assets", help="Installed k4geo containing the six beam-pipe STL assets")
    args = parser.parse_args()
    stage_geometry(args.source, args.destination, args.assets)
