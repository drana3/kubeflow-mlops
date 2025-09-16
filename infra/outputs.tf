output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "s3_datasets" {
  value = aws_s3_bucket.datasets.bucket
}

output "s3_models" {
  value = aws_s3_bucket.models.bucket
}

output "s3_artifacts" {
  value = aws_s3_bucket.artifacts.bucket
}
