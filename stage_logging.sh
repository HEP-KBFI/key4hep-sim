# Source in a detector runner before invoking run_stage.
run_stage() {
    local stage=$1 status=0
    shift
    if [[ -z ${LOGDIR:-} ]]; then
        "$@"
        return
    fi
    local log_file="${LOGDIR}/${stage}.log"
    mkdir -p -- "$LOGDIR" || return
    printf 'Starting %s. Log: %s\n' "$stage" "$log_file"
    (set -o pipefail; "$@" 2>&1 |
        sed -u -E '/^[^[:space:]]+[[:space:]]+(DEBUG|VERBOSE)[[:space:]]/d' > "$log_file") || status=$?
    if (( status != 0 )); then
        printf '%s failed (exit %s). Log: %s\n' "$stage" "$status" "$log_file" >&2
        tail -n 30 -- "$log_file" >&2
    fi
    return "$status"
}
