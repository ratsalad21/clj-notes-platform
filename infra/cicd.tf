resource "aws_codestarconnections_connection" "github" {
  name          = "${var.name}-github"
  provider_type = "GitHub"
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codestarconnections_connection.github.arn
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "codebuild" {
  name = "${var.name}-codebuild-runner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name}-runner*"
      },
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage",
          "ecr:DescribeImages", "ecr:DescribeImageScanFindings"
        ]
        Resource = aws_ecr_repository.notes.arn
      },
      {
        Sid      = "EksDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = module.eks.cluster_arn
      },
      {
        Sid    = "UseGithubConnection"
        Effect = "Allow"
        Action = [
          "codeconnections:GetConnectionToken", "codeconnections:GetConnection",
          "codestar-connections:GetConnectionToken", "codestar-connections:GetConnection",
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

resource "aws_eks_access_entry" "codebuild" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.codebuild.arn
}

resource "aws_eks_access_policy_association" "codebuild" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.codebuild.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }
}

resource "aws_codebuild_project" "runner" {
  name         = "${var.name}-runner"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type            = "LINUX_CONTAINER"
    image           = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    compute_type    = "BUILD_GENERAL1_SMALL"
    privileged_mode = true
  }

  source {
    type     = "GITHUB"
    location = "https://github.com/${var.github_repo}.git"
  }

  depends_on = [aws_codebuild_source_credential.github]
}

resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}