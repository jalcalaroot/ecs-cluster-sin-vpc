#ingresar credenciales
variable "access_key" {}
variable "secret_key" {}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
}

variable "ecs_cluster" {
  type        = "string"
  description = "indicar el nombre del cluster"
}


variable "vpc_id" {
  type        = "string"
  description = "indicar el id de la vpc"
}

variable "subnet_1" {
  type        = "string"
  description = "subnet_1 para el balanceador de carga"
}

variable "subnet_2" {
  type        = "string"
  description = "subnet_2 para el balanceador de carga"
}

variable "subnet_3" {
  type        = "string"
  description = "subnet_3 para el balanceador de carga"
}

variable "subnet_4" {
  type        = "string"
  description = "subnet_4 para el cluster ecs"
}

variable "subnet_5" {
  type        = "string"
  description = "subnet_5 para el cluster ecs"
}

variable "subnet_6" {
  type        = "string"
  description = "subnet_6 para el cluster ecs"
}

variable "min_instance_size" {
  description = "Minimum number of instances in the cluster"
}

variable "desired_capacity" {
  description = "Desired number of instances in the cluster"
}

variable "max_instance_size" {
  description = "Maximum number of instances in the cluster"
}

variable "instance_type" {
  type        = "string"
  description = "instance_type para el cluster ecs"
}

