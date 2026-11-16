#!/bin/bash
set -euo pipefail
CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR=${CONFIG_DIR}/k4RecTracker-local
source "${CONFIG_DIR}/setup.sh"
idea_use_local "${CONFIG_DIR}/k4geo-local"
rm -f "${SOURCE_DIR}/install-local/.idea-stack-id"
cmake --fresh -G Ninja -S "${SOURCE_DIR}" -B "${SOURCE_DIR}/build-local" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX="${SOURCE_DIR}/install-local" \
    -DBUILD_TESTING=OFF
cmake --build "${SOURCE_DIR}/build-local" --parallel "${BUILD_JOBS:-4}"
cmake --install "${SOURCE_DIR}/build-local"
printf '%s\n' "${IDEA_STACK_ID}" > "${SOURCE_DIR}/install-local/.idea-stack-id"
