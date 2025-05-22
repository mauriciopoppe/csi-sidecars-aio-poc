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

	"github.com/kubernetes-csi/csi-sidecars/cmd/csi-sidecars/config"
	attacherconfig "github.com/kubernetes-csi/csi-sidecars/pkg/attacher/cmd/csi-attacher/config"
	flag "github.com/spf13/pflag"
	"sigs.k8s.io/sig-storage-lib-external-provisioner/v11/controller"

	utilfeature "k8s.io/apiserver/pkg/util/feature"
	utilflag "k8s.io/component-base/cli/flag"
	"k8s.io/component-base/logs"
	"k8s.io/klog/v2"
)

var (
	master                      *string
	kubeconfig                  *string
	kubeConfig                  *string
	csiEndpoint                 *string
	csiAddress                  *string
	showVersion                 *bool
	resync                      *time.Duration
	resyncPeriod                *time.Duration
	workerThreads               *int
	workers                     *int
	timeout                     *time.Duration
	operationTimeout            *time.Duration
	retryIntervalStart          *time.Duration
	retryIntervalMax            *time.Duration
	enableLeaderElection        *bool
	leaderElectionNamespace     *string
	leaderElectionLeaseDuration *time.Duration
	leaderElectionRenewDeadline *time.Duration
	leaderElectionRetryPeriod   *time.Duration
	kubeAPIQPS                  *float32
	kubeAPIBurst                *int
	defaultFSType               *string
	httpEndpoint                *string
	metricsAddress              *string
	metricsPath                 *string
	maxGRPCLogLength            *int
	maxEntries                  *int
	reconcileSync               *time.Duration
)

var (

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
	extraModifyMetadata    = flag.Bool("resizer-extra-modify-metadata", false, "If set, add pv/pvc metadata to plugin modify requests as parameters.")

	featureGates map[string]bool
	version      = "unknown"
)

// copyFlagsFromConfigToGlobalVars copies flags from config.AIOConfiguration to the global vars
// This is a workaround until the sidecars are refactored to work with a nested config.
func copyFlagsFromConfigToGlobalVars() {
	master = &config.Configuration.Master
	kubeconfig = &config.Configuration.KubeConfig
	kubeConfig = &config.Configuration.KubeConfig
	csiEndpoint = &config.Configuration.CSIAddress
	csiAddress = &config.Configuration.CSIAddress
	showVersion = &config.Configuration.ShowVersion
	resync = &config.Configuration.Resync
	resyncPeriod = &config.Configuration.Resync
	retryIntervalStart = &config.Configuration.RetryIntervalStart
	retryIntervalMax = &config.Configuration.RetryIntervalMax
	enableLeaderElection = &config.Configuration.LeaderElection
	leaderElectionNamespace = &config.Configuration.LeaderElectionNamespace
	leaderElectionLeaseDuration = &config.Configuration.LeaderElectionLeaseDuration
	leaderElectionRenewDeadline = &config.Configuration.LeaderElectionRenewDeadline
	leaderElectionRetryPeriod = &config.Configuration.LeaderElectionRetryPeriod

	var kubeAPIQPSFloat64Ptr *float64
	kubeAPIQPSFloat64Ptr = &config.Configuration.KubeAPIQPS
	kubeAPIQPSFloat32 := float32(*kubeAPIQPSFloat64Ptr)
	kubeAPIQPS = &kubeAPIQPSFloat32

	kubeAPIBurst = &config.Configuration.KubeAPIBurst
	httpEndpoint = &config.Configuration.HttpEndpoint
	metricsAddress = &config.Configuration.MetricsAddress
	metricsPath = &config.Configuration.MetricsPath

	defaultFSType = &config.Configuration.AttacherConfiguration.DefaultFSType
	workerThreads = &config.Configuration.AttacherConfiguration.WorkerThreads
	workers = &config.Configuration.AttacherConfiguration.WorkerThreads
	maxGRPCLogLength = &config.Configuration.AttacherConfiguration.MaxGRPCLogLength
	maxEntries = &config.Configuration.AttacherConfiguration.MaxEntries
	reconcileSync = &config.Configuration.AttacherConfiguration.ReconcileSync

	// TODO: define if timeout should be global or not
	timeout = &config.Configuration.AttacherConfiguration.Timeout
	operationTimeout = &config.Configuration.AttacherConfiguration.Timeout
}

func main() {
	flag.Var(utilflag.NewMapStringBool(&featureGates), "feature-gates", "A set of key=value pairs that describe feature gates for alpha/experimental features. "+
		"Options are:\n"+strings.Join(utilfeature.DefaultFeatureGate.KnownFeatures(), "\n"))

	klog.InitFlags(nil)
	config.RegisterCommonFlags(goflag.CommandLine)
	attacherconfig.RegisterAttacherFlagsWithPrefix(goflag.CommandLine, &config.Configuration.AttacherConfiguration)
	flag.CommandLine.AddGoFlagSet(goflag.CommandLine)
	flag.Set("logtostderr", "true")

	// Resizer specific
	// fg := featuregate.NewFeatureGate()
	// logsapi.AddFeatureGates(fg)
	// c := logsapi.NewLoggingConfiguration()
	// logsapi.AddGoFlags(c, goflag.CommandLine)
	logs.InitLogs()

	flag.Parse()

	copyFlagsFromConfigToGlobalVars()

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
	for _, ctrl := range strings.Split(*&config.Configuration.Controllers, ",") {
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
