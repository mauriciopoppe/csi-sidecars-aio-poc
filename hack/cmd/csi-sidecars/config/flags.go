package config

import (
	"flag"
	"time"

	attacherconfiguration "github.com/kubernetes-csi/csi-sidecars/pkg/attacher/cmd/csi-attacher/config"
)

type AIOConfiguration struct {
	ShowVersion bool

	Master     string
	KubeConfig string
	CSIAddress string
	Resync     time.Duration

	RetryIntervalStart time.Duration
	RetryIntervalMax   time.Duration

	LeaderElection              bool
	LeaderElectionNamespace     string
	LeaderElectionLeaseDuration time.Duration
	LeaderElectionRenewDeadline time.Duration
	LeaderElectionRetryPeriod   time.Duration

	KubeAPIQPS   float64
	KubeAPIBurst int

	HttpEndpoint   string
	MetricsAddress string
	MetricsPath    string

	Controllers string

	AttacherConfiguration attacherconfiguration.AttacherConfiguration
}

var Configuration = AIOConfiguration{
	AttacherConfiguration: attacherconfiguration.AttacherConfiguration{},
}

func RegisterCommonFlags(flags *flag.FlagSet) {
	flags.BoolVar(&Configuration.ShowVersion, "version", false, "Show version.")
	flags.StringVar(&Configuration.Master, "master", "", "Master URL to build a client config from. Either this or kubeconfig needs to be set if the provisioner is being run out of cluster.")
	flags.StringVar(&Configuration.KubeConfig, "kubeconfig", "", "Absolute path to the kubeconfig file. Required only when running out of cluster.")
	flags.StringVar(&Configuration.CSIAddress, "csi-address", "/run/csi/socket", "The gRPC endpoint for Target CSI Volume.")
	flags.DurationVar(&Configuration.Resync, "resync", 10*time.Minute, "Resync interval of the controller.")
	flags.DurationVar(&Configuration.RetryIntervalStart, "retry-interval-start", time.Second, "Initial retry interval of failed create volume or deletion. It doubles with each failure, up to retry-interval-max.")
	flags.DurationVar(&Configuration.RetryIntervalMax, "retry-interval-max", 5*time.Minute, "Maximum retry interval of failed create volume or deletion.")
	flags.BoolVar(&Configuration.LeaderElection, "leader-election", false, "Enable leader election.")
	flags.StringVar(&Configuration.LeaderElectionNamespace, "leader-election-namespace", "", "Namespace where the leader election resource lives. Defaults to the pod namespace if not set.")
	flags.DurationVar(&Configuration.LeaderElectionLeaseDuration, "leader-election-lease-duration", 15*time.Second, "Duration, in seconds, that non-leader candidates will wait to force acquire leadership. Defaults to 15 seconds.")
	flags.DurationVar(&Configuration.LeaderElectionRenewDeadline, "leader-election-renew-deadline", 10*time.Second, "Duration, in seconds, that the acting leader will retry refreshing leadership before giving up. Defaults to 10 seconds.")
	flags.DurationVar(&Configuration.LeaderElectionRetryPeriod, "leader-election-retry-period", 5*time.Second, "Duration, in seconds, the LeaderElector clients should wait between tries of actions. Defaults to 5 seconds.")
	flags.Float64Var(&Configuration.KubeAPIQPS, "kube-api-qps", 5, "QPS to use while communicating with the kubernetes apiserver. Defaults to 5.0.")
	flags.IntVar(&Configuration.KubeAPIBurst, "kube-api-burst", 10, "Burst to use while communicating with the kubernetes apiserver. Defaults to 10.")

	// "Shared" but probably broken if you actually try to use any of them
	flags.StringVar(&Configuration.HttpEndpoint, "http-endpoint", "", "The TCP network address where the HTTP server for diagnostics, including metrics and leader election health check, will listen (example: `:8080`). The default is empty string, which means the server is disabled. Only one of `--metrics-address` and `--http-endpoint` can be set.")
	flags.StringVar(&Configuration.MetricsAddress, "metrics-address", "", "(deprecated) The TCP network address where the prometheus metrics endpoint will listen (example: `:8080`). The default is empty string, which means metrics endpoint is disabled. Only one of `--metrics-address` and `--http-endpoint` can be set.")
	flags.StringVar(&Configuration.MetricsPath, "metrics-path", "/metrics", "The HTTP path where prometheus metrics will be exposed. Default is `/metrics`.")

	flags.StringVar(&Configuration.Controllers, "controllers", "", "A comma-separated list of controllers to enable. The possible values are: [resizer,attacher,provisioner]")
}

