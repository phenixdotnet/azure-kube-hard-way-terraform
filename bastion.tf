resource "azurerm_bastion_host" "bastion" {
  name                = "kubebastion"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}