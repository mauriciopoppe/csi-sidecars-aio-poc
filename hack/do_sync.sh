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

if [[ ! $(go version) =~ go1.24 ]]; then
  echo "Install go1.24, please read the README.md"
  exit 1
fi
TRASH="trash"
if ! command -v trash; then
  TRASH="rm -rf"
fi

mkdir -p tmp pkg cmd/csi-sidecars/ staging/src/github.com/kubernetes-csi/

for i in attacher,master provisioner,master resizer,master; do
  IFS=',' read SIDECAR SIDECAR_HASH <<< "${i}"
  if [[ ! -d pkg/${SIDECAR} ]]; then
    git clone https://github.com/kubernetes-csi/external-${SIDECAR} pkg/${SIDECAR}
    (cd pkg/${SIDECAR} && git checkout ${SIDECAR_HASH})

    cat pkg/${SIDECAR}/go.mod | grep "	" | grep -v "indirect" >> tmp/gomod-require.txt
    cat pkg/${SIDECAR}/go.mod | { grep "replace " || [[ $? == 1 ]] } >> tmp/gomod-replace.txt

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

    (cd pkg/${SIDECAR}; find . -type f -exec grep -q "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches {} \; -print)

    (cd pkg/${SIDECAR}; find . -type f -exec grep -q "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches {} \; -print | \
	    xargs sed -E -i".bak" "s%github.com/kubernetes-csi/external-${SIDECAR}/(v[0-9]+/)?%github.com/kubernetes-csi/csi-sidecars/pkg/${SIDECAR}/%g")
  fi

  for FILE in pkg/${SIDECAR}/cmd/csi-${SIDECAR}/*.go; do
    NEW_FILE="cmd/csi-sidecars/${SIDECAR}_$(basename ${FILE})"
    cp -v -- "${FILE}" "${NEW_FILE}"
    # Rename main()
    sed -i".bak" "s/func main()/func ${SIDECAR}_main(ctx context.Context)/g" "${NEW_FILE}"
    # Remove variables (mostly flags)
    sed -i".bak" '/^var (/,/^)/d' "${NEW_FILE}"
    # Pass context from main.go
    sed -i".bak" '/ctx :=/d' "${NEW_FILE}"
    sed -i".bak" 's/context.TODO()/ctx/g' "${NEW_FILE}"

    # Flags/logging code that must be removed
    sed -i".bak" '/flag.Var/d' "${NEW_FILE}"
    sed -i".bak" '/featuregate.NewFeatureGate/d' "${NEW_FILE}"
    sed -i".bak" '/logsapi.AddFeatureGates/d' "${NEW_FILE}"
    sed -i".bak" '/Options are:/d' "${NEW_FILE}"
    sed -i".bak" '/logsapi.NewLoggingConfiguration/d' "${NEW_FILE}"
    sed -i".bak" '/logsapi.AddGoFlags/d' "${NEW_FILE}"
    sed -i".bak" '/logs.InitLogs/d' "${NEW_FILE}"
    sed -i".bak" '/flag.Parse/d' "${NEW_FILE}"
    sed -i".bak" '/logsapi.ValidateAndApply/,/}/d' "${NEW_FILE}"
    sed -i".bak" '/klog.InitFlags/d' "${NEW_FILE}"
    sed -i".bak" '/logtostderr/d' "${NEW_FILE}"
    sed -i".bak" '/utilfeature.DefaultMutableFeatureGate/,/}/d' "${NEW_FILE}"
    sed -i".bak" '/flag.CommandLine.AddGoFlagSet/d' "${NEW_FILE}"

    # Dead imports
    sed -i".bak" '/goflag/d' "${NEW_FILE}"
    sed -i".bak" '/flag"/d' "${NEW_FILE}"
    sed -i".bak" '/featuregate"/d' "${NEW_FILE}"
    sed -i".bak" '/logs/d' "${NEW_FILE}"
    if [ "${SIDECAR}" = "resizer" ]; then
      sed -i".bak" '/strings/d' "${NEW_FILE}"
    fi

  done
done

# Create merged go.mod
cat <<EOF >go.mod
module github.com/kubernetes-csi/csi-sidecars

go 1.23.1

require (
EOF
cat tmp/gomod-require.txt | sort | uniq >> go.mod
cat <<EOF >>go.mod
)

EOF
cat tmp/gomod-replace.txt | sort | uniq >> go.mod
go mod tidy

# Use our customized cmd/main.go
cp hack/main.go cmd/csi-sidecars/main.go

cat <<EOF >Makefile
CMDS=csi-sidecars
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
# PULL_BASE_REF=master REGISTRY_NAME=368597081700.dkr.ecr.us-west-2.amazonaws.com/csi-sidecar-aio-poc CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64" ./.cloudbuild.sh
