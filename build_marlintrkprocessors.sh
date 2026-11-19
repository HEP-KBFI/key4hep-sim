#!/usr/bin/env bash
# Build the ILD mass refitter overlay against the stable Key4hep release.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root/setup.sh"
commit=902d36d9999d46272ecb7ba06addde5a45f1bb33
patch_file="$root/patches/MarlinTrkProcessors-v02-12-08-missing-refit-seed.patch"
install_dir="$KEY4HEP_LOCAL_ROOT/install/MarlinTrkProcessors"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
git clone --quiet --depth 1 --branch v02-12-08 https://github.com/iLCSoft/MarlinTrkProcessors.git "$scratch/source"
test "$(git -C "$scratch/source" rev-parse HEAD)" = "$commit"
git -C "$scratch/source" apply "$patch_file"
cmake -G Ninja -S "$scratch/source" -B "$scratch/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$scratch/build" --parallel "${BUILD_JOBS:-4}"
install -D -m 755 "$scratch/build/lib/libMarlinTrkProcessors.so" \
    "$install_dir/lib/libMarlinTrkProcessors.so"
printf '%s\n' "$KEY4HEP_BASE_ID" "$(sha256sum "$patch_file" | cut -d ' ' -f 1)" > "$install_dir/.key4hep-refitter-id"
