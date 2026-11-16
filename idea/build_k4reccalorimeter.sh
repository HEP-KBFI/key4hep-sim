#!/bin/bash
# Build the patched dual-readout reconstruction against the local geometry.
set -euo pipefail

CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR=${CONFIG_DIR}/k4RecCalorimeter-local
BUILD_DIR=${SOURCE_DIR}/build-local
INSTALL_DIR=${SOURCE_DIR}/install-local

source "${CONFIG_DIR}/setup.sh"
idea_use_local "${CONFIG_DIR}/k4geo-local"

rm -f "${INSTALL_DIR}/.idea-stack-id"
cmake --fresh -G Ninja -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DBUILD_TESTING=OFF
cmake --build "${BUILD_DIR}" --parallel "${BUILD_JOBS:-4}"
cmake --install "${BUILD_DIR}"
printf '%s\n' "${IDEA_STACK_ID}" > "${INSTALL_DIR}/.idea-stack-id"
