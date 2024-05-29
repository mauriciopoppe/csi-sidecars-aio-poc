#! /bin/bash
set -e

export PULL_BASE_REF=master
export REGISTRY_NAME=ghcr.io/mauriciopoppe/csi-sidecars-aio-poc
export CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64"

. release-tools/prow.sh

main
