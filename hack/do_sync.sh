#!/bin/bash
set -euxo pipefail

if [[ $(uname) != "Linux" ]]; then
  echo "This script only works in Linux arm64/amd64, yours is $(uname)"
  exit 1
fi

# Set to true to skip the sanity checks.
SKIP_SANITY_CHECK="${SKIP_SANITY_CHECK:-}"

DRY_RUN="${DRY_RUN:-false}"
# cond_exec executes arguments if DRY_RUN=true, otherwise it just echo them
cond_exec() {
  if [[ $DRY_RUN == "true" ]]; then
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

# symlink_from_root_to_hack creates a simlink from a file in project root to hack.
#
# Usage:
# symlink_from_root_to_hack <hack/ prefixed directory>
#
# Example:
# symlink_from_root_to_hack hack/cmd/csi-sidecars/main.go
# (creates the symlink cmd/csi-sidecars/main.go -> hack/cmd/csi-sidecars/main.go)
symlink_from_root_to_hack() {
  file="$1"
  # strip hack/ prefix
  file_without_hack="${file#hack/}"
  mkdir -p "$(dirname $file_without_hack)"
  ln -s $PWD/$file $PWD/$file_without_hack
}

# loop params: [repository,branch,repo_prefix]
# repo_prefix: 'external-' for attacher/provisioner/resizer, '' for node-driver-registrar
for i in "attacher,master,external-" "provisioner,master,external-" "resizer,master,external-" "node-driver-registrar,master,"; do
  IFS=',' read SIDECAR SIDECAR_HASH REPO_PREFIX <<<"${i}"
  if [[ ! -d pkg/${SIDECAR} ]]; then
    git clone --depth 1 https://github.com/kubernetes-csi/${REPO_PREFIX}${SIDECAR} pkg/${SIDECAR}
    (
      cd pkg/${SIDECAR}
      git checkout ${SIDECAR_HASH}
      git rev-parse --short HEAD
    )

    cat pkg/${SIDECAR}/go.mod | grep "	" | grep -v "indirect" >>tmp/gomod-require.txt

    # NOTE: the sed command is to keep consistent package relies among different repos.
    cat pkg/${SIDECAR}/go.mod | { grep "replace " || [[ $? == 1 ]]; } | sed 's/v0.34.0/v0.34.1/g' >>tmp/gomod-replace.txt

    # Checks for drifts in k8s.io/api, drifts in core dependencies are sometimes impossible to solve
    # e.g. attacher requiring k8s v0.34 and provisioner requiring v0.33.
    cat pkg/${SIDECAR}/go.mod | grep "replace k8s.io/api =>" >>tmp/gomod-k8sapi.txt

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

    (
      cd pkg/${SIDECAR}
      find . -type f -exec grep -q "github.com/kubernetes-csi/${REPO_PREFIX}${SIDECAR}/" --files-with-matches {} \; -print
    )

    (
      cd pkg/${SIDECAR}
      find . -type f -exec grep -q "github.com/kubernetes-csi/${REPO_PREFIX}${SIDECAR}/" --files-with-matches {} \; -print |
        xargs sed -E -i".bak" "s%github.com/kubernetes-csi/${REPO_PREFIX}${SIDECAR}/(v[0-9]+/)?%github.com/kubernetes-csi/csi-sidecars/pkg/${SIDECAR}/%g"
    )
  fi

  # After cloning a CSI repository its entrypoints have additional code that now belong
  # to this codebase, for example:
  #
  # - A main() function - CSI repositories no longer need them.
  # - Flags, logging code
  # may have code that
  for FILE in pkg/${SIDECAR}/cmd/csi-${SIDECAR}/*.go; do
    NEW_FILE="cmd/csi-sidecars/${SIDECAR}_$(basename ${FILE})"
    cp -v -- "${FILE}" "${NEW_FILE}"
    # Rename main()
    sed -i".bak" "s/func main()/func ${SIDECAR//-/_}_main(ctx context.Context)/g" "${NEW_FILE}"
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
    sed -i".bak" '/logsapi.AddFlags/d' "${NEW_FILE}"
    sed -i".bak" '/logs.InitLogs/d' "${NEW_FILE}"
    sed -i".bak" '/flag.Parse/d' "${NEW_FILE}"
    sed -i".bak" '/logsapi.ValidateAndApply/,/}/d' "${NEW_FILE}"
    sed -i".bak" '/klog.InitFlags/d' "${NEW_FILE}"
    sed -i".bak" '/logtostderr/d' "${NEW_FILE}"
    # sed -i".bak" '/utilfeature.DefaultMutableFeatureGate/,/}/d' "${NEW_FILE}"
    sed -i".bak" '/^\tif !utilfeature\.DefaultMutableFeatureGate/,/^\t}/d' "${NEW_FILE}"
    sed -i".bak" '/flag.CommandLine.AddGoFlagSet/d' "${NEW_FILE}"

    # TODO: handle setting the automaxproc flag from each sidecar>
    # In the meantime remove setting the flag and handle it in the AIO sidecar.
    # https://github.com/mauriciopoppe/csi-sidecars-aio-poc/issues/14
    sed -i".bak" '/standardflags.AddAutomaxprocs/d' "${NEW_FILE}"
    sed -i".bak" '/csistdflags.AddAutomaxprocs/d' "${NEW_FILE}"

    # Dead imports
    sed -i".bak" '/goflag/d' "${NEW_FILE}"
    sed -i".bak" '/flag"/d' "${NEW_FILE}"
    sed -i".bak" '/featuregate"/d' "${NEW_FILE}"
    sed -i".bak" '/logs/d' "${NEW_FILE}"
    sed -i".bak" '/csi-lib-utils\/standardflags/d' "${NEW_FILE}"

    if [ "${SIDECAR}" = "resizer" ]; then
      sed -i".bak" '/strings/d' "${NEW_FILE}"
    fi
    if [ "${SIDECAR}" = "attacher" ]; then
      sed -i".bak" '/strings/d' "${NEW_FILE}"
    fi
  done

  # Temporary change that tests what it'd take to make a refactor in how flags are parsed,
  # it's tested later when building the individual sidecar.
  if [[ "${SIDECAR}" == "attacher" ]]; then
    rm pkg/attacher/cmd/csi-attacher/main.go
    # This file was forked and manually edited to test the flag initialization feature strategy
    # described in https://docs.google.com/document/d/1AKqJeAlBL8PkH8D9zABCZ82Bk1N46EygKPvVh5p4-qU/edit?tab=t.0
    # For more info read the comments that say `override`
    symlink_from_root_to_hack hack/pkg/attacher/cmd/csi-attacher/main.go
  fi
done

# Sanity checks
echo "Sanity checks"

echo "Check that the k8s.io dependencies match"
if [[ ${SKIP_SANITY_CHECK} != "true" ]] && [[ $(cat tmp/gomod-k8sapi.txt | sort | uniq | wc -l) -gt 1 ]]; then
  echo "There are multiple k8s.io versions as dependencies from sidecars!"
  echo "Check the go.mod of each sidecar and verify that the k8s.io dependencies match"
  cat tmp/gomod-k8sapi.txt
  exit 1
fi

# The new entrypoint for all the sidecars
symlink_from_root_to_hack hack/cmd/csi-sidecars/main.go
# The utility global function to register common and per-sidecar flags.
symlink_from_root_to_hack hack/cmd/csi-sidecars/config/flags.go
# The utility glofal functions to register attacher flags.
symlink_from_root_to_hack hack/pkg/attacher/cmd/csi-attacher/config/flags.go

# Create merged go.mod
cat <<EOF >go.mod
module github.com/kubernetes-csi/csi-sidecars

go 1.23.1

require (
EOF
cat tmp/gomod-require.txt | sort | uniq >>go.mod
cat <<EOF >>go.mod
)

EOF
cat tmp/gomod-replace.txt | sort | uniq >>go.mod
go mod tidy

# The makefile
cat <<EOF >Makefile
CMDS=csi-sidecars
all: build

include release-tools/build.make
EOF

# Clone csi-libe utils into the staging/ directory and add an override to use the local copy in go.mod
csi_lib_utils=staging/src/github.com/kubernetes-csi/csi-lib-utils
if [[ ! -d ${csi_lib_utils} ]]; then
  git clone https://github.com/kubernetes-csi/csi-lib-utils ${csi_lib_utils}

  ${TRASH} ${csi_lib_utils}/.git
  ${TRASH} ${csi_lib_utils}/.github
  ${TRASH} ${csi_lib_utils}/vendor
  ${TRASH} ${csi_lib_utils}/release-tools

  if ! grep -q "./staging/src/github.com/kubernetes-csi/csi-lib-utils" go.mod; then
    echo "replace github.com/kubernetes-csi/csi-lib-utils => ./staging/src/github.com/kubernetes-csi/csi-lib-utils" >>go.mod
  fi
fi

# go.work setup
${TRASH} go.work go.sum
go work init .
go work use ./staging/src/github.com/kubernetes-csi/csi-lib-utils
go mod tidy
go work vendor

# checkpoint: test that we can build the project.
make build
./bin/csi-sidecars --help || true

# checkpoint for individual sidecar refactor: test that we can build attacher
go build -a -ldflags ' -X main.version=foo -extldflags "-static"' -o ./bin/csi-attacher ./pkg/attacher/cmd/csi-attacher
./bin/csi-attacher --help || true

# cat <<'EOF' >Dockerfile
# FROM gcr.io/distroless/static:latest
# LABEL maintainers="Kubernetes Authors"
# LABEL description="CSI Sidecars"
# ARG binary=./bin/csi-sidecars
# COPY ${binary} csi-sidecars
# ENTRYPOINT ["/csi-sidecars"]
# EOF
#
# export PULL_BASE_REF=master
# export REGISTRY_NAME=ghcr.io/mauriciopoppe/csi-sidecars-aio-poc
# HW_ARCH=$(uname -m)
# if [[ "${HW_ARCH}" == "aarch64" ]]; then
#   export CSI_PROW_BUILD_PLATFORMS="linux arm64 arm64"
# elif [[ "${HW_ARCH}" == "x86_64" ]]; then
#   export CSI_PROW_BUILD_PLATFORMS="linux amd64 amd64"
# else
#   echo "Unsupported hardware arch $HW_ARCH"
#   exit 1
# fi
# make container GOFLAGS_VENDOR="-mod=vendor" BUILD_PLATFORMS=${CSI_PROW_BUILD_PLATFORMS}
