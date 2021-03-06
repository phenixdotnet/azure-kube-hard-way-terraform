KUBE_VERSION="1.17.1"
CRI_VERSION="1.17.0"
RUNC_VERSION="1.0.0-rc9"
CNI_PLUGINS_VERSION="0.8.4"
CONTAINERD_VERSION="1.3.2"

wget -q --show-progress --https-only --timestamping \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRI_VERSION}/crictl-v${CRI_VERSION}-linux-amd64.tar.gz" \
  "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64" \
  "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz" \
  "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kube-proxy" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubelet" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl"

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /etc/containerd

mkdir containerd && \
tar -xvf containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz -C containerd

sudo tar -xvf cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz -C /opt/cni/bin/
sudo mv runc.amd64 runc

tar -xvf crictl-v${CRI_VERSION}-linux-amd64.tar.gz && \
chmod +x crictl kubectl kube-proxy kubelet runc && \
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/ && \
sudo mv containerd/bin/* /bin/