#!/bin/bash
# Build the IDEA-local k4geo simulation plugin against the pinned Key4HEP release.
set -euo pipefail

CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR=${CONFIG_DIR}/k4geo-local
BUILD_DIR=${SOURCE_DIR}/build-local
INSTALL_DIR=${SOURCE_DIR}/install-local

set +u
source /cvmfs/sw.hsf.org/key4hep/setup.sh -r 2026-04-08
set -u

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DBUILD_TESTING=OFF \
    -DK4GEO_USE_LCIO=OFF \
    -DINSTALL_COMPACT_FILES=OFF
cmake --build "${BUILD_DIR}" --parallel "${BUILD_JOBS:-4}"
cmake --install "${BUILD_DIR}"
