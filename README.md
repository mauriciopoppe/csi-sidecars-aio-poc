# CSI Sidecars in one repo!

See https://docs.google.com/document/d/1z7OU79YBnvlaDgcvmtYVnUAYFX1w9lyrgiPTV7RXjHM/edit for more info

## Development

Requirements:

- go devel 1.22

```bash
go install golang.org/dl/gotip@latest
gotip download 495801
export PATH="$(gotip env GOROOT)/bin:$PATH"
```

- https://github.com/BurntSushi/ripgrep
- https://www.npmjs.com/package/trash

### Local Runs

After cloning the repo, run the following commands to start from scratch:

```bash
# cleanup first
./hack/do_cleanup.sh
# clone repo, setup go workspaces and build
./hack/do_sync.sh 2>&1 | tee hack/do_sync.log
```

Logs: [./hack/do_sync.log](./hack/do_sync.log)

### CI Runs

There's a presubmit job that runs on every PR using Github Actions,
to run the action locally install https://github.com/nektos/act and run:

```bash
act push
```
