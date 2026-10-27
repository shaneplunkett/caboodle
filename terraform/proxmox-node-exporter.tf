resource "terraform_data" "node_exporter" {
  for_each = {
    (local.cube.name) = local.cube.ip
  }

  triggers_replace = {
    node_ip = each.value
    script  = filesha256("${path.module}/../proxmox/node-exporter.sh")
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no shane@${self.triggers_replace.node_ip} 'sudo sh -s' < ${path.module}/../proxmox/node-exporter.sh"
  }
}
