output "buckets" {
  description = "Bucket details indexed by the stable identifiers from the selected team's YAML."
  value       = module.buckets.buckets
}
