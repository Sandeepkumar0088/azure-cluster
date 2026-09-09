# resource "azurerm_kubernetes_cluster" "dev" {
#   name                = "dev"
#   location            = azurerm_resource_group.cluster.location
#   resource_group_name = azurerm_resource_group.cluster.name
#   dns_prefix          = "dev"
#
#   default_node_pool {
#     name           = "system"
#     node_count     = 1
#     vm_size        = "Standard_D2s_v6"
#     vnet_subnet_id = azurerm_subnet.aks.id
#     os_sku         = "AzureLinux3"
#   }
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

  # AKS Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_D2s_v6"
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

  vm_size      = "Standard_D2s_v6"
  # vm_size      = "Standard_D2lds_v6"
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
      sudo mv /tmp/kubernetes.repo /etc/yum.repos.d/kubernetes.repo
      sudo dnf install -y kubectl

      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    EOT
  }
}

resource "helm_release" "nginx-ingress" {

  depends_on = [
    null_resource.jenkins,
    null_resource.kubeconfig
  ]

  name  = "ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  set = [
    {
      name  = "controller.metrics.enabled"
      value = "true"
    },
    {
      name  = "controller.podAnnotations.prometheus\\.io/port"
      value = "10254"
    },
    {
      name  = "controller.podAnnotations.prometheus\\.io/scrape"
      value = "true"
    }
  ]
}

#managed identity
resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "managed-identity"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
}

# workload identity
resource "azurerm_federated_identity_credential" "external_dns" {
  name = "external-dns-federated"

  user_assigned_identity_id = azurerm_user_assigned_identity.external_dns.id

  issuer = azurerm_kubernetes_cluster.dev.oidc_issuer_url

  subject = "system:serviceaccount:${var.external_dns_namespace}:${var.external_dns_service_account}"

  audience = [
    "api://AzureADTokenExchange"
  ]
}

resource "kubernetes_service_account_v1" "external_dns" {
  metadata {
    name      = var.external_dns_service_account
    namespace = var.external_dns_namespace

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.external_dns.client_id
    }

    labels = {
      "azure.workload.identity/use" = "true"
    }
  }

  depends_on = [
    azurerm_federated_identity_credential.external_dns
  ]
}

# resource "helm_release" "external_dns" {
#   name       = "external-dns"
#   repository = "https://kubernetes-sigs.github.io/external-dns/"
#   chart      = "external-dns"
#   namespace  = var.external_dns_namespace
#
#   create_namespace = false
#
#   values = [
#     yamlencode({
#       fullnameOverride = "external-dns"
#
#       provider = {
#         name = "azure"
#       }
#
#       serviceAccount = {
#         create = false
#         name   = var.external_dns_service_account
#       }
#
#       sources = [
#         "ingress"
#       ]
#
#       domainFilters = [
#         var.dns_zone_name
#       ]
#
#       policy = "upsert-only"
#
#       registry = "txt"
#
#       txtOwnerId = "dev-external-dns"
#
#       podLabels = {
#         "azure.workload.identity/use" = "true"
#       }
#     })
#   ]
#
#   depends_on = [
#     kubernetes_service_account_v1.external_dns,
#     azurerm_federated_identity_credential.external_dns
#   ]
# }

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = var.external_dns_namespace
  create_namespace = false

  values = [
    yamlencode({
      fullnameOverride = "external-dns"

      provider = {
        name = "azure"
      }

      serviceAccount = {
        create = false
        name   = var.external_dns_service_account
      }

      sources = ["ingress"]

      domainFilters = [
        var.dns_zone_name
      ]

      policy = "upsert-only"

      registry = "txt"

      txtOwnerId = "dev-external-dns"

      podLabels = {
        "azure.workload.identity/use" = "true"
      }
    })
  ]

  depends_on = [
    kubernetes_service_account_v1.external_dns
  ]
}
