resource "proxmox_cloned_vm" "debian13_clone" {
  node_name = var.virtual_environment_node_name
  name      = "debian13-clone"
  id = 9001

  clone = {
    source_vm_id = var.template_vm_id
    full         = true
  }

  network = {
    net0 = {
      bridge = "vmbr1"
      model  = "virtio"
      tag = var.clients_vlan_tag
    }
  }

  memory = {
    size    = 2048
    balloon = 512
  }

  cpu = {
    cores = 2
  }
}

output "vm_id" {
  value = proxmox_cloned_vm.debian13_clone.id
}
