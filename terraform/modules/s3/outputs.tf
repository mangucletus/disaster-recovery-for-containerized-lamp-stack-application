output "assets_bucket_id" {
  value       = aws_s3_bucket.assets.id
  description = "ID of the assets bucket"
}

output "assets_bucket_arn" {
  value       = aws_s3_bucket.assets.arn
  description = "ARN of the assets bucket"
}

output "backups_bucket_id" {
  value       = aws_s3_bucket.backups.id
  description = "ID of the backups bucket"
}

output "backups_bucket_arn" {
  value       = aws_s3_bucket.backups.arn
  description = "ARN of the backups bucket"
}