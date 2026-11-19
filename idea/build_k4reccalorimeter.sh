#!/bin/bash
# Build the patched dual-readout reconstruction against the local geometry.
set -euo pipefail

CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR=${CONFIG_DIR}/k4RecCalorimeter-local

source "${CONFIG_DIR}/setup.sh"
BUILD_DIR=${KEY4HEP_LOCAL_ROOT}/build/k4RecCalorimeter
INSTALL_DIR=$(key4hep_install_dir "${SOURCE_DIR}")
idea_use_local "${CONFIG_DIR}/k4geo-local"

rm -f "${INSTALL_DIR}/.key4hep-build-id"
cmake --fresh -G Ninja -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DBUILD_TESTING=OFF
cmake --build "${BUILD_DIR}" --parallel "${BUILD_JOBS:-4}"
cmake --install "${BUILD_DIR}"
key4hep_record_build "${SOURCE_DIR}"
