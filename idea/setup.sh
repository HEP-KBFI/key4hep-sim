#!/bin/bash
# Common stable runtime plus detector-specific source overlays.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/setup.sh" || return 1
idea_use_local() { key4hep_use_local "$@"; }
