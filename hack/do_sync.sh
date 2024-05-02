#!/bin/bash
set -euxo pipefail

FROM_SCRATCH="${FROM_SCRATCH:-false}"

# cond_exec executes arguments if FROM_SCRATCH=true
# otherwise it just echo them
cond_exec() {
  if [[ $FROM_SCRATCH == "true" ]]; then
    eval $@
  fi
  echo $@
}

if [[ ! $(go version) == *go1.22* ]]; then
  echo "Install go1.22, please read the README.md"
  exit 1
fi
if ! command -v rg; then
  echo "Install ripgrep"
  exit 1
fi
TRASH="trash"
if ! command -v trash; then
  TRASH="rm -rf"
fi

mkdir -p tmp pkg cmd/csi-sidecars/ staging/src/github.com/kubernetes-csi/

for SIDECAR in attacher provisioner resizer; do
  if [[ ! -d pkg/${SIDECAR} ]]; then
    git clone --depth 1 https://github.com/kubernetes-csi/external-${SIDECAR} pkg/${SIDECAR}

    cat pkg/${SIDECAR}/go.mod | grep "	" | grep -v "indirect" >> tmp/gomod-require.txt
    cat pkg/${SIDECAR}/go.mod | grep "replace " >> tmp/gomod-replace.txt

    ${TRASH} pkg/${SIDECAR}/.git
    ${TRASH} pkg/${SIDECAR}/.github
    ${TRASH} pkg/${SIDECAR}/vendor
    ${TRASH} pkg/${SIDECAR}/release-tools
    ${TRASH} pkg/${SIDECAR}/go.mod
    ${TRASH} pkg/${SIDECAR}/go.sum
    ${TRASH} pkg/${SIDECAR}/Dockerfile
    ${TRASH} pkg/${SIDECAR}/.cloudbuild.sh
    ${TRASH} pkg/${SIDECAR}/cloudbuild.yaml
    ${TRASH} pkg/${SIDECAR}/.prow.sh
    ${TRASH} pkg/${SIDECAR}/OWNER_ALIASES
    ${TRASH} pkg/${SIDECAR}/Makefile

    (cd pkg/${SIDECAR}; rg "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches | \
      xargs sed -i "s%github.com/kubernetes-csi/external-${SIDECAR}/%github.com/kubernetes-csi/csi-sidecars/pkg/${SIDECAR}/%g")
  fi

  for FILE in pkg/${SIDECAR}/cmd/csi-${SIDECAR}/*.go; do
    NEW_FILE="cmd/csi-sidecars/${SIDECAR}_$(basename ${FILE})"
    cp -v -- "${FILE}" "${NEW_FILE}"
    # Rename main()
    sed -i "s/func main()/func ${SIDECAR}_main(ctx context.Context)/g" "${NEW_FILE}"
    # Remove variables (mostly flags)
    sed -i '/^var (/,/^)/d' "${NEW_FILE}"
    # Pass context from main.go
    sed -i '/ctx :=/d' "${NEW_FILE}"
    sed -i 's/context.TODO()/ctx/g' "${NEW_FILE}"

    # Flags/logging code that must be removed
    sed -i '/flag.Var/d' "${NEW_FILE}"
    sed -i '/featuregate.NewFeatureGate/d' "${NEW_FILE}"
    sed -i '/logsapi.AddFeatureGates/d' "${NEW_FILE}"
    sed -i '/Options are:/d' "${NEW_FILE}"
    sed -i '/logsapi.NewLoggingConfiguration/d' "${NEW_FILE}"
    sed -i '/logsapi.AddGoFlags/d' "${NEW_FILE}"
    sed -i '/logs.InitLogs/d' "${NEW_FILE}"
    sed -i '/flag.Parse/d' "${NEW_FILE}"
    sed -i '/logsapi.ValidateAndApply/,/}/d' "${NEW_FILE}"
    sed -i '/klog.InitFlags/d' "${NEW_FILE}"
    sed -i '/logtostderr/d' "${NEW_FILE}"
    sed -i '/utilfeature.DefaultMutableFeatureGate/,/}/d' "${NEW_FILE}"
    sed -i '/flag.CommandLine.AddGoFlagSet/d' "${NEW_FILE}"

    # Dead imports
    sed -i '/goflag/d' "${NEW_FILE}"
    sed -i '/flag"/d' "${NEW_FILE}"
    sed -i '/featuregate"/d' "${NEW_FILE}"
    sed -i '/logs/d' "${NEW_FILE}"
    if [ "${SIDECAR}" = "resizer" ]; then
      sed -i '/strings/d' "${NEW_FILE}"
    fi
  done
done

# Create merged go.mod
cat <<EOF >go.mod
module github.com/kubernetes-csi/csi-sidecars

go 1.21

require (
EOF
cat tmp/gomod-require.txt | sort | uniq >> go.mod
cat <<EOF >>go.mod
)

EOF
cat tmp/gomod-replace.txt | sort | uniq >> go.mod
go mod tidy

# Copy our main.go in
cp hack/main.go cmd/csi-sidecars/main.go

csi_release_tools=release-tools
if [[ ! -d ${csi_release_tools} ]]; then
  git clone https://github.com/kubernetes-csi/csi-release-tools ${csi_release_tools}

  ${TRASH} ${csi_release_tools}/.git
fi

cat <<EOF >Makefile
CMDS="csi-sidecars"
all: build

include release-tools/build.make
EOF

csi_lib_utils=staging/src/github.com/kubernetes-csi/csi-lib-utils
if [[ ! -d ${csi_lib_utils} ]]; then
  git clone https://github.com/kubernetes-csi/csi-lib-utils ${csi_lib_utils}

  ${TRASH} ${csi_lib_utils}/.git
  ${TRASH} ${csi_lib_utils}/.github
  ${TRASH} ${csi_lib_utils}/vendor
  ${TRASH} ${csi_lib_utils}/release-tools

  # (cd $csi_lib_utils; rg "github.com/kubernetes-csi/csi-lib-utils" --files-with-matches | \
    # xargs sed -i "s%github.com/kubernetes-csi/csi-lib-utils%github.com/kubernetes-csi/csi-sidecars/${csi_lib_utils}%g")

  if ! grep -q "./staging/src/github.com/kubernetes-csi/csi-lib-utils" go.mod; then
    echo "replace github.com/kubernetes-csi/csi-lib-utils => ./staging/src/github.com/kubernetes-csi/csi-lib-utils" >> go.mod
  fi
fi

${TRASH} go.work go.sum
go work init .
go work use ./staging/src/github.com/kubernetes-csi/csi-lib-utils
go mod tidy
go work vendor

# checkpoint: test that we can build
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
. release-tools/prow.sh
gcr_cloud_build
EOF

# TODO: This command doesn't work in my arm mac
# chmod +x .cloudbuild.sh
# docker run -v $PWD:/app -w /app debian /bin/bash -c 'apt-get -y update; apt-get -y install make curl; PULL_BASE_REF=master REGISTRY_NAME=368597081700.dkr.ecr.us-west-2.amazonaws.com/csi-sidecar-aio-poc CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64" ./.cloudbuild.sh'

PULL_BASE_REF=master REGISTRY_NAME=368597081700.dkr.ecr.us-west-2.amazonaws.com/csi-sidecar-aio-poc CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64" ./.cloudbuild.sh
