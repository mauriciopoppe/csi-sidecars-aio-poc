#!/bin/bash
set -euxo pipefail

TRASH="trash"
if ! command -v trash; then
  TRASH="rm -rf"
fi

# removes all the generated files
${TRASH} pkg cmd staging vendor go.mod go.sum go.work go.work.sum tmp
