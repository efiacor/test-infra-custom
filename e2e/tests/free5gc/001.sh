#!/usr/bin/env bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2023 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

## TEST METADATA
## TEST-NAME: Deploy regional workload cluster
##

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

# shellcheck source=e2e/defaults.env
source "$E2EDIR/defaults.env"

# shellcheck source=e2e/lib/k8s.sh
source "${LIBDIR}/k8s.sh"

# shellcheck source=e2e/lib/capi.sh
source "${LIBDIR}/capi.sh"

# shellcheck source=e2e/lib/porch.sh
source "${LIBDIR}/porch.sh"

# shellcheck source=e2e/lib/_assertions.sh
source "${LIBDIR}/_assertions.sh"

# shellcheck source=e2e/lib/_utils.sh
source "${LIBDIR}/_utils.sh"


regional_pkg_rev=$(porchctl rpkg clone -n default "https://github.com/nephio-project/catalog.git/infra/capi/nephio-workload-cluster@$REVISION" --repository mgmt regional | cut -f 1 -d ' ')
k8s_wait_exists "packagerev" "$regional_pkg_rev"


pushd "$(mktemp -d -t "001-pkg-XXX")" >/dev/null
trap popd EXIT

porchctl rpkg pull -n default "$regional_pkg_rev" regional
kpt fn eval --image "gcr.io/kpt-fn/set-labels:v0.2.0" regional -- "nephio.org/site-type=regional" "nephio.org/region=us-west1"
assert_contains "$(cat regional/workload-cluster.yaml)" "nephio.org/region: us-west1" "Workload cluster doesn't have region label"

porchctl rpkg push -n default "$regional_pkg_rev" regional

# Proposal
porchctl rpkg propose -n default "$regional_pkg_rev"

# Approval
porchctl rpkg approve -n default "$regional_pkg_rev"

k8s_wait_exists "workloadcluster" "regional" "$HOME/.kube/config"
capi_cluster_ready "regional"
