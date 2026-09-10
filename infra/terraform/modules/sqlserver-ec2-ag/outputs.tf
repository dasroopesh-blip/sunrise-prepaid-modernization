# modules/sqlserver-ec2-ag/outputs.tf

output "node_instance_ids" {
  description = "EC2 instance ids of the Always On AG nodes."
  value       = [for i in aws_instance.node : i.id]
}

output "node_private_ips" {
  description = "Private IPs of the AG nodes (node 0 is initial primary)."
  value       = [for i in aws_instance.node : i.private_ip]
}

output "listener_hint" {
  description = "Reminder: point the app at the AG LISTENER, not a node IP."
  value       = "Configure the Always On AG Listener DNS/IP after cluster setup; apps connect to the listener for automatic failover."
}
