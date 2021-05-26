provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "rebrain_key" {
    name = var.key_name
}

resource "digitalocean_ssh_key" "my_key" {
  name = "my key"
  public_key = file("${path.module}/${var.pub_key_path}")
}

resource "digitalocean_droplet" "do_vps" {
  count = length(var.devs)
  image = var.do_server_image
  name = "${element(var.devs, count.index)}"
  region = var.do_server_region
  size = var.do_server_size
  ssh_keys = [ data.digitalocean_ssh_key.rebrain_key.id, digitalocean_ssh_key.my_key.fingerprint ]
  tags = [ var.do_module_tag, var.do_email_tag ]

}

data "digitalocean_droplet" "do_server" {
  count = length(var.devs)
  name = digitalocean_droplet.do_vps[count.index].name
} 

resource "local_file" "ansible_inventory" {
  content = "${templatefile("${path.module}/ansible_inventory.tpl", {
    name = var.devs
    ip_adr = local.do_ip_adress
    }
  )}"
  filename = "${path.module}/ansible/inventory"
}

resource "null_resource" "do_vps" {
    depends_on = [
      local_file.ansible_inventory,
  ]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i ${path.module}/ansible/inventory ${path.module}/ansible/webserver.yml"
  }
}
