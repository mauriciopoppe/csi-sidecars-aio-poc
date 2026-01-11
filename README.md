# CSI Sidecars Monorepo

[KEP-4958: CSI Sidecars All in one](https://github.com/kubernetes/enhancements/pull/5153) proposes combining the location
of the source code of the CSI sidecars in a monorepo. Among the benefits are:

- Improve the CSI sidecar release process by reducing the number of components released.
- Decrease the maintenance tasks the SIG Storage community maintainers do to maintain the sidecars.
- Propagate changes in common libraries used by CSI Sidecars immediately instead of through additional PRs.
- Reduce the number of components CSI Driver authors and cluster administrators need to keep up to date in k8s clusters.

As a side effect we also:

- Reduce the memory usage/API server calls done by the CSI Sidecars through the usage of a shared informer.
- Reduce the cluster resource requirements needed to run the CSI Sidecars.

This repo accomplishes merging the CSI sidecar codebases into a monorepo through the `./hack/do_sync.sh` script.
Currently the list includes:

- kubernetes-csi/external-attacher
- kubernetes-csi/external-resizer
- kubernetes-csi/external-provisioner

For more information please look at the following resources:

- [KEP-4958: CSI Sidecars All in one](https://github.com/kubernetes/enhancements/pull/5153)
- [Presentation](https://www.youtube.com/watch?v=hZpgLqys_lQ&t=1742s)
- [Slides](https://docs.google.com/presentation/d/1lldJYYf2WVxgv4O3Wgdefrq3ZAN7s3Mwx-GL_CRmakE/)
- [Design doc](https://docs.google.com/document/d/1z7OU79YBnvlaDgcvmtYVnUAYFX1w9lyrgiPTV7RXjHM/)

## Development

Requirements:

- go 1.24

### Building the project locally

After cloning the repo, run the following commands to start from scratch:

```bash
# cleanup first
./hack/do_cleanup.sh
# clone repo, setup go workspaces and build
./hack/do_sync.sh 2>&1 | tee hack/do_sync.log
```

Logs: [./hack/do_sync.log](./hack/do_sync.log)

We're trying out cloning existing repos preserving their commit history,
the following script implements it:

```bash
python3 -m venv .venv && source .venv/bin/activate
./hack/do_cleanup.sh && ./hack/do_clone_commit_history.sh
```

### Building the project using CI

There's a presubmit job that runs on every PR using Github Actions,
to run the action locally install https://github.com/nektos/act and run:

```bash
act push
```

### E2E tests through the Hostpath CSI Driver

- Go over the slides above.
- Make sure that the project was built locally. The `do_sync.sh` command should exit with status code 0.

WARNING: The following nukes your $GOPATH/src/k8s.io/ directory. Please read .prow.sh.log
and find the `git clean -fdx` command (which removes untracked files).

```bash
./.prow.sh 2>&1 | tee ./.prow.sh.log
```

Common errors:

- `ERROR: failed to clean $GOPATH/src/k8s.io/kubernetes`, csi-release-tools doesn't work fine
  if there's a local copy of the kubernetes codebase already. Remove it and try again.
- `403 on pulling CSI manifests from github`. Due to throttling, try again.
