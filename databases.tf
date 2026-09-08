resource "azurerm_public_ip" "pip" {
  for_each = var.vms
  name                = each.key
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "my-nsg"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name

  # Allow ALL inbound traffic
  security_rule {
    name                       = "Allow-All-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"

    source_port_range          = "*"
    destination_port_range     = "*"

    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # Allow ALL outbound traffic
  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {

  for_each = var.vms
  name                = "alma-nic-${each.key}"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aks.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  for_each = var.vms

  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {

  for_each = var.vms

  name                = each.key
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  size                = each.value

  admin_username = "sandeep"
  admin_password = "Sandeep.,@0088"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux-x86_64"
    sku       = "9-gen2"
    version   = "latest"
  }
}
data "azurerm_dns_zone" "main" {
  name = "sandeepkumarpenta.online"
  resource_group_name = "work"
}

resource "azurerm_dns_a_record" "records" {

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]

  for_each = var.vms

  name = "${each.key}-dev"
  zone_name = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl = 5
  records = [ azurerm_linux_virtual_machine.vm[each.key].private_ip_address ]
}

resource "null_resource" "ansible" {
  depends_on = [
    azurerm_linux_virtual_machine.vm,
    azurerm_dns_a_record.records
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