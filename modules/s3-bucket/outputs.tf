output "buckets" {
  description = "Bucket details indexed by stable identifiers from the team YAML."
  value = {
    for id, bucket in aws_s3_bucket.this : id => {
      id                   = bucket.id
      arn                  = bucket.arn
    }
  }
  depends_on = [aws_s3_bucket_policy.this]
}
