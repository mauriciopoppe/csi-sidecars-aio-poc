package config

import (
	"flag"
	"strings"
	"testing"
)

// TestRegisterAIOFlagsUsesCallerFlagSet asserts every AIO flag registers on
// the caller-provided FlagSet.
func TestRegisterAIOFlagsUsesCallerFlagSet(t *testing.T) {
	fs := flag.NewFlagSet("aio-test", flag.ContinueOnError)

	RegisterAIOFlags(fs)

	expected := []string{
		"master",
		"resync",
		"retry-interval-start",
		"retry-interval-max",
		"controllers",
	}
	for _, name := range expected {
		if fs.Lookup(name) == nil {
			t.Errorf("AIO flag %q was not registered on the caller-provided FlagSet", name)
		}
	}
}

// TestControllersFlagDocumentsFourSidecars guards the sidecar-count: the code
// merges four sidecars (attacher, provisioner, resizer, snapshotter), so the
// --controllers help text must document all four.
func TestControllersFlagDocumentsFourSidecars(t *testing.T) {
	fs := flag.NewFlagSet("aio-test-controllers", flag.ContinueOnError)
	RegisterAIOFlags(fs)

	f := fs.Lookup("controllers")
	if f == nil {
		t.Fatal("controllers flag not registered")
	}

	for _, sidecar := range []string{"attacher", "provisioner", "resizer", "snapshotter"} {
		if !strings.Contains(f.Usage, sidecar) {
			t.Errorf("controllers flag usage does not mention %q; usage=%q", sidecar, f.Usage)
		}
	}
}

// TestRegisterSnapshotterFlagsWithPrefixUsesCallerFlagSet asserts the
// snapshotter flags register on the caller-provided FlagSet with the
// snapshotter- prefix.
func TestRegisterSnapshotterFlagsWithPrefixUsesCallerFlagSet(t *testing.T) {
	fs := flag.NewFlagSet("snapshotter-test", flag.ContinueOnError)
	cfg := &SnapshotterConfiguration{}

	RegisterSnapshotterFlagsWithPrefix(fs, cfg)

	expected := []string{
		"snapshotter-snapshot-name-prefix",
		"snapshotter-snapshot-name-uuid-length",
		"snapshotter-worker-threads",
		"snapshotter-timeout",
		"snapshotter-extra-create-metadata",
		"snapshotter-node-deployment",
		"snapshotter-groupsnapshot-name-prefix",
		"snapshotter-groupsnapshot-name-uuid-length",
	}
	for _, name := range expected {
		if fs.Lookup(name) == nil {
			t.Errorf("snapshotter flag %q was not registered on the caller-provided FlagSet", name)
		}
	}
}
