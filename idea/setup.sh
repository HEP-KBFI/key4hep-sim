#!/bin/bash
# Source from a clean AlmaLinux 9 shell, both for building and running IDEA.
# Upstream sources are pinned by submodules; the LCG nightly is rolling.
IDEA_STACK_RELEASE=${IDEA_STACK_RELEASE:-latest}
IDEA_STACK_COMPILER=${IDEA_STACK_COMPILER:-gcc16}
idea_stack_request="lcg:${IDEA_STACK_RELEASE}:${IDEA_STACK_COMPILER}"
if [[ ${IDEA_STACK_REQUEST:-} != "${idea_stack_request}" ]]; then
    if [[ -n ${KEY4HEP_STACK:-} || -n ${LCG_VIEW_DIR:-} ]]; then
        echo "Start IDEA in a clean shell/container; a different Key4HEP stack is already active." >&2
        return 1
    fi
    # The external setup script is not nounset-compatible.
    idea_restore_nounset=0
    [[ $- == *u* ]] && idea_restore_nounset=1
    set +u
    source /cvmfs/sw-nightlies.hsf.org/key4hep/setup.sh --lcg \
        -c "${IDEA_STACK_COMPILER}" -r "${IDEA_STACK_RELEASE}"
    idea_setup_status=$?
    (( idea_restore_nounset )) && set -u
    if (( idea_setup_status != 0 )); then
        return "${idea_setup_status}"
    fi
    export IDEA_STACK_REQUEST="${idea_stack_request}"
fi

# Refuse to reuse installations after the rolling view has changed.
export IDEA_STACK_ID="$(sha256sum "${LCG_VIEW_DIR}/setup.sh" | cut -d ' ' -f 1)"

idea_use_local() {
    local source_dir=$1
    if [[ ! -f ${source_dir}/install-local/.idea-stack-id ]] || \
       [[ $(cat "${source_dir}/install-local/.idea-stack-id") != "${IDEA_STACK_ID}" ]]; then
        echo "Missing or stale IDEA build: ${source_dir}. Run idea/build_all.sh in this stack." >&2
        return 1
    fi
    local previous_dir=${PWD}
    cd "${source_dir}"
    local restore_nounset=0
    [[ $- == *u* ]] && restore_nounset=1
    set +u
    k4_local_repo install-local
    local setup_status=$?
    (( restore_nounset )) && set -u
    cd "${previous_dir}"
    if (( setup_status != 0 )); then
        return "${setup_status}"
    fi
    # k4_local_repo recognizes only a directory literally named k4geo.
    # Our submodule is named k4geo-local, so select its compact files explicitly.
    if [[ $(basename "${source_dir}") == k4geo-local ]]; then
        export K4GEO="${source_dir}"
        export LCGEO="${source_dir}"
        export k4geo_DIR="${source_dir}/install-local/lib/cmake/k4geo"
        export lcgeo_DIR="${k4geo_DIR}"
    fi
}
