# resource "azurerm_kubernetes_cluster" "dev" {
#   name                = "dev"
#   location            = azurerm_resource_group.cluster.location
#   resource_group_name = azurerm_resource_group.cluster.name
#   dns_prefix          = "dev"
#
#   default_node_pool {
#     name           = "system"
#     node_count     = 4
#     vm_size        = "Standard_D4ls_v6"
#     vnet_subnet_id = azurerm_subnet.aks.id
#     os_sku         = "AzureLinux3"
#   }
#
#   node_provisioning_profile {
#     mode = "Manual"
#   }
#
#   identity {
#     type = "SystemAssigned"
#   }
#
#   network_profile {
#     network_plugin = "azure"
#
#     service_cidr   = "10.10.0.0/16"
#     dns_service_ip = "10.10.0.10"
#   }
# }

resource "azurerm_kubernetes_cluster" "dev" {
  name                = "dev"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix          = "dev"

  default_node_pool {
    name           = "system"
    node_count     = 2
    vm_size        = "Standard_D4ls_v6"
    vnet_subnet_id = azurerm_subnet.aks.id
    os_sku         = "AzureLinux3"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"

    service_cidr   = "10.10.0.0/16"
    dns_service_ip = "10.10.0.10"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "main" {
  name                  = "main"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dev.id

  vm_size      = "Standard_D4ls_v6"
  vnet_subnet_id = azurerm_subnet.aks.id

  node_count          = 2
  min_count           = 1
  max_count           = 10
  auto_scaling_enabled = true

  mode = "User"

  os_sku = "AzureLinux3"

  tags = {
    Name = "NODE"
  }
}

resource "null_resource" "kubeconfig" {

  depends_on = [
    azurerm_kubernetes_cluster.dev,
    azurerm_kubernetes_cluster_node_pool.main
  ]

  triggers = {
    cluster = timestamp()
  }

  provisioner "local-exec" {
    command = "rm -rf ~/.kube ; az aks get-credentials --resource-group cluster --name dev ; kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  }
}

resource "null_resource" "ansible" {
  depends_on = [
    azurerm_kubernetes_cluster.dev,
    azurerm_kubernetes_cluster_node_pool.main
  ]
  for_each   = var.vms

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "sandeep"
      password = "Sandeep.,@0088"
      host     = azurerm_linux_virtual_machine.vm[each.key].public_ip_address
      timeout  = "2m"
    }

    inline = [
      "echo 'sandeep' > ~/vault-pass.txt",
      "chmod 600 ~/vault-pass.txt",
      "sudo dnf install -y ansible-core npm unzip git",
      "ansible-pull -i localhost, -U https://github.com/Sandeepkumar0088/azure-ansible.git main.yml -e component=each.key -e env=dev --vault-password-file ~/vault-pass.txt"
    ]
  }
}