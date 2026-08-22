#!/bin/bash
set -euxo pipefail

# The generated artifacts live at the repository root; resolve it from the script
# location so the cleanup can be started from any directory.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

TRASH="trash"
if ! command -v trash; then
  TRASH="rm -rf"
fi

# removes all the generated files
${TRASH} pkg cmd staging vendor go.mod go.sum go.work go.work.sum tmp bin
