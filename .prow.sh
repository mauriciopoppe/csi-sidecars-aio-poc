#! /bin/bash
set -e

export PULL_BASE_REF=master
export REGISTRY_NAME=ghcr.io/mauriciopoppe/csi-sidecars-aio-poc
export CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64"
# Taken from https://github.com/kubernetes/test-infra/blob/d51e148c34558d18b492a52bdb3e4a0e84492359/config/jobs/kubernetes-csi/external-attacher/external-attacher-config.yaml#L131
export CSI_PROW_GO_VERSION_BUILD="1.22.3"
export CSI_PROW_GO_VERSION_E2E="1.22.3"
export CSI_PROW_KUBERNETES_VERSION="1.29.4"
export CSI_PROW_DEPLOYMENT_SUFFIX=""
export CSI_PROW_DRIVER_VERSION="v1.12.1"
export CSI_SNAPSHOTTER_VERSION="v6.1.0"
export CSI_PROW_TESTS="sanity parallel"

. release-tools/prow.sh

main
