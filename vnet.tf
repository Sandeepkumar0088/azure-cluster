resource "azurerm_resource_group" "cluster" {
  name = "cluster"
  location = "Central India"
}
resource "azurerm_virtual_network" "vnet" {
  name                = "cluster"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "cluster"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}