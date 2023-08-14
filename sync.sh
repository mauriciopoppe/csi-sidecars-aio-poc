#!/bin/bash
set -euxo pipefail

FROM_SCRATCH="${FROM_SCRATCH:-false}"

cond_exec() {
  if [[ $FROM_SCRATCH == "true" ]]; then
    eval $@
  fi
  echo $@
}

cond_exec trash pkg cmd staging go.mod go.sum go.work go.work.sum
mkdir -p pkg cmd/csi-sidecars/ staging/src/github.com/kubernetes-csi/

if [[ ! -d pkg/attacher ]]; then
  git clone https://github.com/kubernetes-csi/external-attacher pkg/attacher

  cp pkg/attacher/go.mod go.mod
  sed -i "1 s%.*%module github.com/kubernetes-csi/csi-sidecars%" go.mod

  trash pkg/attacher/.git
  trash pkg/attacher/.github
  trash pkg/attacher/vendor
  trash pkg/attacher/release-tools
  trash pkg/attacher/go.mod
  trash pkg/attacher/go.sum
  trash pkg/attacher/Dockerfile
  trash pkg/attacher/.cloudbuild.sh
  trash pkg/attacher/cloudbuild.yaml
  trash pkg/attacher/.prow.sh
  trash pkg/attacher/OWNER_ALIASES
  trash pkg/attacher/Makefile

  (cd pkg/attacher; rg "github.com/kubernetes-csi/external-attacher/" --files-with-matches | \
    xargs sed -i "s%github.com/kubernetes-csi/external-attacher/%github.com/kubernetes-csi/csi-sidecars/pkg/attacher/%g")

  cp pkg/attacher/cmd/csi-attacher/main.go cmd/csi-sidecars/main.go
fi

go mod tidy

csi_release_tools=staging/src/github.com/kubernetes-csi/csi-release-tools
if [[ ! -d ${csi_release_tools} ]]; then
  git clone https://github.com/kubernetes-csi/csi-release-tools ${csi_release_tools}

  trash ${csi_release_tools}/.git

  (cd $csi_release_tools; rg "release-tools" --files-with-matches | \
    xargs sed -i "s%release-tools%${csi_release_tools}%g")
fi

cat <<\EOF >Makefile
CMDS="csi-sidecars"
all: build

include staging/src/github.com/kubernetes-csi/csi-release-tools/build.make
EOF

csi_lib_utils=staging/src/github.com/kubernetes-csi/csi-lib-utils
if [[ ! -d ${csi_lib_utils} ]]; then
  git clone https://github.com/kubernetes-csi/csi-lib-utils ${csi_lib_utils}

  trash ${csi_lib_utils}/.git
  trash ${csi_lib_utils}/.github
  trash ${csi_lib_utils}/vendor
  trash ${csi_lib_utils}/release-tools

  # (cd $csi_lib_utils; rg "github.com/kubernetes-csi/csi-lib-utils" --files-with-matches | \
    # xargs sed -i "s%github.com/kubernetes-csi/csi-lib-utils%github.com/kubernetes-csi/csi-sidecars/${csi_lib_utils}%g")

  # proof that go workspace is working
  # Create a method that doesn't exist in csi-lib-utils
  cat <<EOF >>${csi_lib_utils}/connection/connection.go
func HelloWorld() {
  klog.Info("Hello world!")
}
EOF

  if grep -q "// Connect to CSI" cmd/csi-sidecars/main.go; then
    sed -i "s%// Connect to CSI.%// Override\!\nconnection.HelloWorld()%g" cmd/csi-sidecars/main.go
  fi
fi

trash go.work go.sum
go work init .
go work use ./staging/src/github.com/kubernetes-csi/csi-lib-utils
go mod tidy

# checkpoint: test that we can build attacher
if ! grep -q "HelloWorld" cmd/csi-sidecars/main.go; then
  echo "Expected to find override to test that go workspaces work!"
  exit 1
fi
make build

cat <<'EOF' > Dockerfile
FROM gcr.io/distroless/static:latest
LABEL maintainers="Kubernetes Authors"
LABEL description="CSI Sidecars"
ARG binary=./bin/csi-sidecars

COPY ${binary} csi-sidecars
ENTRYPOINT ["/csi-sidecars"]
EOF

cat <<'EOF' > .cloudbuild.sh
. staging/src/github.com/kubernetes-csi/csi-release-tools/prow.sh
gcr_cloud_build
EOF

# chmod +x .cloudbuild.sh
# PULL_BASE_REF=master REGISTRY_NAME=gcr.io/foo CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64" ./.cloudbuild.sh
