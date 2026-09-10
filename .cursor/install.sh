#!/usr/bin/env bash
# Idempotent bootstrap for the AutoRepairShop Kubernetes (IaC) repository.
# Installs the validation toolchain (Terraform, kubectl, kubeval) pinned to the
# versions used by CI / the target cluster, then initializes the Terraform
# working directory so `terraform validate` works offline.
set -euo pipefail

TERRAFORM_VERSION="1.6.6"   # matches .github/workflows/ci.yml
KUBECTL_VERSION="v1.31.2"   # matches the EKS cluster version (infra/main.tf)
KUBEVAL_VERSION="0.16.1"

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
BIN_DIR="/usr/local/bin"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Some build environments run as root (no sudo binary); guard accordingly.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "==> Ensuring base packages (curl, unzip)"
if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  $SUDO apt-get update -qq
  $SUDO apt-get install -y --no-install-recommends curl unzip ca-certificates
fi

install_terraform() {
  local cur=""
  command -v terraform >/dev/null 2>&1 && cur="$(terraform version 2>/dev/null | head -1 || true)"
  if [ "${cur#*v${TERRAFORM_VERSION}}" != "$cur" ]; then
    echo "==> terraform ${TERRAFORM_VERSION} already installed"
    return
  fi
  echo "==> Installing terraform ${TERRAFORM_VERSION}"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/tf.zip" \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip"
  unzip -o "${tmp}/tf.zip" -d "${tmp}" >/dev/null
  $SUDO install -m 0755 "${tmp}/terraform" "${BIN_DIR}/terraform"
  rm -rf "${tmp}"
}

install_kubectl() {
  local cur=""
  command -v kubectl >/dev/null 2>&1 && cur="$(kubectl version --client 2>/dev/null | head -1 || true)"
  if [ "${cur#*${KUBECTL_VERSION}}" != "$cur" ]; then
    echo "==> kubectl ${KUBECTL_VERSION} already installed"
    return
  fi
  echo "==> Installing kubectl ${KUBECTL_VERSION}"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/kubectl" \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  $SUDO install -m 0755 "${tmp}/kubectl" "${BIN_DIR}/kubectl"
  rm -rf "${tmp}"
}

install_kubeval() {
  local cur=""
  command -v kubeval >/dev/null 2>&1 && cur="$(kubeval --version 2>/dev/null | head -1 || true)"
  if [ "${cur#*${KUBEVAL_VERSION}}" != "$cur" ]; then
    echo "==> kubeval ${KUBEVAL_VERSION} already installed"
    return
  fi
  echo "==> Installing kubeval ${KUBEVAL_VERSION}"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/kubeval.tar.gz" \
    "https://github.com/instrumenta/kubeval/releases/download/v${KUBEVAL_VERSION}/kubeval-linux-${ARCH}.tar.gz"
  tar -xzf "${tmp}/kubeval.tar.gz" -C "${tmp}" kubeval
  $SUDO install -m 0755 "${tmp}/kubeval" "${BIN_DIR}/kubeval"
  rm -rf "${tmp}"
}

install_terraform
install_kubectl
install_kubeval

echo "==> Initializing Terraform providers (infra/)"
# -backend=false: no remote state needed for local validation.
( cd "${REPO_ROOT}/infra" && terraform init -backend=false -input=false )

echo "==> Toolchain ready:"
terraform version | head -1
kubectl version --client 2>/dev/null | head -1
kubeval --version | head -1
