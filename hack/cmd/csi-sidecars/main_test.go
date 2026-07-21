package main

import (
	"reflect"
	"testing"
	"time"

	"github.com/kubernetes-csi/csi-sidecars/cmd/csi-sidecars/config"
)

// TestParseControllers covers the --controllers parsing, including the
// edge cases that the previous inline strings.Split produced (an empty value
// leaking an "" key, and whitespace/duplicate commas).
func TestParseControllers(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want map[string]bool
	}{
		{
			name: "empty string yields empty set",
			in:   "",
			want: map[string]bool{},
		},
		{
			name: "single controller",
			in:   "attacher",
			want: map[string]bool{"attacher": true},
		},
		{
			name: "all four sidecars",
			in:   "attacher,provisioner,resizer,snapshotter",
			want: map[string]bool{
				"attacher":    true,
				"provisioner": true,
				"resizer":     true,
				"snapshotter": true,
			},
		},
		{
			name: "trailing comma is ignored",
			in:   "attacher,",
			want: map[string]bool{"attacher": true},
		},
		{
			name: "leading comma is ignored",
			in:   ",attacher",
			want: map[string]bool{"attacher": true},
		},
		{
			name: "surrounding whitespace is trimmed",
			in:   " attacher , provisioner ",
			want: map[string]bool{"attacher": true, "provisioner": true},
		},
		{
			name: "duplicate entries collapse",
			in:   "attacher,attacher",
			want: map[string]bool{"attacher": true},
		},
		{
			name: "only commas yield empty set",
			in:   ",,,",
			want: map[string]bool{},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := parseControllers(tc.in)
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("parseControllers(%q) = %v, want %v", tc.in, got, tc.want)
			}
		})
	}
}

// TestCopyFlagsFromConfigToGlobalVars asserts the global vars used by the
// sidecar entrypoints alias the correct fields of config.Configuration and
// standardflags.Configuration. This guards the error-prone manual pointer
// mapping in copyFlagsFromConfigToGlobalVars: aliasing the wrong field would
// silently feed the wrong value to a sidecar. We verify aliasing (not just
// equal values) by mutating the source config and observing the global var
// through its pointer.
func TestCopyFlagsFromConfigToGlobalVars(t *testing.T) {
	// Restore the package-global config.Configuration after the test so we do
	// not leak the sentinel values below into any other test in this package.
	// config.Configuration and its nested *Configuration structs are all value
	// types, so a plain struct copy is a complete snapshot.
	original := config.Configuration
	t.Cleanup(func() {
		config.Configuration = original
	})

	// Set distinct sentinel values on the source config so a mis-aliased
	// pointer would surface as a wrong/zero value.
	config.Configuration.Master = "https://master.example"
	config.Configuration.Resync = 7 * time.Minute
	config.Configuration.RetryIntervalStart = 3 * time.Second
	config.Configuration.RetryIntervalMax = 11 * time.Minute
	config.Configuration.AttacherConfiguration.DefaultFSType = "ext4"
	config.Configuration.AttacherConfiguration.WorkerThreads = 42
	config.Configuration.AttacherConfiguration.MaxGRPCLogLength = 99
	config.Configuration.AttacherConfiguration.MaxEntries = 5
	config.Configuration.AttacherConfiguration.ReconcileSync = 13 * time.Second
	config.Configuration.AttacherConfiguration.Timeout = 17 * time.Second
	config.Configuration.SnapshotterConfiguration.SnapshotNamePrefix = "snap-prefix"
	config.Configuration.SnapshotterConfiguration.SnapshotNameUUIDLength = 8
	config.Configuration.SnapshotterConfiguration.CSITimeout = 19 * time.Second
	config.Configuration.SnapshotterConfiguration.Threads = 6
	config.Configuration.SnapshotterConfiguration.EnableNodeDeployment = true
	config.Configuration.SnapshotterConfiguration.GroupSnapshotNamePrefix = "grp-prefix"
	config.Configuration.SnapshotterConfiguration.GroupSnapshotNameUUIDLength = 4
	config.Configuration.SnapshotterConfiguration.ExtraCreateMetadata = true

	copyFlagsFromConfigToGlobalVars()

	// AIO-specific.
	assertStrPtr(t, "master", master, config.Configuration.Master)
	assertDurPtr(t, "resync", resync, config.Configuration.Resync)
	assertDurPtr(t, "resyncPeriod", resyncPeriod, config.Configuration.Resync)
	assertDurPtr(t, "retryIntervalStart", retryIntervalStart, config.Configuration.RetryIntervalStart)
	assertDurPtr(t, "retryIntervalMax", retryIntervalMax, config.Configuration.RetryIntervalMax)

	// Attacher-specific.
	assertStrPtr(t, "defaultFSType", defaultFSType, config.Configuration.AttacherConfiguration.DefaultFSType)
	assertIntPtr(t, "workerThreads", workerThreads, config.Configuration.AttacherConfiguration.WorkerThreads)
	assertIntPtr(t, "workers", workers, config.Configuration.AttacherConfiguration.WorkerThreads)
	assertIntPtr(t, "maxGRPCLogLength", maxGRPCLogLength, config.Configuration.AttacherConfiguration.MaxGRPCLogLength)
	assertIntPtr(t, "maxEntries", maxEntries, config.Configuration.AttacherConfiguration.MaxEntries)
	assertDurPtr(t, "reconcileSync", reconcileSync, config.Configuration.AttacherConfiguration.ReconcileSync)
	assertDurPtr(t, "timeout", timeout, config.Configuration.AttacherConfiguration.Timeout)
	assertDurPtr(t, "operationTimeout", operationTimeout, config.Configuration.AttacherConfiguration.Timeout)

	// Snapshotter-specific.
	assertStrPtr(t, "snapshotNamePrefix", snapshotNamePrefix, config.Configuration.SnapshotterConfiguration.SnapshotNamePrefix)
	assertIntPtr(t, "snapshotNameUUIDLength", snapshotNameUUIDLength, config.Configuration.SnapshotterConfiguration.SnapshotNameUUIDLength)
	assertDurPtr(t, "snapshotterCSITimeout", snapshotterCSITimeout, config.Configuration.SnapshotterConfiguration.CSITimeout)
	assertIntPtr(t, "snapshotterThreads", snapshotterThreads, config.Configuration.SnapshotterConfiguration.Threads)
	assertBoolPtr(t, "snapshotterEnableNodeDeployment", snapshotterEnableNodeDeployment, config.Configuration.SnapshotterConfiguration.EnableNodeDeployment)
	assertStrPtr(t, "groupSnapshotNamePrefix", groupSnapshotNamePrefix, config.Configuration.SnapshotterConfiguration.GroupSnapshotNamePrefix)
	assertIntPtr(t, "groupSnapshotNameUUIDLength", groupSnapshotNameUUIDLength, config.Configuration.SnapshotterConfiguration.GroupSnapshotNameUUIDLength)
	assertBoolPtr(t, "snapshotterExtraCreateMetadata", snapshotterExtraCreateMetadata, config.Configuration.SnapshotterConfiguration.ExtraCreateMetadata)
}

func assertStrPtr(t *testing.T, name string, got *string, want string) {
	t.Helper()
	if got == nil {
		t.Errorf("%s is nil, want alias to %q", name, want)
		return
	}
	if *got != want {
		t.Errorf("%s = %q, want %q (mis-aliased field?)", name, *got, want)
	}
}

func assertIntPtr(t *testing.T, name string, got *int, want int) {
	t.Helper()
	if got == nil {
		t.Errorf("%s is nil, want alias to %d", name, want)
		return
	}
	if *got != want {
		t.Errorf("%s = %d, want %d (mis-aliased field?)", name, *got, want)
	}
}

func assertDurPtr(t *testing.T, name string, got *time.Duration, want time.Duration) {
	t.Helper()
	if got == nil {
		t.Errorf("%s is nil, want alias to %s", name, want)
		return
	}
	if *got != want {
		t.Errorf("%s = %s, want %s (mis-aliased field?)", name, *got, want)
	}
}

func assertBoolPtr(t *testing.T, name string, got *bool, want bool) {
	t.Helper()
	if got == nil {
		t.Errorf("%s is nil, want alias to %v", name, want)
		return
	}
	if *got != want {
		t.Errorf("%s = %v, want %v (mis-aliased field?)", name, *got, want)
	}
}
