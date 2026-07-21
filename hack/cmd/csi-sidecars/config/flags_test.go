package config

import (
	"flag"
	"strings"
	"testing"
	"time"
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

// TestRegisterSnapshotterFlagsNoPrefixUsesCallerFlagSet asserts the no-prefix
// snapshotter registration path also targets the caller-provided FlagSet
// rather than the global flag.CommandLine. This is the same class of bug that
// affected the attacher flags (flag.* vs flags.*); registering here guards the
// no-prefix path, which the WithPrefix test above does not exercise.
func TestRegisterSnapshotterFlagsNoPrefixUsesCallerFlagSet(t *testing.T) {
	fs := flag.NewFlagSet("snapshotter-test-noprefix", flag.ContinueOnError)
	cfg := &SnapshotterConfiguration{}

	RegisterSnapshotterFlags(fs, cfg)

	expected := []string{
		"snapshot-name-prefix",
		"snapshot-name-uuid-length",
		"worker-threads",
		"timeout",
		"extra-create-metadata",
		"node-deployment",
		"groupsnapshot-name-prefix",
		"groupsnapshot-name-uuid-length",
	}
	for _, name := range expected {
		if fs.Lookup(name) == nil {
			t.Errorf("snapshotter flag %q was not registered on the caller-provided FlagSet "+
				"(likely leaked onto the global flag.CommandLine)", name)
		}
	}
}

// TestRegisterSnapshotterFlagsTwiceDoesNotPanic guards against a double-register
// panic that would occur if the snapshotter flags leaked onto the global
// flag.CommandLine and registration ran more than once. With a caller-owned
// FlagSet each call targets a distinct set, so two independent FlagSets must
// both register without panicking.
func TestRegisterSnapshotterFlagsTwiceDoesNotPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("registering snapshotter flags twice panicked (flags leaked to "+
				"global flag.CommandLine): %v", r)
		}
	}()

	fs1 := flag.NewFlagSet("snapshotter-twice-1", flag.ContinueOnError)
	fs2 := flag.NewFlagSet("snapshotter-twice-2", flag.ContinueOnError)
	RegisterSnapshotterFlagsWithPrefix(fs1, &SnapshotterConfiguration{})
	RegisterSnapshotterFlagsWithPrefix(fs2, &SnapshotterConfiguration{})
}

// TestRegisterAIOFlagsTwiceDoesNotPanic is the AIO-flag counterpart of the
// snapshotter/attacher double-register guards. RegisterAIOFlags writes into the
// package-global config.Configuration, so we snapshot and restore it to avoid
// leaking state into other tests in this package.
func TestRegisterAIOFlagsTwiceDoesNotPanic(t *testing.T) {
	original := Configuration
	t.Cleanup(func() { Configuration = original })

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("registering AIO flags twice panicked (flags leaked to "+
				"global flag.CommandLine): %v", r)
		}
	}()

	fs1 := flag.NewFlagSet("aio-twice-1", flag.ContinueOnError)
	fs2 := flag.NewFlagSet("aio-twice-2", flag.ContinueOnError)
	RegisterAIOFlags(fs1)
	RegisterAIOFlags(fs2)
}

// TestRegisterAIOFlagsDefaults pins the default values of the AIO flags. These
// defaults are part of the sidecar's documented behavior, so an accidental
// change to any of them should surface as a test failure rather than silently
// altering runtime behavior. Registration writes into config.Configuration, so
// the global is snapshotted and restored.
func TestRegisterAIOFlagsDefaults(t *testing.T) {
	original := Configuration
	t.Cleanup(func() { Configuration = original })

	fs := flag.NewFlagSet("aio-defaults", flag.ContinueOnError)
	RegisterAIOFlags(fs)

	tests := []struct {
		name string
		want string
	}{
		{"master", ""},
		{"resync", (10 * time.Minute).String()},
		{"retry-interval-start", time.Second.String()},
		{"retry-interval-max", (5 * time.Minute).String()},
		{"controllers", ""},
	}
	for _, tc := range tests {
		f := fs.Lookup(tc.name)
		if f == nil {
			t.Errorf("AIO flag %q not registered", tc.name)
			continue
		}
		if f.DefValue != tc.want {
			t.Errorf("AIO flag %q default = %q, want %q", tc.name, f.DefValue, tc.want)
		}
	}
}
