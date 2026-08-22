CMDS=csi-sidecars snapshot-controller snapshot-conversion-webhook
all: build

include release-tools/build.make

# Regenerate the assembly area (cmd/, pkg/, staging/, go.mod/go.work) from the
# upstream kubernetes-csi repositories. Requires Linux, see tools/scripts/sync.sh.
.PHONY: sync
sync:
	./tools/scripts/sync.sh

# Extend release-tools' `clean` (which only removes bin/) so it also removes
# the generated assembly area; cleanup.sh leaves tools/ untouched.
.PHONY: clean-generated
clean: clean-generated
clean-generated:
	./tools/scripts/cleanup.sh
