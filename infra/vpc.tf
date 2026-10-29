data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = var.name
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets   = ["10.0.0.0/24", "10.0.1.0/24"]
  database_subnets = ["10.0.20.0/24", "10.0.21.0/24"]

  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  enable_nat_gateway                 = false
  map_public_ip_on_launch            = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}