#!/bin/bash
# Source in a clean AlmaLinux 9 shell. All detector recipes use this stable base.
export MLPF_KEY4HEP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KEY4HEP_RELEASE=${KEY4HEP_RELEASE:-${KEY4HEP_VERSION:-2026-04-08}}
if [[ -n ${KEY4HEP_VERSION:-} && ${KEY4HEP_VERSION} != "${KEY4HEP_RELEASE}" ]]; then
    echo "KEY4HEP_VERSION and KEY4HEP_RELEASE disagree; select one stable runtime." >&2
    return 1
fi
if [[ ! ${KEY4HEP_RELEASE} =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "KEY4HEP_RELEASE must name a dated stable release, not a rolling view." >&2
    return 1
fi
if [[ -n ${LCG_VIEW_DIR:-} ]]; then
    echo "Start a clean shell/container before selecting the stable Key4HEP runtime." >&2
    return 1
fi
if [[ -n ${KEY4HEP_STACK:-} && ${KEY4HEP_STACK} != *"/releases/${KEY4HEP_RELEASE}/"* ]]; then
    echo "An incompatible Key4HEP release is already active: ${KEY4HEP_STACK}" >&2
    return 1
fi
if [[ ${MLPF_KEY4HEP_REQUEST:-} != "stable:${KEY4HEP_RELEASE}" ]] || ! declare -F k4_local_repo >/dev/null; then
    mlpf_restore_nounset=0
    [[ $- == *u* ]] && mlpf_restore_nounset=1
    set +u
    source /cvmfs/sw.hsf.org/key4hep/setup.sh -r "${KEY4HEP_RELEASE}"
    mlpf_setup_status=$?
    (( mlpf_restore_nounset == 0 )) || set -u
    if (( mlpf_setup_status != 0 )); then return "${mlpf_setup_status}"; fi
fi
export MLPF_KEY4HEP_REQUEST="stable:${KEY4HEP_RELEASE}"
export KEY4HEP_LOCAL_ROOT=${KEY4HEP_LOCAL_ROOT:-${MLPF_KEY4HEP_ROOT}/.local/${KEY4HEP_RELEASE}}
export KEY4HEP_BASE_ID=$(sha256sum "${KEY4HEP_STACK}" | cut -d ' ' -f 1)
mlpf_core_commit=$(git -C "${MLPF_KEY4HEP_ROOT}/k4FWCore" rev-parse HEAD)
export KEY4HEP_BUILD_ID=$(printf '%s\n%s\n' "${KEY4HEP_BASE_ID}" "${mlpf_core_commit}" | sha256sum | cut -d ' ' -f 1)
# Compatibility names used by the detector manifests.
export IDEA_STACK_REQUEST="${MLPF_KEY4HEP_REQUEST}+k4FWCore:${mlpf_core_commit}"
export IDEA_STACK_ID=${KEY4HEP_BUILD_ID}

key4hep_install_dir() {
    local package
    package=$(basename "$1")
    printf '%s/install/%s\n' "${KEY4HEP_LOCAL_ROOT}" "${package%-local}"
}

key4hep_use_local() {
    local source_dir=$1 install_dir source_commit previous_dir=${PWD}
    install_dir=$(key4hep_install_dir "${source_dir}")
    source_commit=$(git -C "${source_dir}" rev-parse HEAD)
    if [[ ! -f ${install_dir}/.key4hep-build-id || ! -f ${install_dir}/.key4hep-source-id ]] || \
       [[ $(cat "${install_dir}/.key4hep-build-id") != "${KEY4HEP_BUILD_ID}" || \
          $(cat "${install_dir}/.key4hep-source-id") != "${source_commit}" ]]; then
        echo "Missing or stale stable build: ${source_dir}. Run gen/build_all.sh in the development container." >&2
        return 1
    fi
    git -C "${source_dir}" diff --quiet HEAD -- . || {
        echo "Source differs from the recorded build commit: ${source_dir}" >&2
        return 1
    }
    cd "${source_dir}"
    local restore_nounset=0
    [[ $- == *u* ]] && restore_nounset=1
    set +u
    # Upstream derives the package name from PWD; our forks have a -local suffix.
    # Remove the stock package paths explicitly before activating these forks.
    if [[ $(basename "${source_dir}") == *-local ]]; then
        local package variable entry filtered
        package=$(basename "${source_dir}")
        package=${package%-local}
        package=${package,,}
        for variable in PATH ROOT_LIBRARY_PATH LD_LIBRARY_PATH PYTHONPATH CMAKE_PREFIX_PATH \
                        PKG_CONFIG_PATH ROOT_INCLUDE_PATH GAUDI_PLUGIN_PATH; do
            filtered=
            local -a entries
            IFS=: read -r -a entries <<< "${!variable}"
            for entry in "${entries[@]}"; do
                [[ -z ${entry} || ${entry,,} == *"/${package}/"* ]] && continue
                filtered=${filtered:+${filtered}:}${entry}
            done
            export "${variable}=${filtered}"
        done
        _replace_marlin_dll "${package}" "$(realpath --relative-to="${source_dir}" "${install_dir}")"
    fi
    k4_local_repo "$(realpath --relative-to="${source_dir}" "${install_dir}")"
    local setup_status=$?
    (( restore_nounset == 0 )) || set -u
    cd "${previous_dir}"
    if (( setup_status != 0 )); then return "${setup_status}"; fi
    if [[ $(basename "${source_dir}") == k4geo-local ]]; then
        export K4GEO=${source_dir} LCGEO=${source_dir}
        export k4geo_DIR=${install_dir}/lib/cmake/k4geo
        export lcgeo_DIR=${k4geo_DIR}
    fi
}

key4hep_record_build() {
    local source_dir=$1 install_dir
    install_dir=$(key4hep_install_dir "${source_dir}")
    printf '%s\n' "${KEY4HEP_BUILD_ID}" > "${install_dir}/.key4hep-build-id"
    git -C "${source_dir}" rev-parse HEAD > "${install_dir}/.key4hep-source-id"
}

key4hep_write_manifest() {
    local output=$1
    {
        printf 'key4hep_release=%s\nkey4hep_stack=%s\nkey4hep_base_id=%s\nkey4hep_build_id=%s\n' \
            "${KEY4HEP_RELEASE}" "${KEY4HEP_STACK}" "${KEY4HEP_BASE_ID}" "${KEY4HEP_BUILD_ID}"
        printf 'k4FWCore=%s\nMarlinReco=%s\n' \
            "$(git -C "${MLPF_KEY4HEP_ROOT}/k4FWCore" rev-parse HEAD)" \
            "$(git -C "${MLPF_KEY4HEP_ROOT}/MarlinReco" rev-parse HEAD)"
    } > "${output}"
}

if [[ ${KEY4HEP_BOOTSTRAP:-0} != 1 ]]; then
    key4hep_use_local "${MLPF_KEY4HEP_ROOT}/k4FWCore" || return 1
fi
if [[ ${KEY4HEP_BOOTSTRAP:-0} != 1 && ${KEY4HEP_SKIP_MARLIN:-0} != 1 ]]; then
    key4hep_use_local "${MLPF_KEY4HEP_ROOT}/MarlinReco" || return 1
fi
