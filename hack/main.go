/*
Copyright 2024 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"context"
	goflag "flag"
	"fmt"
	"strings"
	"time"

	"golang.org/x/sync/errgroup"

	flag "github.com/spf13/pflag"
	"sigs.k8s.io/sig-storage-lib-external-provisioner/v11/controller"

	utilfeature "k8s.io/apiserver/pkg/util/feature"
	utilflag "k8s.io/component-base/cli/flag"
	"k8s.io/component-base/logs"
	"k8s.io/klog/v2"
)

var (
	// Shared variables
	master                      = flag.String("master", "", "Master URL to build a client config from. Either this or kubeconfig needs to be set if the provisioner is being run out of cluster.")
	kubeconfig                  = flag.String("kubeconfig", "", "Absolute path to the kubeconfig file. Required only when running out of cluster.")
	kubeConfig                  = kubeconfig
	csiEndpoint                 = flag.String("csi-address", "/run/csi/socket", "The gRPC endpoint for Target CSI Volume.")
	csiAddress                  = csiEndpoint
	showVersion                 = flag.Bool("version", false, "Show version.")
	resync                      = flag.Duration("resync", 10*time.Minute, "Resync interval of the controller.")
	resyncPeriod                = resync
	workerThreads               = flag.Int("worker-threads", 10, "Number of worker threads per sidecar")
	workers                     = workerThreads
	timeout                     = flag.Duration("timeout", 15*time.Second, "Timeout for waiting for attaching or detaching the volume.")
	operationTimeout            = timeout
	retryIntervalStart          = flag.Duration("retry-interval-start", time.Second, "Initial retry interval of failed create volume or deletion. It doubles with each failure, up to retry-interval-max.")
	retryIntervalMax            = flag.Duration("retry-interval-max", 5*time.Minute, "Maximum retry interval of failed create volume or deletion.")
	enableLeaderElection        = flag.Bool("leader-election", false, "Enable leader election.")
	leaderElectionNamespace     = flag.String("leader-election-namespace", "", "Namespace where the leader election resource lives. Defaults to the pod namespace if not set.")
	leaderElectionLeaseDuration = flag.Duration("leader-election-lease-duration", 15*time.Second, "Duration, in seconds, that non-leader candidates will wait to force acquire leadership. Defaults to 15 seconds.")
	leaderElectionRenewDeadline = flag.Duration("leader-election-renew-deadline", 10*time.Second, "Duration, in seconds, that the acting leader will retry refreshing leadership before giving up. Defaults to 10 seconds.")
	leaderElectionRetryPeriod   = flag.Duration("leader-election-retry-period", 5*time.Second, "Duration, in seconds, the LeaderElector clients should wait between tries of actions. Defaults to 5 seconds.")
	kubeAPIQPS                  = flag.Float32("kube-api-qps", 5, "QPS to use while communicating with the kubernetes apiserver. Defaults to 5.0.")
	kubeAPIBurst                = flag.Int("kube-api-burst", 10, "Burst to use while communicating with the kubernetes apiserver. Defaults to 10.")
	defaultFSType               = flag.String("attacher-default-fstype", "", "The default filesystem type of the volume to use.")
	controllers                 = flag.String("controllers", "", "A comma-separated list of controllers to enable. The possible values are: [resizer,attacher,provisioner]")

	// "Shared" but probably broken if you actually try to use any of them
	httpEndpoint   = flag.String("http-endpoint", "", "The TCP network address where the HTTP server for diagnostics, including metrics and leader election health check, will listen (example: `:8080`). The default is empty string, which means the server is disabled. Only one of `--metrics-address` and `--http-endpoint` can be set.")
	metricsAddress = flag.String("metrics-address", "", "(deprecated) The TCP network address where the prometheus metrics endpoint will listen (example: `:8080`). The default is empty string, which means metrics endpoint is disabled. Only one of `--metrics-address` and `--http-endpoint` can be set.")
	metricsPath    = flag.String("metrics-path", "/metrics", "The HTTP path where prometheus metrics will be exposed. Default is `/metrics`.")

	// Attacher specific
	maxEntries       = flag.Int("attacher-max-entries", 0, "Max entries per each page in volume lister call, 0 means no limit.")
	reconcileSync    = flag.Duration("attacher-reconcile-sync", 1*time.Minute, "Resync interval of the VolumeAttachment reconciler.")
	maxGRPCLogLength = flag.Int("attacher-max-grpc-log-length", -1, "The maximum amount of characters logged for every grpc responses. Defaults to no limit")

	// Provisioner specific
	kubeAPICapacityQPS             = flag.Float32("provisioner-kube-api-capacity-qps", 1, "QPS to use for storage capacity updates while communicating with the kubernetes apiserver. Defaults to 1.0.")
	kubeAPICapacityBurst           = flag.Int("provisioner-kube-api-capacity-burst", 5, "Burst to use for storage capacity updates while communicating with the kubernetes apiserver. Defaults to 5.")
	volumeNamePrefix               = flag.String("provisioner-volume-name-prefix", "pvc", "Prefix to apply to the name of a created volume.")
	volumeNameUUIDLength           = flag.Int("provisioner-volume-name-uuid-length", -1, "Truncates generated UUID of a created volume to this length. Defaults behavior is to NOT truncate.")
	finalizerThreads               = flag.Uint("provisioner-cloning-protection-threads", 1, "Number of simultaneously running threads, handling cloning finalizer removal")
	capacityThreads                = flag.Uint("provisioner-capacity-threads", 1, "Number of simultaneously running threads, handling CSIStorageCapacity objects")
	strictTopology                 = flag.Bool("provisioner-strict-topology", false, "Late binding: pass only selected node topology to CreateVolume Request, unlike default behavior of passing aggregated cluster topologies that match with topology keys of the selected node.")
	immediateTopology              = flag.Bool("provisioner-immediate-topology", true, "Immediate binding: pass aggregated cluster topologies for all nodes where the CSI driver is available (enabled, the default) or no topology requirements (if disabled).")
	extraCreateMetadata            = flag.Bool("provisioner-extra-create-metadata", false, "If set, add pv/pvc metadata to plugin create requests as parameters.")
	enableProfile                  = flag.Bool("provisioner-enable-pprof", false, "Enable pprof profiling on the TCP network address specified by --http-endpoint. The HTTP path is `/debug/pprof/`.")
	enableCapacity                 = flag.Bool("provisioner-enable-capacity", false, "This enables producing CSIStorageCapacity objects with capacity information from the driver's GetCapacity call.")
	capacityImmediateBinding       = flag.Bool("provisioner-capacity-for-immediate-binding", false, "Enables producing capacity information for storage classes with immediate binding. Not needed for the Kubernetes scheduler, maybe useful for other consumers or for debugging.")
	capacityPollInterval           = flag.Duration("provisioner-capacity-poll-interval", time.Minute, "How long the external-provisioner waits before checking for storage capacity changes.")
	capacityOwnerrefLevel          = flag.Int("provisioner-capacity-ownerref-level", 1, "The level indicates the number of objects that need to be traversed starting from the pod identified by the POD_NAME and NAMESPACE environment variables to reach the owning object for CSIStorageCapacity objects: -1 for no owner, 0 for the pod itself, 1 for a StatefulSet or DaemonSet, 2 for a Deployment, etc.")
	enableNodeDeployment           = flag.Bool("provisioner-node-deployment", false, "Enables deploying the external-provisioner together with a CSI driver on nodes to manage node-local volumes.")
	nodeDeploymentImmediateBinding = flag.Bool("provisioner-node-deployment-immediate-binding", true, "Determines whether immediate binding is supported when deployed on each node.")
	nodeDeploymentBaseDelay        = flag.Duration("provisioner-node-deployment-base-delay", 20*time.Second, "Determines how long the external-provisioner sleeps initially before trying to own a PVC with immediate binding.")
	nodeDeploymentMaxDelay         = flag.Duration("provisioner-node-deployment-max-delay", 60*time.Second, "Determines how long the external-provisioner sleeps at most before trying to own a PVC with immediate binding.")
	controllerPublishReadOnly      = flag.Bool("provisioner-controller-publish-readonly", false, "This option enables PV to be marked as readonly at controller publish volume call if PVC accessmode has been set to ROX.")
	preventVolumeModeConversion    = flag.Bool("provisioner-prevent-volume-mode-conversion", true, "Prevents an unauthorised user from modifying the volume mode when creating a PVC from an existing VolumeSnapshot.")
	provisionController            *controller.ProvisionController

	// Resizer specific
	handleVolumeInUseError = flag.Bool("resizer-handle-volume-inuse-error", true, "Flag to turn on/off capability to handle volume in use error in resizer controller. Defaults to true if not set.")
	extraModifyMetadata = flag.Bool("resizer-extra-modify-metadata", false, "If set, add pv/pvc metadata to plugin modify requests as parameters.")

	featureGates map[string]bool
	version      = "unknown"
)

func main() {
	flag.Var(utilflag.NewMapStringBool(&featureGates), "feature-gates", "A set of key=value pairs that describe feature gates for alpha/experimental features. "+
		"Options are:\n"+strings.Join(utilfeature.DefaultFeatureGate.KnownFeatures(), "\n"))

	klog.InitFlags(nil)
	flag.CommandLine.AddGoFlagSet(goflag.CommandLine)
	flag.Set("logtostderr", "true")

	// Resizer specific
	//fg := featuregate.NewFeatureGate()
	//logsapi.AddFeatureGates(fg)
	//c := logsapi.NewLoggingConfiguration()
	//logsapi.AddGoFlags(c, goflag.CommandLine)
	logs.InitLogs()

	flag.Parse()

	// Resizier specific
	/*if err := logsapi.ValidateAndApply(c, fg); err != nil {
		klog.ErrorS(err, "LoggingConfiguration is invalid")
		klog.FlushAndExit(klog.ExitFlushTimeout, 1)
	}*/

	if err := utilfeature.DefaultMutableFeatureGate.SetFromMap(featureGates); err != nil {
		klog.Fatal(err)
	}

	errs, ctx := errgroup.WithContext(context.Background())

	controllersToEnable := map[string]bool{}
	for _, ctrl := range strings.Split(*controllers, ",") {
		controllersToEnable[ctrl] = true
	}

	// TODO: Get main from each sidecar to return an error so we can handle it here
	if _, ok := controllersToEnable["attacher"]; ok {
		errs.Go(func() error {
			attacher_main(ctx)
			return fmt.Errorf("Attacher stopped")
		})
	}
	if _, ok := controllersToEnable["provisioner"]; ok {
		errs.Go(func() error {
			provisioner_main(ctx)
			return fmt.Errorf("Provisioner stopped")
		})
	}
	if _, ok := controllersToEnable["resizer"]; ok {
		errs.Go(func() error {
			resizer_main(ctx)
			return fmt.Errorf("Resizer stopped")
		})
	}

	if err := errs.Wait(); err != nil {
		panic(err)
	}
}
