#!/usr/bin/env bash
# Execute inside the development container after building all overlays.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root/idea/setup.sh"
source "$root/ild/use_refitter.sh"
assets=$K4GEO
for package in k4geo k4RecTracker k4RecCalorimeter; do
    idea_use_local "$root/idea/${package}-local"
done
test "$(git -C "$root/ild/ILDConfig" rev-parse HEAD)" = fc1c9f58f9912b4d1fb10da5defbaca2133d60a0
command -v ddsim
command -v k4run
python -c 'import DDG4; from Configurables import TrackMerger, GGTFTrackFinder, GenfitTrackFitter; print("Native simulation and tracking imports passed")'
check_dir=$(mktemp -d /tmp/key4hep-runtime-check.XXXXXXXX)
trap 'rm -rf -- "$check_dir"' EXIT
python "$root/ild/stage_geometry.py" "$K4GEO" "$check_dir/geometry" --assets "$assets"
test -s "$root/.local/models/SimpleGatrIDEAv3o1.onnx"
printf 'Runtime check passed; build identity: %s\n' "$KEY4HEP_BUILD_ID"
