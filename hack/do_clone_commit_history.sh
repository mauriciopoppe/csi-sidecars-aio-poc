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
for i in external-attacher,master external-provisioner,master external-resizer,master; do
  IFS=',' read SIDECAR SIDECAR_HASH <<<"${i}"

  git clone https://github.com/kubernetes-csi/${SIDECAR} tmp/${SIDECAR}
  (
    cd tmp/${SIDECAR}
    git status
    git checkout ${SIDECAR_HASH}
    git rev-parse --short HEAD

    # --force is required if we checkout to a different branch.
    # alternatively, comment the `git checkout` about and remove the flag.
    git filter-repo \
      --commit-callback "
# commit.original_id is a byte string of the original SHA-1
original_hash = commit.original_id.decode()

# Github link for reference.
github_link = f\"https://github.com/kubernetes-csi/${SIDECAR}/commit/{original_hash}\"

# Append a trailer to the commit message.
# We decode the message to add the string, then re-encode to bytes.
original_message = commit.message.decode()
new_message = f\"{original_message}\n\nImported-from: ${SIDECAR}\n\nOriginal-commit: {original_hash}\n\nGithub-link: {github_link}\"
commit.message = new_message.encode()
    " \
      --to-subdirectory-filter pkg/${SIDECAR#external-} --force
  )

  # Import a ${SIDECAR} repo into the tmp/csi-sidecars repo
  (
    cd tmp/csi-sidecars
    git remote add ${SIDECAR} ../${SIDECAR}
    git fetch ${SIDECAR}
    git merge ${SIDECAR}/${SIDECAR_HASH} --allow-unrelated-histories --no-edit
  )
done

echo "Complete!"
echo "Check the new repo at tmp/csi-sidecars"
