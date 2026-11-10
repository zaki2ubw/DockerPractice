#!/bin/sh

set -eu

LOGIN_NAME="$(id -un)"
DATA_ROOT="/home/${LOGIN_NAME}/data/docker"
DOMAIN_NAME="${LOGIN_NAME}.42.fr"

VM_IP="$(ip -4 addr show eth0 \
    | awk '/inet / {print $2}' \
    | cut -d/ -f1 \
    | head -n1)"

doas mkdir -p "${DATA_ROOT}"
doas mkdir -p /etc/docker

CURRENT_ROOT="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"

if [ "${CURRENT_ROOT}" != "${DATA_ROOT}" ]; then
    doas sh -c "cat > /etc/docker/daemon.json <<JSON
{
  \"data-root\": \"${DATA_ROOT}\"
}
JSON"

    doas service docker restart
fi

# 現在のIPとドメインの組み合わせが登録済みなら変更しない
if ! grep -qFx "${VM_IP} ${DOMAIN_NAME}" /etc/hosts; then
    # 古いドメイン設定を除去して、現在のIPで登録する
    doas sed -i "\|[[:space:]]${DOMAIN_NAME}$|d" /etc/hosts
    echo "${VM_IP} ${DOMAIN_NAME}" | doas tee -a /etc/hosts >/dev/null
fi

echo "Docker data-root: $(docker info --format '{{.DockerRootDir}}')"
echo "Domain: ${DOMAIN_NAME} -> ${VM_IP}"
