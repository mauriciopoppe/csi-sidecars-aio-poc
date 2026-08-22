package config

import (
	"flag"
	"testing"
)

// expectedAttacherFlags is the full set of flags that
// RegisterAttacherFlagsWithPrefix must register on the caller-provided
// FlagSet. These are asserted against a freshly-built FlagSet (NOT the global
// flag.CommandLine) so that any flag accidentally registered on the global
// command line is detected as a missing flag here.
//
// This is the regression guard for a past bug where the first three flags
// (max-entries, reconcile-sync, max-grpc-log-length) were registered via the
// package-global flag.IntVar/flag.DurationVar instead of the passed-in
// *flag.FlagSet, silently leaking them onto flag.CommandLine.
var expectedAttacherFlags = []string{
	"attacher-max-entries",
	"attacher-reconcile-sync",
	"attacher-max-grpc-log-length",
	"attacher-worker-threads",
	"attacher-default-fstype",
	"attacher-timeout",
	"attacher-retry-interval-start",
	"attacher-retry-interval-max",
}

func TestRegisterAttacherFlagsWithPrefixUsesCallerFlagSet(t *testing.T) {
	fs := flag.NewFlagSet("attacher-test", flag.ContinueOnError)
	cfg := &AttacherConfiguration{}

	RegisterAttacherFlagsWithPrefix(fs, cfg)

	for _, name := range expectedAttacherFlags {
		if fs.Lookup(name) == nil {
			t.Errorf("flag %q was not registered on the caller-provided FlagSet "+
				"(likely leaked onto the global flag.CommandLine)", name)
		}
	}
}

func TestRegisterAttacherFlagsNoPrefixUsesCallerFlagSet(t *testing.T) {
	fs := flag.NewFlagSet("attacher-test-noprefix", flag.ContinueOnError)
	cfg := &AttacherConfiguration{}

	RegisterAttacherFlags(fs, cfg)

	unprefixed := []string{
		"max-entries",
		"reconcile-sync",
		"max-grpc-log-length",
		"worker-threads",
		"default-fstype",
		"timeout",
		"retry-interval-start",
		"retry-interval-max",
	}
	for _, name := range unprefixed {
		if fs.Lookup(name) == nil {
			t.Errorf("flag %q was not registered on the caller-provided FlagSet "+
				"(likely leaked onto the global flag.CommandLine)", name)
		}
	}
}

// TestRegisterAttacherFlagsTwiceDoesNotPanic guards against the double-register
// panic that occurs when flags leak onto the global flag.CommandLine and the
// registration runs more than once. With a caller-owned FlagSet each call
// targets a distinct set, so two independent FlagSets must both succeed.
func TestRegisterAttacherFlagsTwiceDoesNotPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("registering attacher flags twice panicked (flags leaked to "+
				"global flag.CommandLine): %v", r)
		}
	}()

	fs1 := flag.NewFlagSet("attacher-test-1", flag.ContinueOnError)
	fs2 := flag.NewFlagSet("attacher-test-2", flag.ContinueOnError)
	RegisterAttacherFlagsWithPrefix(fs1, &AttacherConfiguration{})
	RegisterAttacherFlagsWithPrefix(fs2, &AttacherConfiguration{})
}
