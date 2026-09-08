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