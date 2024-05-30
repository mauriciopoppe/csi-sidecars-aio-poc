# Custom CSI hostpath driver

The existence of this folder is well explained in release-tools/prow.sh,
copying the documentation of the relevant CSI_PROW_* env vars here:

```bash
# By default, this script tests sidecars with the CSI hostpath driver,
# using the install_csi_driver function. That function depends on
# a deployment script that it searches for in several places:
#
# - The "deploy" directory in the current repository: this is useful
#   for the situation that a component becomes incompatible with the
#   shared deployment, because then it can (temporarily!) provide its
#   own example until the shared one can be updated; it's also how
#   csi-driver-host-path itself provides the example.
#
# - CSI_PROW_DRIVER_VERSION of the CSI_PROW_DRIVER_REPO is checked
#   out: this allows other repos to reference a version of the example
#   that is known to be compatible.
#
# - The <driver repo>/deploy directory can have multiple sub-directories,
#   each with different deployments (stable set of images for Kubernetes 1.13,
#   stable set of images for Kubernetes 1.14, canary for latest Kubernetes, etc.).
#   This is necessary because there may be incompatible changes in the
#   "API" of a component (for example, its command line options or RBAC rules)
#   or in its support for different Kubernetes versions (CSIDriverInfo as
#   CRD in Kubernetes 1.13 vs builtin API in Kubernetes 1.14).
#
#   When testing an update for a component in a PR job, the
#   CSI_PROW_DEPLOYMENT variable can be set in the
#   .prow.sh of each component when there are breaking changes
#   that require using a non-default deployment. The default
#   is a deployment named "kubernetes-x.yy${CSI_PROW_DEPLOYMENT_SUFFIX}" (if available),
#   otherwise "kubernetes-latest${CSI_PROW_DEPLOYMENT_SUFFIX}".
#   "none" disables the deployment of the hostpath driver.
#
# When no deploy script is found (nothing in `deploy` directory,
# CSI_PROW_DRIVER_REPO=none), nothing gets deployed.
#
# If the deployment script is called with CSI_PROW_TEST_DRIVER=<file name> as
# environment variable, then it must write a suitable test driver configuration
# into that file in addition to installing the driver.
configvar CSI_PROW_DRIVER_VERSION "v1.12.0" "CSI driver version"
configvar CSI_PROW_DRIVER_REPO https://github.com/kubernetes-csi/csi-driver-host-path "CSI driver repo"
configvar CSI_PROW_DEPLOYMENT "" "deployment"
configvar CSI_PROW_DEPLOYMENT_SUFFIX "" "additional suffix in kubernetes-x.yy[suffix].yaml files"
```

We're implementing the 1st scenario above which is a local CSI Hostpath deployment.

I copied these manifest from https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/deploy/kubernetes-1.27/
