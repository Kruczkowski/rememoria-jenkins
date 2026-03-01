variable "auth_url" {
  description = "OVH OpenStack auth URL"
  default     = "https://auth.cloud.ovh.net/v3"
}

variable "tenant_id" {
  description = "OVH Project ID (OS_TENANT_ID)"
}

variable "user_name" {
  description = "OVH OpenStack username"
}

variable "password" {
  description = "OVH OpenStack password"
  sensitive   = true
}

variable "region" {
  description = "OVH region"
  default     = "WAW1"
}

variable "flavor" {
  description = "Instance flavor"
  default     = "d2-4"
}

variable "image_name" {
  description = "Ubuntu LTS image name"
  default     = "Ubuntu 24.04"
}

variable "keypair_name" {
  description = "Nazwa klucza SSH zaimportowanego w OVH"
  default     = "rememotion-key"
}

variable "public_key" {
  description = "Zawartość klucza publicznego SSH do importu w OVH"
  sensitive   = true
}

variable "instance_name" {
  description = "Nazwa instancji"
  default     = "rememotion-instance"
}
