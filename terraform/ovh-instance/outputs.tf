output "instance_id" {
  description = "ID utworzonej instancji"
  value       = openstack_compute_instance_v2.instance.id
}

output "instance_ip" {
  description = "Publiczny adres IP instancji"
  value       = openstack_compute_instance_v2.instance.access_ip_v4
}

output "instance_name" {
  description = "Nazwa instancji"
  value       = openstack_compute_instance_v2.instance.name
}
