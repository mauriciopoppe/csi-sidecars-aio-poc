#!/bin/bash
set -euxo pipefail

# removes all the generated files
trash pkg/attacher cmd staging go.mod go.sum go.work go.work.sum
