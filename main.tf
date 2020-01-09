# Configure the Microsoft Azure Provider
provider "azurerm" {
}

locals {
  master_virtual_machine_name  = "kubemaster"
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

resource "null_resource" "kubemaster" {
  depends_on = [azurerm_virtual_machine.kubemaster]

  count = var.count_agent

  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.master[count.index].ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }


  provisioner "local-exec" {
      command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${local.agent_virtual_machine_name}-${count.index + 1},${azurerm_network_interface.internal_agent[count.index].private_ip_address} -profile=kubernetes ${local.agent_virtual_machine_name}-${count.index + 1}-csr.json | cfssljson -bare ${local.agent_virtual_machine_name}-${count.index + 1}"
      working_dir = "ca"
  }

  provisioner "file" {
      source = "ca/ca.pem"
      destination = "/home/${var.admin_username}/ca.pem"
  }

  provisioner "file" {
      source = "ca/${local.agent_virtual_machine_name}-${count.index + 1}-key.pem"
      destination = "/home/${var.admin_username}/${local.agent_virtual_machine_name}-${count.index + 1}-key.pem"
  }

  provisioner "file" {
      source = "ca/${local.agent_virtual_machine_name}-${count.index + 1}.pem"
      destination = "/home/${var.admin_username}/${local.agent_virtual_machine_name}-${count.index + 1}.pem"
  }

  provisioner "file" {
      source = "ca/${local.agent_virtual_machine_name}-${count.index + 1}.pem"
      destination = "/home/${var.admin_username}/${local.agent_virtual_machine_name}-${count.index + 1}.pem"
  }

  provisioner "file" {
      source = "ca/${local.agent_virtual_machine_name}-${count.index + 1}-key.pem"
      destination = "/home/${var.admin_username}/${local.agent_virtual_machine_name}-${count.index + 1}-key.pem"
  }
}