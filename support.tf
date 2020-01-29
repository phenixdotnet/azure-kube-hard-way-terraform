resource "azurerm_public_ip" "support" {
  name                = "${var.prefix}-ext-support-ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "internal_support" {
  name                = "${var.prefix}-int-support-nic"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name

  network_security_group_id   = azurerm_network_security_group.firewall.id
  enable_ip_forwarding  = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kubetest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.support.id
  }
} 

resource "azurerm_virtual_machine" "support" {

  name                          = "${var.prefix}-support"
  location                      = azurerm_resource_group.kubetest.location
  resource_group_name           = azurerm_resource_group.kubetest.name

  primary_network_interface_id  = azurerm_network_interface.internal_support.id
  network_interface_ids         = [azurerm_network_interface.internal_support.id]
  vm_size                       = "Standard_B2s"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-support-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name   = "${var.prefix}-support"
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


  connection {
    type = "ssh"
    user = var.admin_username
    host = azurerm_public_ip.support.ip_address
    private_key = file(var.private_ssh_key)
    agent = false
  }

  provisioner "file" {
      source = "config/admin.kubeconfig"
      destination = "/home/${var.admin_username}/admin.kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.kube && mv admin.kubeconfig ~/.kube/default",
      "wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
    ]
  }
}

output "support_ip_address" {
  value = azurerm_public_ip.support.ip_address
}