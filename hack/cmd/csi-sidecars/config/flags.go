package config

import (
	"flag"
	"time"

	attacherconfiguration "github.com/kubernetes-csi/csi-sidecars/pkg/attacher/cmd/csi-attacher/config"
)

// AIOConfiguration holds AIO-specific flags that are not covered by
// standardflags.SidecarConfiguration (common flags like kubeconfig,
// csi-address, leader-election, kube-api-qps, etc. are registered via
// standardflags.RegisterCommonFlags).
type AIOConfiguration struct {
	Master string
	Resync time.Duration

	RetryIntervalStart time.Duration
	RetryIntervalMax   time.Duration

	Controllers string

	AttacherConfiguration attacherconfiguration.AttacherConfiguration
}

var Configuration = AIOConfiguration{
	AttacherConfiguration: attacherconfiguration.AttacherConfiguration{},
}

// RegisterAIOFlags registers AIO-specific flags that are not part of the
// common sidecar flags provided by standardflags.RegisterCommonFlags.
func RegisterAIOFlags(flags *flag.FlagSet) {
	flags.StringVar(&Configuration.Master, "master", "", "Master URL to build a client config from. Either this or kubeconfig needs to be set if the provisioner is being run out of cluster.")
	flags.DurationVar(&Configuration.Resync, "resync", 10*time.Minute, "Resync interval of the controller.")
	flags.DurationVar(&Configuration.RetryIntervalStart, "retry-interval-start", time.Second, "Initial retry interval of failed create volume or deletion. It doubles with each failure, up to retry-interval-max.")
	flags.DurationVar(&Configuration.RetryIntervalMax, "retry-interval-max", 5*time.Minute, "Maximum retry interval of failed create volume or deletion.")
	flags.StringVar(&Configuration.Controllers, "controllers", "", "A comma-separated list of controllers to enable. The possible values are: [resizer,attacher,provisioner]")
}
