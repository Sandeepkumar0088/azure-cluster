variable "vms" {
  default = {
    mongodb     = "Standard_B2ats_v2"
    redis       = "Standard_B2ats_v2"
    mysql       = "Standard_D4ls_v6"
    rabbitmq    = "Standard_B2ats_v2"
  }
}

variable "admin_password" {
  default = "Sandeep.,@0088"
}


variable "aks_name" {
type    = string
default = "dev"
}

variable "aks_resource_group" {
type    = string
default = "cluster"
}

variable "dns_resource_group" {
type    = string
default = "work"
}

variable "dns_zone_name" {
type    = string
default = "sandeepkumarpenta.online"
}

variable "external_dns_namespace" {
type    = string
default = "default"
}

variable "external_dns_service_account" {
type    = string
default = "external-dns"
}

variable "external_dns_identity_name" {
type    = string
default = "external-dns-identity"
}

variable "external_dns_hostname" {
type    = string
default = "frontend-dev.sandeepkumarpenta.online"
}
