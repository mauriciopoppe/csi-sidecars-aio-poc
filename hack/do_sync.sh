#!/bin/bash
set -euxo pipefail

if [[ $(uname) != "Linux" ]]; then
  echo "This script only works in Linux arm64/amd64, yours is $(uname)"
  exit 1
fi

# ==============================================================================
# DEVELOPER WORKSPACE PATH NORMALIZATION
# ==============================================================================
# When developers run this synchronization script locally, their terminal output
# and the resulting 'hack/do_sync.log' file capture absolute file paths unique to
# their specific machine/box (e.g., '/home/mauriciopoppe.linux' or '/root').
#
# Since 'hack/do_sync.log' is a tracked file in version control (linked by the
# README.md as a reference log of a successful synchronization), these absolute
# paths cause persistent git diff noise and merge conflicts whenever different
# developers run the tooling.
#
# To solve this cleanly without manual post-processing, the block below intercepts
# the script execution. If 'NORMALIZED_LOGGING' is not active, it re-executes the
# script and filters all stdout and stderr in real-time through GNU 'sed'.
# Any absolute path matching the current working directory ($PWD) or the user's
# home directory ($HOME) is replaced with generic placeholders ('$WORKSPACE'
# and '$HOME' respectively).
#
# Because 'set -o pipefail' is active (line 2), the exit status of the underlying
# execution is correctly preserved and bubbled up to the caller (or CI runner).
# ==============================================================================
if [[ "${NORMALIZED_LOGGING:-}" != "true" ]]; then
  export NORMALIZED_LOGGING=true
  escaped_pwd=$(echo "$PWD" | sed 's/[.[\*^$]/\\&/g')
  escaped_home=$(echo "$HOME" | sed 's/[.[\*^$]/\\&/g')
  "$0" "$@" 2>&1 | sed -u -e "s|$escaped_pwd|\$WORKSPACE|g" -e "s|$escaped_home|\$HOME|g"
  exit $?
fi


if [[ -z ${VIRTUAL_ENV:-} ]]; then
  echo "This script must run within a virtual env"
  echo "  python3 -m venv .venv && source .venv/bin/activate "
  exit 1
fi

if ! command -v git-filter-repo >/dev/null; then
  echo "git-filter-repo is required, installing it..."
  pip install git-filter-repo
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

if [[ ! $(go version) =~ go1.2[6-9] ]]; then
  echo "Install go1.26+, please read the README.md"
  exit 1
fi
TRASH="trash"
if ! command -v trash; then
  TRASH="rm -rf"
fi

mkdir -p tmp pkg cmd/csi-sidecars/ staging/src/github.com/kubernetes-csi/

# Initialize the target repo for merged commit history
if [[ ! -d tmp/csi-sidecars ]]; then
  mkdir -p tmp/csi-sidecars
  (cd tmp/csi-sidecars && git init)
fi

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
  ln -sf $PWD/$file $PWD/$file_without_hack
}

# loop params: [repository,branch]
for i in attacher,master provisioner,master resizer,master snapshotter,master; do
  IFS=',' read SIDECAR SIDECAR_HASH <<<"${i}"
  if [[ ! -d pkg/${SIDECAR} ]]; then
    git clone https://github.com/kubernetes-csi/external-${SIDECAR} tmp/external-${SIDECAR}
    (
      cd tmp/external-${SIDECAR}
      git checkout ${SIDECAR_HASH}
      git rev-parse --short HEAD

      # --force is required if we checkout to a different branch.
      git filter-repo \
        --commit-callback "
original_hash = commit.original_id.decode()
original_message = commit.message.decode()
new_message = f\"{original_message}\n\nImported-from: external-${SIDECAR}\n\nOriginal-commit-hash: {original_hash}\"
commit.message = new_message.encode()
        " \
        --to-subdirectory-filter pkg/${SIDECAR} --force
    )

    # Merge the rewritten sidecar history into the target repo
    (
      cd tmp/csi-sidecars
      git config user.email "csi-aio-sync@localhost"
      git config user.name "CSI AIO Sync"
      git remote add external-${SIDECAR} ../external-${SIDECAR} || true
      git fetch external-${SIDECAR}
      git merge external-${SIDECAR}/${SIDECAR_HASH} --allow-unrelated-histories --no-edit --quiet >/dev/null
    )

    # Copy the sidecar files (without .git) for processing
    cp -a tmp/external-${SIDECAR}/pkg/${SIDECAR} pkg/${SIDECAR}

    cat pkg/${SIDECAR}/go.mod | grep "	" | grep -v "indirect" >>tmp/gomod-require.txt

    # NOTE: the sed command is to keep consistent package relies among different repos.
    cat pkg/${SIDECAR}/go.mod | { grep "replace " || [[ $? == 1 ]]; } | sed 's/v0.35.0/v0.35.2/g' | { grep -v "=> ./client" || [[ $? == 1 ]]; } >>tmp/gomod-replace.txt


    # Checks for drifts in k8s.io/api, drifts in core dependencies are sometimes impossible to solve
    # e.g. attacher requiring k8s v0.34 and provisioner requiring v0.33.
    # NOTE: the sed command is temporary while provisioner adopts a more recent version of k8s, check #18 for more info.
    cat pkg/${SIDECAR}/go.mod | { grep "replace k8s.io/api =>" || [[ $? == 1 ]]; } >>tmp/gomod-k8sapi.txt

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

    if [ "${SIDECAR}" = "snapshotter" ]; then
      ${TRASH} pkg/${SIDECAR}/client/.git
      ${TRASH} pkg/${SIDECAR}/client/go.mod
      ${TRASH} pkg/${SIDECAR}/client/go.sum
      ${TRASH} pkg/${SIDECAR}/client/hack
      ${TRASH} pkg/${SIDECAR}/CHANGELOG
      ${TRASH} pkg/${SIDECAR}/examples
      ${TRASH} pkg/${SIDECAR}/deploy
      ${TRASH} pkg/${SIDECAR}/hack
      # snapshot-conversion-webhook is kept as an independent binary in cmd/snapshot-conversion-webhook
      # ${TRASH} pkg/${SIDECAR}/cmd/snapshot-conversion-webhook
      ${TRASH} pkg/${SIDECAR}/SECURITY_CONTACTS
      ${TRASH} pkg/${SIDECAR}/code-of-conduct.md
      ${TRASH} pkg/${SIDECAR}/CONTRIBUTING.md
      ${TRASH} pkg/${SIDECAR}/OWNERS_ALIASES
    fi

    (
      cd pkg/${SIDECAR}
      find . -type f -exec grep -q "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches {} \; -print
    )

    (
      cd pkg/${SIDECAR}
      if [ "${SIDECAR}" = "snapshotter" ]; then
        find . -type f -exec grep -q "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches {} \; -print |
          xargs -r sed -E -i".bak" -e "s%github.com/kubernetes-csi/external-snapshotter/v8/%github.com/kubernetes-csi/csi-sidecars/pkg/snapshotter/%g" \
                                -e "s%github.com/kubernetes-csi/external-snapshotter/client/v8/%github.com/kubernetes-csi/csi-sidecars/pkg/snapshotter/client/%g"
      else
        find . -type f -exec grep -q "github.com/kubernetes-csi/external-${SIDECAR}/" --files-with-matches {} \; -print |
          xargs -r sed -E -i".bak" "s%github.com/kubernetes-csi/external-${SIDECAR}/(v[0-9]+/)?%github.com/kubernetes-csi/csi-sidecars/pkg/${SIDECAR}/%g"
      fi
    )
  fi

  # After cloning a CSI repository its entrypoints have additional code that now belong
  # to this codebase, for example:
  #
  # - A main() function - CSI repositories no longer need them.
  # - Flags, logging code
  # may have code that
  for FILE in $(find pkg/${SIDECAR}/cmd/csi-${SIDECAR}/ -maxdepth 1 -name '*.go' ! -name '*_test.go'); do
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
    sed -i".bak" '/standardflags.RegisterCommonFlags/d' "${NEW_FILE}"

    # Standalone var version (outside var() blocks) conflicts with main.go
    sed -i".bak" '/^var version/d' "${NEW_FILE}"

    # Dead imports
    sed -i".bak" '/goflag/d' "${NEW_FILE}"
    sed -i".bak" '/flag"/d' "${NEW_FILE}"
    sed -i".bak" '/featuregate"/d' "${NEW_FILE}"
    sed -i".bak" '/logs/d' "${NEW_FILE}"

    if [ "${SIDECAR}" = "resizer" ]; then
      sed -i".bak" '/strings/d' "${NEW_FILE}"
    fi
    if [ "${SIDECAR}" = "attacher" ]; then
      sed -i".bak" '/strings/d' "${NEW_FILE}"
      # Remove flag registration that uses flag.CommandLine (handled by main.go via RegisterAttacherFlagsWithPrefix)
      sed -i".bak" '/RegisterAttacherFlags.*flag.CommandLine/d' "${NEW_FILE}"
      sed -i".bak" '/^var attacherConfiguration/d' "${NEW_FILE}"
      # Remove local var re-declarations that shadow globals set by copyFlagsFromConfigToGlobalVars
      sed -i".bak" '/attacherConfiguration\./d' "${NEW_FILE}"
      sed -i".bak" '/attacherconfiguration "/d' "${NEW_FILE}"
      # Replace standardflags.Configuration field accesses with global vars (order matters: longest match first)
      sed -i".bak" 's/standardflags\.Configuration\.ShowVersion/*showVersion/g' "${NEW_FILE}"
      sed -i".bak" 's/standardflags\.Configuration\.MetricsAddress/*metricsAddress/g' "${NEW_FILE}"
      sed -i".bak" 's/standardflags\.Configuration\.HttpEndpoint/*httpEndpoint/g' "${NEW_FILE}"
      sed -i".bak" 's/standardflags\.Configuration\.KubeConfig/*kubeconfig/g' "${NEW_FILE}"
      sed -i".bak" 's/standardflags\.Configuration\.CSIAddress/*csiAddress/g' "${NEW_FILE}"
      sed -i".bak" 's/standardflags\.Configuration\.MetricsPath/*metricsPath/g' "${NEW_FILE}"
      # Remove only the standardflags.RegisterCommonFlags import alias line if present,
      # but keep the standardflags package import and bare standardflags.Configuration
      # usages (passed to libconfig.BuildConfig and leaderelection.RunWithLeaderElection).
      # The field accesses (e.g. standardflags.Configuration.ShowVersion) were already
      # replaced with global vars above.
    fi
    if [ "${SIDECAR}" = "provisioner" ]; then
      # Remove pre-Go 1.21 max() helper that shadows the builtin
      sed -i".bak" '/^\/\/ max returns/,/^}/d' "${NEW_FILE}"
    fi
    if [ "${SIDECAR}" = "snapshotter" ]; then
      # NOTE: unlike other sidecars, do NOT remove strings import for snapshotter
      # because it's used in the leaderelection.RunWithLeaderElection call
      # Restore the prefix var that was inside var(...) block (stripped by sed)
      sed -i".bak" '/^func snapshotter_main/i\var snapshotterPrefix = "external-snapshotter-leader"' "${NEW_FILE}"
      sed -i".bak" 's/\bprefix\b/snapshotterPrefix/g' "${NEW_FILE}"
      # Rename colliding variables to avoid conflicts with other sidecar globals
      sed -i".bak" 's/\bthreads\b/snapshotterThreads/g' "${NEW_FILE}"
      sed -i".bak" 's/\bextraCreateMetadata\b/snapshotterExtraCreateMetadata/g' "${NEW_FILE}"
      sed -i".bak" 's/\benableNodeDeployment\b/snapshotterEnableNodeDeployment/g' "${NEW_FILE}"
      sed -i".bak" 's/\bcsiTimeout\b/snapshotterCSITimeout/g' "${NEW_FILE}"
      sed -i".bak" 's/\bbuildConfig\b/snapshotterBuildConfig/g' "${NEW_FILE}"
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

# Copy snapshot-controller entrypoint into its own independent cmd/ directory.
# Unlike the sidecar entrypoints which merge into cmd/csi-sidecars/main.go,
# snapshot-controller keeps its own main() as a separate binary.
# NOTE: Import path replacement for both the main module and the client module
# is already handled by the sed block inside pkg/snapshotter/ above, which
# recursively covers cmd/snapshot-controller/*.go.
mkdir -p cmd/snapshot-controller
cp -v pkg/snapshotter/cmd/snapshot-controller/*.go cmd/snapshot-controller/

# Copy snapshot-conversion-webhook entrypoint into its own independent cmd/ directory.
# Like snapshot-controller, the webhook keeps its own main() as a separate binary.
# NOTE: Import path replacement is already handled by the sed block inside
# pkg/snapshotter/ above.
mkdir -p cmd/snapshot-conversion-webhook
cp -v pkg/snapshotter/cmd/snapshot-conversion-webhook/*.go cmd/snapshot-conversion-webhook/

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
# Tooling tests for the AIO entrypoint (parseControllers, config->global mapping).
symlink_from_root_to_hack hack/cmd/csi-sidecars/main_test.go
# The utility global function to register common and per-sidecar flags.
symlink_from_root_to_hack hack/cmd/csi-sidecars/config/flags.go
# Tooling tests for the AIO flag registration.
symlink_from_root_to_hack hack/cmd/csi-sidecars/config/flags_test.go
# The utility glofal functions to register attacher flags.
symlink_from_root_to_hack hack/pkg/attacher/cmd/csi-attacher/config/flags.go
# Tooling tests for the attacher flag registration.
symlink_from_root_to_hack hack/pkg/attacher/cmd/csi-attacher/config/flags_test.go

# Create merged go.mod
cat <<EOF >go.mod
module github.com/kubernetes-csi/csi-sidecars

go 1.26

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
CMDS=csi-sidecars snapshot-controller snapshot-conversion-webhook
all: build

include release-tools/build.make
EOF

# Clone csi-lib-utils into the staging/ directory and add an override to use the local copy in go.mod
csi_lib_utils=staging/src/github.com/kubernetes-csi/csi-lib-utils
if [[ ! -d ${csi_lib_utils} ]]; then
  git clone https://github.com/kubernetes-csi/csi-lib-utils ${csi_lib_utils}

  ${TRASH} ${csi_lib_utils}/.git
  ${TRASH} ${csi_lib_utils}/.github
  ${TRASH} ${csi_lib_utils}/vendor
  ${TRASH} ${csi_lib_utils}/release-tools
fi

if ! grep -q "./staging/src/github.com/kubernetes-csi/csi-lib-utils" go.mod; then
  echo "replace github.com/kubernetes-csi/csi-lib-utils => ./staging/src/github.com/kubernetes-csi/csi-lib-utils" >>go.mod
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

# checkpoint: test that snapshot-controller builds as a standalone binary
./bin/snapshot-controller --help || true

# checkpoint: test that snapshot-conversion-webhook builds as a standalone binary
./bin/snapshot-conversion-webhook --help || true

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

echo "Complete!"
echo "Merged commit history available at tmp/csi-sidecars/"
