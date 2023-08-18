#!/bin/bash
set -euxo pipefail

# removes all the generated files
trash pkg release-tools cmd staging vendor go.mod go.sum go.work go.work.sum
