#!/bin/bash

# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

KIND_LOG_LEVEL="1"

if ! [ -z $DEBUG ]; then
  set -x
  KIND_LOG_LEVEL="6"
fi

set -o errexit
set -o nounset
set -o pipefail

cleanup() {
  if [[ "${KUBETEST_IN_DOCKER:-}" == "true" ]]; then
    kind "export" logs --name ${KIND_CLUSTER_NAME} "${ARTIFACTS}/logs" || true
  fi

  kind delete cluster \
    --name ${KIND_CLUSTER_NAME}
}

trap cleanup EXIT

if ! command -v kind --version &> /dev/null; then
  echo "kind is not installed. Use the package manager or visit the official site https://kind.sigs.k8s.io/"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-ingress-nginx-dev}

BASEDIR=$(dirname "$0")
NGINX_BASE_IMAGE=$(cat $BASEDIR/../../NGINX_BASE)

echo "Running e2e with nginx base image ${NGINX_BASE_IMAGE}"

export NGINX_BASE_IMAGE=$NGINX_BASE_IMAGE

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-config-$KIND_CLUSTER_NAME}"

if [ "${SKIP_CLUSTER_CREATION:-false}" = "false" ]; then
  echo "[dev-env] creating Kubernetes cluster with kind"

  export K8S_VERSION=${K8S_VERSION:-v1.20.2@sha256:8f7ea6e7642c0da54f04a7ee10431549c0257315b3a634f6ef2fecaaedb19bab}

  kind create cluster \
    --verbosity=${KIND_LOG_LEVEL} \
    --name ${KIND_CLUSTER_NAME} \
    --config ${DIR}/kind.yaml \
    --retain \
    --image "kindest/node:${K8S_VERSION}"

  echo "Kubernetes cluster:"
  kubectl get nodes -o wide
fi

echo "[dev-env] running helm chart e2e tests..."
# Uses a custom chart-testing image to avoid timeouts waiting for namespace deletion.
# The changes can be found here: https://github.com/aledbf/chart-testing/commit/41fe0ae0733d0c9a538099fb3cec522e888e3d82
docker run --rm --interactive --network host \
    --name ct \
    --volume $KUBECONFIG:/root/.kube/config \
    --volume "${DIR}/../../":/workdir \
    --workdir /workdir \
    aledbf/chart-testing:v3.3.1-next ct install \
        --charts charts/ingress-nginx \
        --helm-extra-args "--timeout 60s"
