module "vpc" {

  source = "./modules/vpc"

  vpc_cidr              = var.vpc_cidr

  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr

  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr

  az_1 = var.az_1
  az_2 = var.az_2

}


module "eks" {

  source = "./modules/eks"

  vpc_cidr = module.vpc.vpc_cidr
  
  vpc_id = module.vpc.vpc_id

  cluster_name = var.cluster_name

  private_subnet_1_id = module.vpc.private_subnet_1_id

  private_subnet_2_id = module.vpc.private_subnet_2_id


}
