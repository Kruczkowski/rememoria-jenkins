terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.1"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  tenant_id   = var.tenant_id
  user_name   = var.user_name
  password    = var.password
  region      = var.region
}

data "openstack_images_image_v2" "ubuntu_lts" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = var.keypair_name
  public_key = var.public_key
}

resource "openstack_compute_instance_v2" "instance" {
  name            = var.instance_name
  flavor_name     = var.flavor
  image_id        = data.openstack_images_image_v2.ubuntu_lts.id
  key_pair        = openstack_compute_keypair_v2.keypair.name
  region          = var.region
  user_data       = file("${path.module}/user_data.sh")

  network {
    name = "Ext-Net"
  }

  metadata = {
    billing = "hourly"
  }
}
