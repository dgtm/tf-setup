locals {
  team        = "beta"
  config_file = abspath("${path.module}/../../configuration/${local.team}.yml")
  config      = yamldecode(file(local.config_file))
}

provider "aws" {
  region = local.config.aws_region
}

module "buckets" {
  source = "../../modules/s3-bucket"

  config_file = local.config_file
}
