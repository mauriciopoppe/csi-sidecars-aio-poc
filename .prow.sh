#! /bin/bash
set -e

export PULL_BASE_REF=master
export REGISTRY_NAME=ghcr.io/mauriciopoppe/csi-sidecars-aio-poc

HW_ARCH=$(uname -m)
if [[ "${HW_ARCH}" == "aarch64" ]]; then
  export CSI_PROW_BUILD_PLATFORMS="linux arm64 arm64"
elif [[ "${HW_ARCH}" == "x86_64" ]]; then
  export CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64"
else
  echo "Unsupported hardware arch $HW_ARCH"
  exit 1
fi

# Taken from https://github.com/kubernetes/test-infra/blob/d51e148c34558d18b492a52bdb3e4a0e84492359/config/jobs/kubernetes-csi/external-attacher/external-attacher-config.yaml#L131
export CSI_PROW_GO_VERSION_BUILD="1.24.3"
export CSI_PROW_GO_VERSION_E2E="1.24.3"
# This variable controls:
# - The version to use in kind
# - After pulling the k8s codebase, the tag to checkou to.
#
# Therefore, to keep this up to date:
# - update release-tools/prow.sh's CSI_PROW_KIND_IMAGES variable to match upstream.
export CSI_PROW_KUBERNETES_VERSION="1.31.9"
export CSI_PROW_DEPLOYMENT_SUFFIX=""
export CSI_PROW_DRIVER_VERSION="v1.12.1"
# This variable controls the CRDs for snapshotter
#
# To keep this up to date:
# - Also update deploy/<k8s-version>/hostpath/csi-hostpath-plugin.yaml image
#   for csi-snapshotter to match this version.
export CSI_SNAPSHOTTER_VERSION="v8.2.0"
export CSI_PROW_TESTS="sanity parallel"

. release-tools/prow.sh

main
