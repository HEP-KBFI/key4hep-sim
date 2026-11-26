#!/bin/bash
# Build released framework/Marlin overlays against the selected stable release.
set -euo pipefail
GENERATOR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KEY4HEP_BOOTSTRAP=1
source "${GENERATOR_ROOT}/setup.sh"
for package in k4FWCore MarlinReco; do
    source_dir=${GENERATOR_ROOT}/${package}
    install_dir=$(key4hep_install_dir "${source_dir}")
    build_dir=${KEY4HEP_LOCAL_ROOT}/build/${package}
    rm -f "${install_dir}/.key4hep-build-id"
    cmake --fresh -G Ninja -S "${source_dir}" -B "${build_dir}" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_PREFIX="${install_dir}" -DBUILD_TESTING="${BUILD_TESTING:-OFF}" -DINSTALL_DOC=OFF
    cmake --build "${build_dir}" --parallel "${BUILD_JOBS:-4}"
    cmake --install "${build_dir}"
    key4hep_record_build "${source_dir}"
    key4hep_use_local "${source_dir}"
done
