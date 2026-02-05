output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate.arn
}

output "state_bucket_region" {
  description = "Region where the state bucket is located"
  value       = aws_s3_bucket.tfstate.region
}

output "state_lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "state_lock_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.tfstate_lock.arn
}

output "logs_bucket_name" {
  description = "Name of the S3 bucket for state access logs"
  value       = aws_s3_bucket.tfstate_logs.id
}

output "kms_key_id" {
  description = "ID of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.tfstate[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.tfstate[0].arn : null
}

output "backend_config" {
  description = "Backend configuration block for use in other Terraform configurations"
  value = {
    bucket         = aws_s3_bucket.tfstate.id
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.tfstate_lock.name
    encrypt        = true
  }
}

output "backend_config_snippet" {
  description = "Ready-to-use backend configuration snippet (copy to your terraform block)"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.id}"
      key            = "ENV/terraform.tfstate"  # Replace ENV with dev/prod
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.tfstate_lock.name}"
      encrypt        = true
    }
  EOT
}
