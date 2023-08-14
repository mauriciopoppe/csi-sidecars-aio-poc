# CSI Sidecars in one repo!

See https://docs.google.com/document/d/1z7OU79YBnvlaDgcvmtYVnUAYFX1w9lyrgiPTV7RXjHM/edit for more info

## Development

For the POC most of the code is generated through `sync.sh`.

To start from scratch:

```
rm -rf cmd pkg staging .cloudbuild.sh Dockerfile Makefile go.mod go.sum go.work go.work.sum
./sync.sh
```
