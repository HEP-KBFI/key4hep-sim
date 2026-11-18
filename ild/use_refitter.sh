# Source after initializing the stable Key4hep environment.
refitter="${KEY4HEP_LOCAL_ROOT}/install/MarlinTrkProcessors/lib/libMarlinTrkProcessors.so"
if [[ ! -r $refitter ]]; then
    echo "Missing patched MarlinTrkProcessors. Run gen/build_all.sh inside the development container." >&2
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
