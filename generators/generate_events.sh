#!/usr/bin/env bash
# Run in a private work directory, after sourcing the shared setup.sh.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sample=${1:?Usage: generate_events.sh SAMPLE SEED EVENTS [fccee|clic]}
export NUM=${2:?Set random seed}
export NEV=${3:?Set event count}
collider=${4:-fccee}
[[ $sample =~ ^[A-Za-z0-9_]+$ && $NUM =~ ^[0-9]+$ && $NEV =~ ^[1-9][0-9]*$ ]] || {
    echo "Invalid sample, seed or event count" >&2; exit 2;
}
case $collider in fccee|clic) ;; *) echo "Unknown collider: $collider" >&2; exit 2 ;; esac
source_card=$root/pythia/$collider/$sample.cmd
test -r "$source_card"
cp "$source_card" card.cmd
printf '\nRandom:seed=%s\n' "$NUM" >> card.cmd
case $sample in
    bhwide*)
        lhe=$PWD/events.lhe
        binary=${BHWIDE_PATH:-${root}/generators/bhwide/bin/bhwide}
        test -x "$binary"
        cp "$binary" ./bhwide
        ./bhwide --events "$NEV" --seed "$NUM" --lhe "$lhe"
        printf '\nBeams:LHEF = %s\nMain:numberOfEvents = %s\n' "$lhe" "$NEV" >> card.cmd
        ;;
    mg5*)
        lhe=$PWD/events.lhe.gz
        templates=${MG5_TEMPLATE_DIR:-${SIMDIR:-${root}/cld/CLDConfig}/mg5}
        envsubst < "$templates/$sample.template" > "$sample.mg5"
        mg5_aMC "$sample.mg5"
        ln -s "$PWD/$sample/Events/${sample}_seed${NUM}/unweighted_events.lhe.gz" "$lhe"
        printf '\nBeams:LHEF = %s\nMain:numberOfEvents = %s\n' "$lhe" "$NEV" >> card.cmd
        ;;
esac
{
    printf 'collider=%s\nsample=%s\nseed=%s\nevents=%s\n' "$collider" "$sample" "$NUM" "$NEV"
    if [[ $collider == fccee ]]; then
        printf 'cards_commit=%s\n' "$(git -C "$root/cld/CLDConfig" rev-parse HEAD)"
    else
        printf 'cards_commit=%s\n' "$(git -C "$root" rev-parse HEAD)"
    fi
    sha256sum "$source_card" card.cmd "$root/pythia/generate.py"
} > generation.software.txt
k4run "$root/pythia/generate.py" -n "$NEV" --Dumper.Filename "$PWD/out.hepmc" \
    --Pythia8.PythiaInterface.pythiacard "$PWD/card.cmd"
