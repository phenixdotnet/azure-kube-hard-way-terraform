# Configure the Microsoft Azure Provider
provider "azurerm" {
}

locals {
  master_virtual_machine_name  = "kubemaster"
}

resource "random_password" "encryption_key" {
  length = 32
}

resource "local_file" "encryption_config" {
  content = templatefile("config/encryption-config.yaml.tmpl", {encryption_key = base64encode(random_password.encryption_key.result)})
  filename = "config/encryption-config.yaml"
}

resource "azurerm_resource_group" "kubetest" {
  name     = var.prefix
  location = var.location
}

resource "azurerm_virtual_machine" "kubemaster" {

  count                         = var.count_master

  name                          = "${var.prefix}-master-${count.index + 1}"
  location                      = azurerm_resource_group.kubetest.location
  resource_group_name           = azurerm_resource_group.kubetest.name

  primary_network_interface_id  = azurerm_network_interface.internal_master[count.index].id
  network_interface_ids         = [azurerm_network_interface.internal_master[count.index].id]
  vm_size                       = "Standard_A4_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-master-${count.index + 1}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name   = "${var.prefix}-master-${count.index + 1}"
    admin_username  = var.admin_username
    admin_password  = var.admin_password
    custom_data     = file(var.cloud_init_file_master)
  }

  os_profile_linux_config {
    disable_password_authentication = false

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.public_ssh_key)
    }
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = azurerm_storage_account.kubetest.primary_blob_endpoint
  }
}

locals {

  internal_ips = [
    for net in azurerm_network_interface.internal_master:
    net.private_ip_address
  ]

  master_public_ips = [
    for net in azurerm_public_ip.master:
    net.ip_address
  ]

  internal_etcd_endpoints = [
    for net in azurerm_network_interface.internal_master:
    "https://${net.private_ip_address}:2380"
  ]

  internal_etcd_members = [
    for k,vm in azurerm_virtual_machine.kubemaster:
    "${vm.name}=https://${azurerm_network_interface.internal_master[k].private_ip_address}:2380"
  ]

  internal_etcd_public_endpoints = [
    for net in azurerm_network_interface.internal_master:
    "https://${net.private_ip_address}:2379"
  ]
}

resource "null_resource" "kubemaster_ca" {
  depends_on = [azurerm_virtual_machine.kubemaster]

  count = var.count_master

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }

  provisioner "local-exec" {
      command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${azurerm_lb.kubeapi.private_ip_address},10.32.0.1,${join(",",local.internal_ips)},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "ca/ca.pem"
      destination = "/home/${var.admin_username}/ca.pem"
  }

  provisioner "file" {
      source = "ca/ca-key.pem"
      destination = "/home/${var.admin_username}/ca-key.pem"
  }

  provisioner "file" {
      source = "ca/kubernetes.pem"
      destination = "/home/${var.admin_username}/kubernetes.pem"
  }

  provisioner "file" {
      source = "ca/kubernetes-key.pem"
      destination = "/home/${var.admin_username}/kubernetes-key.pem"
  }

  provisioner "file" {
      source = "ca/service-account-key.pem"
      destination = "/home/${var.admin_username}/service-account-key.pem"
  }

  provisioner "file" {
      source = "ca/service-account.pem"
      destination = "/home/${var.admin_username}/service-account.pem"
  }
}

resource "null_resource" "kubemaster_config" {
  depends_on = [null_resource.kubemaster_ca]
  count = var.count_master

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }

  # kube-controller-manager
  provisioner "local-exec" {
      command = "kubectl config set-cluster ${var.cluster_name} --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=../config/kube-controller-manager.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=../config/kube-controller-manager.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-context default --cluster=${var.cluster_name} --user=system:kube-controller-manager --kubeconfig=../config/kube-controller-manager.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config use-context default --kubeconfig=../config/kube-controller-manager.kubeconfig"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "config/kube-controller-manager.kubeconfig"
      destination = "/home/${var.admin_username}/kube-controller-manager.kubeconfig"
  }

  # kube-scheduler
  provisioner "local-exec" {
      command = "kubectl config set-cluster ${var.cluster_name} --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=../config/kube-scheduler.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=../config/kube-scheduler.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-context default --cluster=${var.cluster_name} --user=system:kube-scheduler --kubeconfig=../config/kube-scheduler.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config use-context default --kubeconfig=../config/kube-scheduler.kubeconfig"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "config/kube-scheduler.kubeconfig"
      destination = "/home/${var.admin_username}/kube-scheduler.kubeconfig"
  }

  # admin
  provisioner "local-exec" {
      command = "kubectl config set-cluster ${var.cluster_name} --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=../config/admin.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=../config/admin.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-context default --cluster=${var.cluster_name} --user=admin --kubeconfig=../config/admin.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config use-context default --kubeconfig=../config/admin.kubeconfig"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "config/admin.kubeconfig"
      destination = "/home/${var.admin_username}/admin.kubeconfig"
  }

  # Encryption config
  provisioner "file" {
      source = "config/encryption-config.yaml"
      destination = "/home/${var.admin_username}/encryption-config.yaml"
  }
}

resource "local_file" "etcd_config" {
  depends_on = [null_resource.kubemaster_config]

  count = var.count_master

  content = templatefile("config/etcd.service.tmpl", {
      hostname = azurerm_virtual_machine.kubemaster[count.index].name, 
      private_ip = azurerm_network_interface.internal_master[count.index].private_ip_address, 
      initial_cluster = join(",", local.internal_etcd_members)})
  filename = "config/etcd.service_${azurerm_virtual_machine.kubemaster[count.index].name}.yaml"

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }
  
  provisioner "file" {
      source = "config/etcd.service_${azurerm_virtual_machine.kubemaster[count.index].name}.yaml"
      destination = "/home/${var.admin_username}/etcd.service"
  }
}

resource "null_resource" "etcd_reload" {
  depends_on = [local_file.etcd_config]
  count = var.count_master

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }

  provisioner "file" {
      source = "scripts/download_etcd.sh"
      destination = "/tmp/download_etcd.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /tmp/download_etcd.sh && /tmp/download_etcd.sh",
      "sudo mv /tmp/etcd-download-test/etcd* /usr/local/bin/",
      "sudo mkdir -p /etc/etcd /var/lib/etcd",
      "sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/",
      "sudo mv /home/${var.admin_username}/etcd.service /etc/systemd/system/etcd.service",
      "sudo systemctl daemon-reload && sudo systemctl enable etcd && sudo systemctl --no-block start etcd"
    ]
  }
}

resource "null_resource" "kube_download" {
  depends_on = [null_resource.etcd_reload]

  count = var.count_master

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }

  provisioner "file" {
      source = "scripts/download_kubernetes_master.sh"
      destination = "/home/${var.admin_username}/download_kubernetes.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x download_kubernetes.sh",
      "./download_kubernetes.sh"
    ]
  }

}

resource "local_file" "kube-apiserver_config" {
  depends_on = [null_resource.kube_download]

  count = var.count_master

  content = templatefile("config/kube-apiserver.service.tmpl", {
      private_ip = azurerm_network_interface.internal_master[count.index].private_ip_address, 
      etcd_cluster = join(",", local.internal_etcd_public_endpoints),
      cidr = "10.32.0.0/24",
      count_master = length(azurerm_network_interface.internal_master)})
  filename = "config/kube-apiserver.service_${azurerm_virtual_machine.kubemaster[count.index].name}"

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }
  
  provisioner "file" {
      source = "config/kube-apiserver.service_${azurerm_virtual_machine.kubemaster[count.index].name}"
      destination = "/home/${var.admin_username}/kube-apiserver.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/config /var/lib/kubernetes/",
      "sudo mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service",
      "sudo systemctl daemon-reload && sudo systemctl enable kube-apiserver && sudo systemctl start kube-apiserver"
    ]
  }
}

resource "local_file" "kube-controller-manager_config" {
  depends_on = [local_file.kube-apiserver_config]

  count = var.count_master

  content = templatefile("config/kube-controller-manager.service.tmpl", {
      private_ip = azurerm_network_interface.internal_master[count.index].private_ip_address, 
      etcd_cluster = join(",", local.internal_etcd_public_endpoints),
      cluster_cidr = var.cluster_cidr,
      cluster_service_cidr = var.cluster_service_cidr})
  filename = "config/kube-controller-manager.service_${azurerm_virtual_machine.kubemaster[count.index].name}"

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }
  
  provisioner "file" {
      source = "config/kube-controller-manager.service_${azurerm_virtual_machine.kubemaster[count.index].name}"
      destination = "/home/${var.admin_username}/kube-controller-manager.service"
  }

  provisioner "file" {
    source = "config/kube-controller-manager.kubeconfig"
    destination = "/home/${var.admin_username}/kube-controller-manager.kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/",
      "sudo mv kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service",
      "sudo systemctl daemon-reload && sudo systemctl enable kube-controller-manager && sudo systemctl start kube-controller-manager"
    ]
  }
}

resource "null_resource" "kube-scheduler_config" {
  depends_on = [local_file.kube-controller-manager_config]

  count = var.count_master

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }
  
  provisioner "file" {
      source = "config/kube-scheduler.service"
      destination = "/home/${var.admin_username}/kube-scheduler.service"
  }

  provisioner "file" {
    source = "config/kube-scheduler.kubeconfig"
    destination = "/home/${var.admin_username}/kube-scheduler.kubeconfig"
  }

  provisioner "file" {
    source = "config/kube-scheduler.yaml"
    destination = "/home/${var.admin_username}/kube-scheduler.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/",
      "sudo mv kube-scheduler.service /etc/systemd/system/kube-scheduler.service",
      "sudo mv kube-scheduler.yaml /etc/kubernetes/config/kube-scheduler.yaml",
      "sudo systemctl daemon-reload && sudo systemctl enable kube-scheduler && sudo systemctl start kube-scheduler"
    ]
  }
}

resource "null_resource" "kube-rbac" {
  depends_on = [null_resource.kube-scheduler_config]

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[0].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }
  
  provisioner "file" {
      source = "config/kube-apiserver-to-kubelet-ClusterRole.yaml"
      destination = "/home/${var.admin_username}/kube-apiserver-to-kubelet-ClusterRole.yaml"
  }

  provisioner "file" {
      source = "config/kube-apiserver-to-kubelet-ClusterRoleBinding.yaml"
      destination = "/home/${var.admin_username}/kube-apiserver-to-kubelet-ClusterRoleBinding.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl apply --kubeconfig admin.kubeconfig -f /home/${var.admin_username}/kube-apiserver-to-kubelet-ClusterRole.yaml",
      "kubectl apply --kubeconfig admin.kubeconfig -f /home/${var.admin_username}/kube-apiserver-to-kubelet-ClusterRoleBinding.yaml"
    ]
  }
}

output "master_ip_addresses" {
  value = local.master_public_ips
}