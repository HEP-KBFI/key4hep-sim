# Source after initializing the stable Key4hep environment.
refitter_dir="${KEY4HEP_LOCAL_ROOT}/install/MarlinTrkProcessors"
refitter="${refitter_dir}/lib/libMarlinTrkProcessors.so"
refitter_patch="$(dirname "${BASH_SOURCE[0]}")/../patches/MarlinTrkProcessors-v02-12-08-missing-refit-seed.patch"
refitter_patch_sha=$(sha256sum "$refitter_patch" | cut -d ' ' -f 1)
if [[ ! -r $refitter || ! -r $refitter_dir/.key4hep-refitter-id ]] ||
   [[ $(cat "$refitter_dir/.key4hep-refitter-id") != "$(printf '%s\n' "$KEY4HEP_BASE_ID" "$refitter_patch_sha")" ]]; then
    echo "Missing or stale MarlinTrkProcessors overlay. Run gen/build_marlintrkprocessors.sh inside the development container." >&2
    return 1
fi
IFS=: read -r -a marlin_plugins <<< "$MARLIN_DLL"
replaced_refitter=0
for i in "${!marlin_plugins[@]}"; do
    if [[ ${marlin_plugins[i]} == */marlintrkprocessors/* ]]; then
        marlin_plugins[i]=$refitter
        replaced_refitter=1
    fi
done
if [[ $replaced_refitter != 1 ]]; then
    echo "Cannot locate the stable MarlinTrkProcessors plugin in MARLIN_DLL." >&2
    return 1
fi
MARLIN_DLL=$(IFS=:; printf '%s' "${marlin_plugins[*]}")
export MARLIN_DLL
printf 'Using patched MarlinTrkProcessors: %s\n' "$refitter"
