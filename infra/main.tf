terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "kubeflow-mlops-tfstate-891713918387-dev" # replace with your bucket
    key            = "kubeflow/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kubeflow-mlops-tf-lock-dev" # replace with your table
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Kubernetes Provider ---
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# --- VPC ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "${var.cluster_name}-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# --- EKS cluster ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["m5.large"]
    }
  }

  enable_irsa                    = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # 👇 Manage access (new way in v20+)
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    dewasheesh-admin = {
      principal_arn = "arn:aws:iam::891713918387:user/dewasheesh-admin"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = []
          }
        }
      }
    }
  }
}

resource "null_resource" "kubeflow_pipelines" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl apply -k ${path.module}/../kubeflow/kfp-manifests/cluster-scoped-resources
      kubectl wait --for=condition=Established crd/applications.app.k8s.io --timeout=60s
      kubectl apply -k ${path.module}/../kubeflow/kfp-manifests/env/platform-agnostic
    EOT
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_config_map" "pipeline_install_config" {
  metadata {
    name      = "pipeline-install-config"
    namespace = "kubeflow"
  }

  data = {
    ARTIFACT_BUCKET  = "kubeflow-prod-artifacts"
    ARTIFACT_ENDPOINT = "s3.amazonaws.com"

    dbHost     = aws_db_instance.kfp_rds.address
    dbPort     = "3306"
    dbType     = "mysql"
    pipelineDb = "mlpipeline"
  }
}

# Create a DB subnet group from private subnets
resource "aws_db_subnet_group" "kfp" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "kfp_rds" {
  identifier        = "kubeflow-pipelines-db"
  engine            = "mysql"
  instance_class    = "db.t3.medium"
  allocated_storage = 20
  username          = "admin"
  password          = "SuperSecurePassword123" # (move to AWS Secrets Manager in prod)
  db_name           = "mlpipeline"
  skip_final_snapshot = true

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.kfp.name
  publicly_accessible    = false
}
# --- IAM Policy for Kubeflow Pipelines to use S3 ---
resource "aws_iam_policy" "kubeflow_s3_policy" {
  name        = "KubeflowArtifactsS3Policy"
  description = "Allow Kubeflow Pipelines to store artifacts in S3"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${aws_s3_bucket.artifacts.bucket}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${aws_s3_bucket.artifacts.bucket}/*"
      }
    ]
  })
}

# --- IRSA role for ml-pipeline service account ---
module "ml_pipeline_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "kubeflow-ml-pipeline-s3"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kubeflow:ml-pipeline"]
    }
  }
}

# --- Attach the custom S3 policy to the IRSA role ---
resource "aws_iam_role_policy_attachment" "kubeflow_s3_attach" {
  role       = module.ml_pipeline_irsa.iam_role_name
  policy_arn = aws_iam_policy.kubeflow_s3_policy.arn
}
# --- S3 buckets ---
resource "aws_s3_bucket" "datasets" {
  bucket        = "${var.cluster_name}-datasets"
  force_destroy = true
}

resource "aws_s3_bucket" "models" {
  bucket        = "${var.cluster_name}-models"
  force_destroy = true
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.cluster_name}-artifacts"
  force_destroy = true
}

# --- ECR repos ---
resource "aws_ecr_repository" "components" {
  for_each = toset(["ingest", "preprocess", "train", "evaluate", "deploy", "drift-check"])
  name     = "${var.cluster_name}-${each.key}"
}