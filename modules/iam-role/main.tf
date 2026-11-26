resource "aws_iam_policy" "permissions_boundary" {
  name        = "${var.role_name}-boundary"
  description = "Maximum identity-policy permissions for ${var.role_name}"
  policy      = var.permissions_boundary_policy
  tags        = var.tags
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = var.assume_role_policy
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "this" {
  for_each = var.policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}
