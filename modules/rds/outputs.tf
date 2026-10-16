output "endpoint" {
  description = "host:port"
  value       = aws_db_instance.this.endpoint
}

output "db_name" {
  value = aws_db_instance.this.db_name
}
