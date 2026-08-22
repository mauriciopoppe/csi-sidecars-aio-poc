package config

import (
	"flag"
	"time"

	attacherconfiguration "github.com/kubernetes-csi/csi-sidecars/pkg/attacher/cmd/csi-attacher/config"
)

type SnapshotterConfiguration struct {
	SnapshotNamePrefix          string
	SnapshotNameUUIDLength      int
	Threads                     int
	CSITimeout                  time.Duration
	ExtraCreateMetadata         bool
	EnableNodeDeployment        bool
	GroupSnapshotNamePrefix     string
	GroupSnapshotNameUUIDLength int
}

// AIOConfiguration holds AIO-specific flags that are not covered by
// standardflags.SidecarConfiguration (common flags like kubeconfig,
// csi-address, leader-election, kube-api-qps, etc. are registered via
// standardflags.RegisterCommonFlags).
type AIOConfiguration struct {
	Master string
	Resync time.Duration

	RetryIntervalStart time.Duration
	RetryIntervalMax   time.Duration

	// Resizer-specific per-call timeouts. Upstream external-resizer added
	// dedicated --resize-timeout/--modify-timeout flags alongside --timeout;
	// the AIO exposes them as resizer-prefixed flags.
	ResizeTimeout time.Duration
	ModifyTimeout time.Duration

	Controllers string

	AttacherConfiguration    attacherconfiguration.AttacherConfiguration
	SnapshotterConfiguration SnapshotterConfiguration
}

var Configuration = AIOConfiguration{
	AttacherConfiguration:    attacherconfiguration.AttacherConfiguration{},
	SnapshotterConfiguration: SnapshotterConfiguration{},
}

// RegisterAIOFlags registers AIO-specific flags that are not part of the
// common sidecar flags provided by standardflags.RegisterCommonFlags.
func RegisterAIOFlags(flags *flag.FlagSet) {
	flags.StringVar(&Configuration.Master, "master", "", "Master URL to build a client config from. Either this or kubeconfig needs to be set if the provisioner is being run out of cluster.")
	flags.DurationVar(&Configuration.Resync, "resync", 10*time.Minute, "Resync interval of the controller.")
	flags.DurationVar(&Configuration.RetryIntervalStart, "retry-interval-start", time.Second, "Initial retry interval of failed create volume or deletion. It doubles with each failure, up to retry-interval-max.")
	flags.DurationVar(&Configuration.RetryIntervalMax, "retry-interval-max", 5*time.Minute, "Maximum retry interval of failed create volume or deletion.")
	flags.StringVar(&Configuration.Controllers, "controllers", "", "A comma-separated list of controllers to enable. The possible values are: [resizer,attacher,provisioner,snapshotter]")
	flags.DurationVar(&Configuration.ResizeTimeout, "resizer-resize-timeout", 10*time.Second, "Timeout for ControllerExpandVolume calls issued by the resizer controller.")
	flags.DurationVar(&Configuration.ModifyTimeout, "resizer-modify-timeout", 10*time.Second, "Timeout for ControllerModifyVolume calls issued by the resizer controller.")
}

func registerSnapshotterFlags(flags *flag.FlagSet, c *SnapshotterConfiguration, prefix string) {
	flags.StringVar(&c.SnapshotNamePrefix, prefix+"snapshot-name-prefix", "snapshot", "Prefix to apply to the name of a created snapshot.")
	flags.IntVar(&c.SnapshotNameUUIDLength, prefix+"snapshot-name-uuid-length", -1, "Truncates generated UUID of a created snapshot to this length. Defaults behavior is to NOT truncate.")
	flags.IntVar(&c.Threads, prefix+"worker-threads", 10, "Number of worker threads.")
	flags.DurationVar(&c.CSITimeout, prefix+"timeout", time.Minute, "The timeout for any RPCs to the CSI driver.")
	flags.BoolVar(&c.ExtraCreateMetadata, prefix+"extra-create-metadata", false, "If set, add snapshot metadata to plugin snapshot requests as parameters.")
	flags.BoolVar(&c.EnableNodeDeployment, prefix+"node-deployment", false, "Enables deploying the sidecar controller together with a CSI driver on nodes to manage snapshots for node-local volumes.")
	flags.StringVar(&c.GroupSnapshotNamePrefix, prefix+"groupsnapshot-name-prefix", "groupsnapshot", "Prefix to apply to the name of a created group snapshot.")
	flags.IntVar(&c.GroupSnapshotNameUUIDLength, prefix+"groupsnapshot-name-uuid-length", -1, "Truncates generated UUID of a created group snapshot. Defaults behavior is to NOT truncate.")
}

func RegisterSnapshotterFlags(flags *flag.FlagSet, c *SnapshotterConfiguration) {
	registerSnapshotterFlags(flags, c, "")
}

func RegisterSnapshotterFlagsWithPrefix(flags *flag.FlagSet, c *SnapshotterConfiguration) {
	registerSnapshotterFlags(flags, c, "snapshotter-")
}

