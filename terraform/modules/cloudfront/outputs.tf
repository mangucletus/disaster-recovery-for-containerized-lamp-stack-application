# Output the CloudFront URL
output "cloudfront_url" {
  value       = aws_cloudfront_distribution.failover.domain_name
  description = "CloudFront distribution URL with automatic failover"
}