resource "azurerm_virtual_network" "kubetest" {
  name                = "${var.prefix}-network"
  address_space       = [var.network_address_range]
  resource_group_name = azurerm_resource_group.kubetest.name
  location            = azurerm_resource_group.kubetest.location
}

resource "azurerm_subnet" "kubetest" {
  name                 = "${var.prefix}-vms"
  virtual_network_name = azurerm_virtual_network.kubetest.name
  resource_group_name  = azurerm_resource_group.kubetest.name
  address_prefix       = var.vms_cidr
}

#resource "azurerm_subnet" "kube_pod_cidr" {

#  count                = var.count_worker

#  name                 = "${var.prefix}_pod_${count.index + 1}"
#  virtual_network_name = azurerm_virtual_network.kubetest.name
#  resource_group_name  = azurerm_resource_group.kubetest.name
#  address_prefix       = replace(var.pods_cidr, "X", count.index + 1)
#}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.kubetest.name
  virtual_network_name = azurerm_virtual_network.kubetest.name
  address_prefix       = "172.16.254.224/27"
}

resource "azurerm_public_ip" "bastion" {
  name                = "bastion_ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "worker" {
  count               = var.count_worker
  name                = "${var.prefix}-ext-worker-${count.index + 1}-ip"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "master" {
  count               = var.count_master
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

  network_security_group_id   = azurerm_network_security_group.firewall.id
  enable_ip_forwarding  = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kubetest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.master[count.index].id
    load_balancer_backend_address_pools_ids = [azurerm_lb_backend_address_pool.kubeapi_pool.id]
  }
} 

resource "azurerm_network_interface" "internal_worker" {
  count               = var.count_worker
  name                = "${var.prefix}-int-worker-${count.index + 1}-nic"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name

  network_security_group_id   = azurerm_network_security_group.firewall.id
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kubetest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker[count.index].id
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

resource "azurerm_route_table" "workers_to_pod_cidr" {
  name                          = "${var.prefix}-route-table"
  location                      = azurerm_resource_group.kubetest.location
  resource_group_name           = azurerm_resource_group.kubetest.name
}

resource "azurerm_route" "workers_to_pod_cidr" {

  count               = var.count_worker

  name                = "${var.prefix}-route-${azurerm_virtual_machine.kubeworker[count.index].name}"
  resource_group_name = azurerm_resource_group.kubetest.name
  route_table_name    = azurerm_route_table.workers_to_pod_cidr.name
  address_prefix      = replace(var.pods_cidr, "X", count.index + 1)
  next_hop_in_ip_address = azurerm_network_interface.internal_worker[count.index].private_ip_address
  next_hop_type       = "VirtualAppliance"
}

resource "azurerm_subnet_route_table_association" "workers_to_pod_cidr" {
  subnet_id      = azurerm_subnet.kubetest.id
  route_table_id = azurerm_route_table.workers_to_pod_cidr.id
}