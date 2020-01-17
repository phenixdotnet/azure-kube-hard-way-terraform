KUBE_VERSION="1.17.0"

wget -q --show-progress --https-only --timestamping \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${KUBE_VERSION}/crictl-v${KUBE_VERSION}-linux-amd64.tar.gz" \
  "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc9/runc.amd64" \
  "https://github.com/containernetworking/plugins/releases/download/v0.8.4/cni-plugins-linux-amd64-v0.8.4.tgz" \
  "https://github.com/containerd/containerd/releases/download/v1.3.2/containerd-1.3.2.linux-amd64.tar.gz" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kube-proxy" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubelet" \  
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl"

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

mkdir containerd && \
tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd

sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
sudo mv runc.amd64 runc

tar -xvf crictl-v1.15.0-linux-amd64.tar.gz && \
chmod +x crictl kubectl kube-proxy kubelet runc && \
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/ && \
sudo mv containerd/bin/* /bin/