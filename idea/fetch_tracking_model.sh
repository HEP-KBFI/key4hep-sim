#!/usr/bin/env bash
# Download the IDEA GGTF tracking model once, so production jobs do not fetch it.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
model_dir=${TRACKING_MODEL_DIR:-${root}/.local/models}
model=${model_dir}/SimpleGatrIDEAv3o1.onnx
url=https://fccsw.web.cern.ch/fccsw/filesForSimDigiReco/IDEA/IDEA_o1_v03/SimpleGatrIDEAv3o1.onnx
if [[ -s ${model} ]]; then
    printf 'Tracking model present: %s\n' "${model}"
    exit 0
fi
mkdir -p "${model_dir}"
wget -nv "${url}" -O "${model}.part"
test -s "${model}.part"
mv "${model}.part" "${model}"
sha256sum "${model}"
