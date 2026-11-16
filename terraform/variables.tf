variable "virtual_environment_node_name" {
    type = string
    description = "Target proxmox node"
    default = "pve1"
}

variable "template_vm_id" {
    type = number
    description = "ID of the cloud-init template hand crafted in previous chapter"
}

variable "clients_vlan_tag" {
    type = number
    description = "VLAN tag number where clients live"
    default = 20
}

