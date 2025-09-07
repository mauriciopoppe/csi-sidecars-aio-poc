#!/bin/bash
set -euxo pipefail

if [[ -z $VIRTUAL_ENV ]]; then
  echo "This script must run within a virtual env"
  echo "  python3 -m venv venv && source venv/bin/activate "
  exit 1
fi

if ! command -v git-filter-repo >/dev/null; then
  echo "git-filter-repo is required, installing it..."
  pip install git-filter-repo
fi

if [[ -d tmp ]]; then
  echo "tmp directory exists, remove it to start from scratch"
  exit 1
fi

# Create a temporary directory for the clone
mkdir -p tmp

# Let's assume that this repo is not the target of the merge apply
# so that the history isn't polluted.
#
# Instead, let's do it in a temporary new git repo as a POC.
mkdir -p tmp/csi-sidecars
(cd tmp/csi-sidecars && git init)

# Clone the full history of each repository
for i in attacher,master provisioner,master resizer,master; do
  IFS=',' read SIDECAR SIDECAR_HASH <<<"${i}"

  git clone https://github.com/kubernetes-csi/external-${SIDECAR} tmp/${SIDECAR}
  (
    cd tmp/${SIDECAR}
    git status
    git checkout ${SIDECAR_HASH}
    git rev-parse --short HEAD
    # --force is required if we checkout to a different branch.
    # alternatively, comment the `git checkout` about and remove the flag.
    git filter-repo --to-subdirectory-filter pkg/${SIDECAR} --force
  )

  # Import a ${SIDECAR} repo into the tmp/csi-sidecars repo
  (
    cd tmp/csi-sidecars
    git remote add external-${SIDECAR} ../${SIDECAR}
    git fetch external-${SIDECAR}
    git merge external-${SIDECAR}/${SIDECAR_HASH} --allow-unrelated-histories --no-edit
  )
done

echo "Complete!"
echo "Check the new repo at tmp/csi-sidecars"
