resource "azurerm_virtual_network" "kubetest" {
  name                = "${var.prefix}-network"
  address_space       = ["172.16.0.0/16"]
  resource_group_name = azurerm_resource_group.kubetest.name
  location            = azurerm_resource_group.kubetest.location
}

resource "azurerm_subnet" "kubetest" {
  name                 = var.prefix
  virtual_network_name = azurerm_virtual_network.kubetest.name
  resource_group_name  = azurerm_resource_group.kubetest.name
  address_prefix       = "172.16.1.0/24"
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.kubetest.name
  virtual_network_name = azurerm_virtual_network.kubetest.name
  address_prefix       = "172.16.2.224/27"
}

resource "azurerm_public_ip" "bastion" {
  name                = "bastion_ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "agent" {
  count               = var.count_agent
  name                = "${var.prefix}-ext-agent-${count.index + 1}-ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "master" {
  count               = var.count_agent
  name                = "${var.prefix}-ext-master-${count.index + 1}-ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "internal_master" {
  count               = var.count_master
  name                = "${var.prefix}-int-master-${count.index + 1}-nic"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kubetest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.master[count.index].id
  }
} 

resource "azurerm_network_interface" "internal_agent" {
  count               = var.count_agent
  name                = "${var.prefix}-int-agent-${count.index + 1}-nic"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name

  network_security_group_id   = azurerm_network_security_group.firewall.id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kubetest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent[count.index].id
  }
}

resource "azurerm_network_security_group" "firewall" {
  name                = "${var.prefix}-security-group"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kubetest.name
  network_security_group_name = azurerm_network_security_group.firewall.name
}