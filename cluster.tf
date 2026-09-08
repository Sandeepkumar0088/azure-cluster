resource "azurerm_kubernetes_cluster" "dev" {
  name                = "dev"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix          = "dev"

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_D4ls_v6"
    vnet_subnet_id = azurerm_subnet.aks.id
    os_sku         = "AzureLinux3"
  }
  node_provisioning_profile {
    mode = "Manual"
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

  node_count          = 1
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
    command = <<-EOT
      cat <<EOF > /tmp/kubernetes.repo
      [kubernetes]
      name=Kubernetes
      baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
      enabled=1
      gpgcheck=1
      gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
      EOF

      sudo mv /tmp/kubernetes.repo /etc/yum.repos.d/kubernetes.repo
      sudo dnf install -y kubectl

      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    EOT
  }
}
