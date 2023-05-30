// Outputs
// This will output the public IP of the web server
output "web_public_ip" {
  description = "The public IP address of the web server"
  // We are grabbing it from the Elastic IP
  value       = aws_eip.cred_card_web_eip[0].public_ip

  // This output waits for the Elastic IPs to be created and distributed
  depends_on = [aws_eip.cred_card_web_eip]
}

// This will output the the public DNS address of the web server
output "web_public_dns" {
  description = "The public DNS address of the web server"
  // We are grabbing it from the Elastic IP
  value       = aws_eip.cred_card_web_eip[0].public_dns

  depends_on = [aws_eip.cred_card_web_eip]
}

// This will output the database endpoint
output "database_endpoint" {
  description = "The endpoint of the database"
  value       = aws_db_instance.cred_card_database.address
}

// This will output the database port
output "database_port" {
  description = "The port of the database"
  value       = aws_db_instance.cred_card_database.port
}

// Bastion Connection
output "bastion_connection" {
  description = "String to Bastion/Jump Box Connection"
  value       = "ssh -i cred_card_kp.pem ubuntu@${aws_eip.cred_card_web_eip[0].public_dns}"
}

// RDS Connection
output "rds_connection" {
  description = "String to RDS Connection - Postgres"
  value       = "ssh -i cred_card_kp.pem -f -N -L 5432:${aws_db_instance.cred_card_database.address}:5432 ubuntu@${aws_eip.cred_card_web_eip[0].public_dns}"
}