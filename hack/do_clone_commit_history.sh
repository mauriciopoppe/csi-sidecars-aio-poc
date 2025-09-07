#!/bin/bash
set -euxo pipefail

# Create a temporary directory for the clone
mkdir -p tmp

# Get all the hashes from csi-release-tools that we should ignore
git clone https://github.com/kubernetes-csi/csi-release-tools tmp/csi-release-tools
(cd tmp/csi-release-tools && git rev-list --reverse HEAD) > hack/csi-release-tools-hashes.txt

# Clone the full history of the repository
git clone https://github.com/kubernetes-csi/external-attacher tmp/external-attacher
# Create the directory to store the patches
mkdir -p hack/patches/attacher
# Generate the patches for all commits on the master branch
(cd tmp/external-attacher && git format-patch --root --full-index -o ../../hack/patches/attacher)
# Clean up the temporary clone
rm -rf tmp/external-attacher

