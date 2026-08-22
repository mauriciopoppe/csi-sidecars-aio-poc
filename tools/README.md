# tools/ — hand-maintained tool code

Everything in this directory is the **source of truth** maintained by
developers. Nothing here is auto-generated. See the repository-root
[CODE_LAYOUT.md](../CODE_LAYOUT.md) for how this layer relates to the generated
assembly area.

## Contents

| Path | Purpose |
|------|---------|
| `cmd/csi-sidecars/main.go` | AIO unified entry point; dispatches to each sidecar's `<sidecar>_main`. |
| `cmd/csi-sidecars/main_test.go` | Tests for `parseControllers` and the config→global-var mapping. |
| `cmd/csi-sidecars/config/flags.go` | AIO + snapshotter flag registration. |
| `cmd/csi-sidecars/config/flags_test.go` | Flag-registration regression tests. |
| `pkg/attacher/cmd/csi-attacher/main.go` | Forked attacher entrypoint testing the flag-init strategy. |
| `pkg/attacher/cmd/csi-attacher/config/flags.go` | Attacher flag registration (prefixed + unprefixed). |
| `pkg/attacher/cmd/csi-attacher/config/flags_test.go` | Attacher flag-registration tests. |
| `scripts/sync.sh` | Clones upstream `external-*`, rewrites imports, assembles the merged module and binaries. |
| `scripts/cleanup.sh` | Removes all generated artifacts (leaves `tools/` untouched). |
| `scripts/sidecars.conf` | List of sidecars to sync, one `<sidecar>,<branch>` per line. |
| `csi-release-tools-hashes.txt` | Pinned release-tools hashes. |
| `sync.log` | Reference log of a successful sync (tracked, generated). |

## Usage

```bash
python3 -m venv .venv && source .venv/bin/activate
./tools/scripts/sync.sh 2>&1 | tee tools/sync.log
```

Equivalent Makefile shortcuts from the repository root: `make sync` and
`make clean` (the latter also removes `bin/`).

`sync.sh` symlinks the hand-maintained entrypoints from `tools/` into the
assembly area (repository root) and generates the rest from upstream. It requires
Linux with go1.26+. Both `sync.sh` and `cleanup.sh` can be started from any
directory: they resolve the repository root from their own location and always
operate on it.

## Adding or changing a synced sidecar

Edit `scripts/sidecars.conf`:

```
attacher,master
provisioner,master
resizer,master
snapshotter,master
```

Then re-run `sync.sh`.
