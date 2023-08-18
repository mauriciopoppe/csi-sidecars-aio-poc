# CSI Sidecars in one repo!

See https://docs.google.com/document/d/1z7OU79YBnvlaDgcvmtYVnUAYFX1w9lyrgiPTV7RXjHM/edit for more info

## Development

For the POC most of the code is generated through `sync.sh`.

Requirements:

- https://github.com/BurntSushi/ripgrep
- https://www.npmjs.com/package/trash

To start from scratch:

```
# cleanup first
./hack/do_cleanup.sh
# synchronize files next
./hack/do_sync.sh
```

Logs:

```
+ FROM_SCRATCH=false
+ cond_exec trash pkg cmd staging go.mod go.sum go.work go.work.sum
+ [[ false == \t\r\u\e ]]
+ echo trash pkg cmd staging go.mod go.sum go.work go.work.sum
+ mkdir -p pkg cmd/csi-sidecars/ staging/src/github.com/kubernetes-csi/
+ [[ ! -d pkg/attacher ]]
+ git clone https://github.com/kubernetes-csi/external-attacher pkg/attacher
Cloning into 'pkg/attacher'...
trash pkg cmd staging go.mod go.sum go.work go.work.sum
remote: Enumerating objects: 32179, done.
remote: Counting objects: 100% (2566/2566), done.
remote: Compressing objects: 100% (1137/1137), done.
Receiving objects:  31% (9976/32179), 9.98 MiB | 19Receiving objects:  32% (10298/32179), 9.98 MiB | 1Receiving objects:  33% (10620/32179), 9.98 MiB | 1Receiving objects:  34% (10941/32179), 9.98 MiB | 1Receiving objects:  35% (11263/32179), 9.98 MiB | 1Receiving objects:  36% (11585/32179), 9.98 MiB | 1Receiving objects:  37% (11907/32179), 9.98 MiB | 1Receiving objects:  38% (12229/32179), 9.98 MiB | 1Receiving objects:  39% (12550/32179), 9.98 MiB | 1Receiving objects:  40% (12872/32179), 9.98 MiB | 1Receiving objects:  41% (13194/32179), 9.98 MiB | 1Receiving objects:  42% (13516/32179), 9.98 MiB | 1Receiving objects:  43% (13837/32179), 9.98 MiB | 1Receiving objects:  44% (14159/32179), 9.98 MiB | 1Receiving objects:  45% (14481/32179), 9.98 MiB | 1Receiving objects:  46% (14803/32179), 9.98 MiB | 1Receiving objects:  47% (15125/32179), 9.98 MiB | 1Receiving objects:  48% (15446/32179), 9.98 MiB | 1Receiving objects:  49% (15768/32179), 9.98 MiB | 1Receiving objects:  50% (16090/32179), 9.98 MiB | 1Receiving objects:  51% (16412/32179), 9.98 MiB | 1Receiving objects:  52% (16734/32179), 9.98 MiB | 1Receiving objects:  53% (17055/32179), 9.98 MiB | 1Receiving objects:  54% (17377/32179), 9.98 MiB | 1Receiving objects:  55% (17699/32179), 9.98 MiB | 1Receiving objects:  56% (18021/32179), 9.98 MiB | 1Receiving objects:  57% (18343/32179), 9.98 MiB | 1Receiving objects:  58% (18664/32179), 9.98 MiB | 1Receiving objects:  59% (18986/32179), 9.98 MiB | 1Receiving objects:  60% (19308/32179), 9.98 MiB | 1Receiving objects:  60% (19464/32179), 29.07 MiB | Receiving objects:  61% (19630/32179), 29.07 MiB | Receiving objects:  62% (19951/32179), 29.07 MiB | Receiving objects:  63% (20273/32179), 29.07 MiB | Receiving objects:  64% (20595/32179), 29.07 MiB | Receiving objects:  65% (20917/32179), 29.07 MiB | Receiving objects:  66% (21239/32179), 29.07 MiB | Receiving objects:  67% (21560/32179), 29.07 MiB | Receiving objects:  68% (21882/32179), 29.07 MiB | Receiving objects:  69% (22204/32179), 29.07 MiB | Receiving objects:  70% (22526/32179), 29.07 MiB | Receiving objects:  71% (22848/32179), 29.07 MiB | Receiving objects:  72% (23169/32179), 29.07 MiB | Receiving objects:  73% (23491/32179), 29.07 MiB | Receiving objects:  74% (23813/32179), 29.07 MiB | Receiving objects:  75% (24135/32179), 29.07 MiB | Receiving objects:  76% (24457/32179), 29.07 MiB | Receiving objects:  77% (24778/32179), 29.07 MiB | Receiving objects:  78% (25100/32179), 29.07 MiB | Receiving objects:  79% (25422/32179), 29.07 MiB | Receiving objects:  80% (25744/32179), 29.07 MiB | Receiving objects:  81% (26065/32179), 29.07 MiB | Receiving objects:  82% (26387/32179), 29.07 MiB | Receiving objects:  83% (26709/32179), 29.07 MiB | Receiving objects:  84% (27031/32179), 29.07 MiB | Receiving objects:  85% (27353/32179), 29.07 MiB | Receiving objects:  86% (27674/32179), 29.07 MiB | Receiving objects:  87% (27996/32179), 29.07 MiB | Receiving objects:  88% (28318/32179), 29.07 MiB | Receiving objects:  89% (28640/32179), 29.07 MiB | Receiving objects:  90% (28962/32179), 29.07 MiB | Receiving objects:  91% (29283/32179), 29.07 MiB | Receiving objects:  92% (29605/32179), 29.07 MiB | Receiving objects:  93% (29927/32179), 29.07 MiB | Receiving objects:  94% (30249/32179), 29.07 MiB | Receiving objects:  95% (30571/32179), 29.07 MiB | Receiving objects:  96% (30892/32179), 29.07 MiB | Receiving objects:  97% (31214/32179), 29.07 MiB | Receiving objects:  98% (31536/32179), 29.07 MiB | Receiving objects:  99% (31858/32179), 29.07 MiB | remote: Total 32179 (delta 1302), reused 2533 (delta 1298), pack-reused 29613
Receiving objects: 100% (32179/32179), 29.07 MiB | Receiving objects: 100% (32179/32179), 46.80 MiB | 32.53 MiB/s, done.
Resolving deltas: 100% (18374/18374), done.
+ cp pkg/attacher/go.mod go.mod
+ sed -i '1 s%.*%module github.com/kubernetes-csi/csi-sidecars%' go.mod
+ trash pkg/attacher/.git
+ trash pkg/attacher/.github
+ trash pkg/attacher/vendor
+ trash pkg/attacher/release-tools
+ trash pkg/attacher/go.mod
+ trash pkg/attacher/go.sum
+ trash pkg/attacher/Dockerfile
+ trash pkg/attacher/.cloudbuild.sh
+ trash pkg/attacher/cloudbuild.yaml
+ trash pkg/attacher/.prow.sh
+ trash pkg/attacher/OWNER_ALIASES
+ trash pkg/attacher/Makefile
+ cd pkg/attacher
+ rg github.com/kubernetes-csi/external-attacher/ --files-with-matches
+ xargs sed -i s%github.com/kubernetes-csi/external-attacher/%github.com/kubernetes-csi/csi-sidecars/pkg/attacher/%g
+ cp pkg/attacher/cmd/csi-attacher/main.go cmd/csi-sidecars/main.go
+ go mod tidy
+ csi_release_tools=staging/src/github.com/kubernetes-csi/csi-release-tools
+ [[ ! -d staging/src/github.com/kubernetes-csi/csi-release-tools ]]
+ git clone https://github.com/kubernetes-csi/csi-release-tools staging/src/github.com/kubernetes-csi/csi-release-tools
Cloning into 'staging/src/github.com/kubernetes-csi/csi-release-tools'...
remote: Enumerating objects: 953, done.
remote: Counting objects: 100% (953/953), done.
remote: Compressing objects: 100% (457/457), done.
remote: Total 953 (delta 520), reused 915 (delta 495), pack-reused 0
Receiving objects: 100% (953/953), 374.86 KiB | 5.86 MiB/s, done.
Resolving deltas: 100% (520/520), done.
+ trash staging/src/github.com/kubernetes-csi/csi-release-tools/.git
+ cd staging/src/github.com/kubernetes-csi/csi-release-tools
+ rg release-tools --files-with-matches
+ xargs sed -i s%release-tools%staging/src/github.com/kubernetes-csi/csi-release-tools%g
+ cat
+ csi_lib_utils=staging/src/github.com/kubernetes-csi/csi-lib-utils
+ [[ ! -d staging/src/github.com/kubernetes-csi/csi-lib-utils ]]
+ git clone https://github.com/kubernetes-csi/csi-lib-utils staging/src/github.com/kubernetes-csi/csi-lib-utils
Cloning into 'staging/src/github.com/kubernetes-csi/csi-lib-utils'...
remote: Enumerating objects: 13440, done.
remote: Counting objects: 100% (2520/2520), done.
remote: Compressing objects: 100% (1271/1271), done.
Receiving objects:  96% (12903/13440), 15.41 MiB | Receiving objects:  97% (13037/13440), 15.41 MiB | Receiving objects:  98% (13172/13440), 15.41 MiB | Receiving objects:  99% (13306/13440), 15.41 MiB | remote: Total 13440 (delta 1380), reused 1700 (delta 1147), pack-reused 10920
Receiving objects: 100% (13440/13440), 15.41 MiB | Receiving objects: 100% (13440/13440), 16.65 MiB | 31.63 MiB/s, done.
Resolving deltas: 100% (8258/8258), done.
+ trash staging/src/github.com/kubernetes-csi/csi-lib-utils/.git
+ trash staging/src/github.com/kubernetes-csi/csi-lib-utils/.github
+ trash staging/src/github.com/kubernetes-csi/csi-lib-utils/vendor
+ trash staging/src/github.com/kubernetes-csi/csi-lib-utils/release-tools
+ cat
+ grep -q '// Connect to CSI' cmd/csi-sidecars/main.go
+ sed -i 's%// Connect to CSI.%// Override\!\nconnection.HelloWorld()%g' cmd/csi-sidecars/main.go
+ trash go.work go.sum
+ go work init .
+ go work use ./staging/src/github.com/kubernetes-csi/csi-lib-utils
+ go mod tidy
+ grep -q HelloWorld cmd/csi-sidecars/main.go
+ make build
./staging/src/github.com/kubernetes-csi/csi-release-tools/verify-go-version.sh "go"

======================================================
                  WARNING

  This projects is tested with Go v1.20.
  Your current Go version is v1.21.
  This may or may not be close enough.

  In particular test-gofmt and test-vendor
  are known to be sensitive to the version of
  Go.
======================================================

mkdir -p bin
# os_arch_seen captures all of the $os-$arch-$buildx_platform seen for the current binary
# that we want to build, if we've seen an $os-$arch-$buildx_platform before it means that
# we don't need to build it again, this is done to avoid building
# the windows binary multiple times (see the default value of $BUILD_PLATFORMS)
export os_arch_seen="" && echo '' | tr ';' '\n' | while read -r os arch buildx_platform suffix base_image addon_image; do \
        os_arch_seen_pre=${os_arch_seen%%$os-$arch-$buildx_platform*}; \
        if ! [ ${#os_arch_seen_pre} = ${#os_arch_seen} ]; then \
                continue; \
        fi; \
        if ! (set -x; cd ./cmd/"csi-sidecars" && CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" go build  -a -ldflags ' -X main.version=c353144c68da9c75637d10f7ff11ff4b622424bd -extldflags "-static"' -o "/Users/mauriciopoppe/go/src/github.com/kubernetes-csi/csi-sidecars/bin/"csi-sidecars"$suffix" .); then \
                echo "Building "csi-sidecars" for GOOS=$os GOARCH=$arch failed, see error(s) above."; \
                exit 1; \
        fi; \
        os_arch_seen+=";$os-$arch-$buildx_platform"; \
done
+ cd ./cmd/csi-sidecars
+ CGO_ENABLED=0
+ GOOS=
+ GOARCH=
+ go build -a -ldflags ' -X main.version=c353144c68da9c75637d10f7ff11ff4b622424bd -extldflags "-static"' -o /Users/mauriciopoppe/go/src/github.com/kubernetes-csi/csi-sidecars/bin/csi-sidecars .
+ cat
+ cat
```
