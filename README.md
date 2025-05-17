# CSI Sidecars in one repo!

- [Design doc](https://docs.google.com/document/d/1z7OU79YBnvlaDgcvmtYVnUAYFX1w9lyrgiPTV7RXjHM/edit)
- [POC slides](https://docs.google.com/presentation/d/1lldJYYf2WVxgv4O3Wgdefrq3ZAN7s3Mwx-GL_CRmakE/edit?slide=id.g401c104a3c_0_0#slide=id.g401c104a3c_0_0)

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

### Building the project using CI

There's a presubmit job that runs on every PR using Github Actions,
to run the action locally install https://github.com/nektos/act and run:

```bash
act push
```

### E2E tests through the Hostpath CSI Driver

- Go over the POC slides above.
- Make sure that the project was built locally. The `do_sync.sh` command should exit with status code 0.

WARNING: The following nukes your $GOPATH/src/k8s.io/ directory. Please read .prow.sh.log
and find the `git clean -fdx` command (which removes untracked files).

```bash
kind delete cluster --name csi-prow
./.prow.sh 2>&1 | tee ./.prow.sh.log
```

Common errors:

- `ERROR: failed to clean $GOPATH/src/k8s.io/kubernetes`, csi-release-tools doesn't work fine
  if there's a local copy of the kubernetes codebase already. Remove it and try again.
- `403 on pulling CSI manifests from github`. Due to throttling, try again in a few minutes.
