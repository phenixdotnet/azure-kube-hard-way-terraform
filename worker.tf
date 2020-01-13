# Configure the Microsoft Azure Provider
locals {
  worker_virtual_machine_name  = "kubeworker"
}

resource "local_file" "worker_cert_csr" {
  count = var.count_worker
  content = templatefile("ca/worker-csr.json.tmpl", { instance = "${local.worker_virtual_machine_name}-${count.index + 1}" })
  filename = "ca/${local.worker_virtual_machine_name}-${count.index + 1}-csr.json"
}

resource "azurerm_virtual_machine" "kubeworker" {

  count                         = var.count_worker

  name                          = "${local.worker_virtual_machine_name}-${count.index + 1}"
  location                      = azurerm_resource_group.kubetest.location
  resource_group_name           = azurerm_resource_group.kubetest.name

  primary_network_interface_id  = azurerm_network_interface.internal_worker[count.index].id
  network_interface_ids         = [azurerm_network_interface.internal_worker[count.index].id]
  vm_size                       = "Standard_A4_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.worker_virtual_machine_name}-${count.index + 1}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name   = "${local.worker_virtual_machine_name}-${count.index + 1}"
    admin_username  = var.admin_username
    admin_password  = var.admin_password
    custom_data     = file(var.cloud_init_file)
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

resource "null_resource" "kubeworker_ca" {
  depends_on = [azurerm_virtual_machine.kubeworker]

  count = var.count_worker

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.worker[count.index].ip_address
    private_key = file("/home/vlaine/.ssh/id_rsa")
    agent = false
  }


  provisioner "local-exec" {
      command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${local.worker_virtual_machine_name}-${count.index + 1},${azurerm_network_interface.internal_worker[count.index].private_ip_address} -profile=kubernetes ${local.worker_virtual_machine_name}-${count.index + 1}-csr.json | cfssljson -bare ${local.worker_virtual_machine_name}-${count.index + 1}"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "ca/ca.pem"
      destination = "/home/${var.admin_username}/ca.pem"
  }

  provisioner "file" {
      source = "ca/${local.worker_virtual_machine_name}-${count.index + 1}-key.pem"
      destination = "/home/${var.admin_username}/${local.worker_virtual_machine_name}-${count.index + 1}-key.pem"
  }

  provisioner "file" {
      source = "ca/${local.worker_virtual_machine_name}-${count.index + 1}.pem"
      destination = "/home/${var.admin_username}/${local.worker_virtual_machine_name}-${count.index + 1}.pem"
  }

  provisioner "file" {
      source = "ca/${local.worker_virtual_machine_name}-${count.index + 1}.pem"
      destination = "/home/${var.admin_username}/${local.worker_virtual_machine_name}-${count.index + 1}.pem"
  }

  provisioner "file" {
      source = "ca/${local.worker_virtual_machine_name}-${count.index + 1}-key.pem"
      destination = "/home/${var.admin_username}/${local.worker_virtual_machine_name}-${count.index + 1}-key.pem"
  }
}

resource "null_resource" "kubeworker_config" {
  depends_on = [null_resource.kubeworker_ca]
  count = var.count_worker

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.worker[count.index].ip_address
    private_key = file("/home/vlaine/.ssh/id_rsa")
    agent = false
  }

  provisioner "local-exec" {
      command = "kubectl config set-cluster ${var.cluster_name} --certificate-authority=ca.pem --embed-certs=true --server=https://${azurerm_lb.kubeapi.private_ip_address}:6443 --kubeconfig=../config/${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-credentials system:node:${local.worker_virtual_machine_name}-${count.index + 1} --client-certificate=${local.worker_virtual_machine_name}-${count.index + 1}.pem --client-key=${local.worker_virtual_machine_name}-${count.index + 1}-key.pem --embed-certs=true --kubeconfig=${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-context default --cluster=${var.cluster_name} --user=system:node:${local.worker_virtual_machine_name}-${count.index + 1} --kubeconfig=${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config use-context default --kubeconfig=${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "config/${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
      destination = "/home/${var.admin_username}/${local.worker_virtual_machine_name}-${count.index + 1}.kubeconfig"
  }

  # Kube proxy config
  provisioner "local-exec" {
      command = "kubectl config set-cluster ${var.cluster_name} --certificate-authority=ca.pem --embed-certs=true --server=https://${azurerm_lb.kubeapi.private_ip_address}:6443 --kubeconfig=../config/kube-proxy.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-credentials system:kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=../config/kube-proxy.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config set-context default --cluster=${var.cluster_name} --user=system:kube-proxy --kubeconfig=../config/kube-proxy.kubeconfig"
      working_dir = "ca"
  }

  provisioner "local-exec" {
      command = "kubectl config use-context default --kubeconfig=../config/kube-proxy.kubeconfig"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "config/kube-proxy.kubeconfig"
      destination = "/home/${var.admin_username}/kube-proxy.kubeconfig"
  }

}
