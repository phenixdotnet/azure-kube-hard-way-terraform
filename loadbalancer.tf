
resource "azurerm_lb" "kubeapi" {
  name                = "${var.prefix}-kubeapi-lb"
  location            = azurerm_resource_group.kubetest.location
  resource_group_name = azurerm_resource_group.kubetest.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PrivateIPAddress"
    subnet_id = azurerm_subnet.kubetest.id
  }
}

resource "azurerm_lb_backend_address_pool" "kubeapi_pool" {
  resource_group_name = azurerm_resource_group.kubetest.name
  loadbalancer_id     = azurerm_lb.kubeapi.id
  name                = "KubeAPIPool"
}

resource "azurerm_lb_probe" "kubeapi_probe" {
  resource_group_name = azurerm_resource_group.kubetest.name
  loadbalancer_id     = azurerm_lb.kubeapi.id
  name                = "kubeapi-healthz"
  port                = 6443
  protocol            = "https"
  request_path        = "healthz"
}

resource "azurerm_lb_rule" "kubeapi" {
  resource_group_name            = azurerm_resource_group.kubetest.name
  loadbalancer_id                = azurerm_lb.kubeapi.id
  name                           = "kubeapi"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "PrivateIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.kubeapi_pool.id
  probe_id                       = azurerm_lb_probe.kubeapi_probe.id
}