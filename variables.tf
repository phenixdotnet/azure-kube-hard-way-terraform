variable "prefix" {
  default = "kubetest"
}

variable "location" {
  default = "West Europe"
}

variable "cloud_init_file_master" {
  default = "cloud_init_master.cfg"
}

variable "cloud_init_file_worker" {
  default = "cloud_init_worker.cfg"
}

variable "cluster_name" {
  default = "phenix"
}

variable "network_address_range" {
  default = "172.16.0.0/16"
}

variable "vms_cidr" {
  default = "172.16.0.0/24"
}

variable "cluster_cidr" {
  default = "172.17.0.0/16"
}

variable "cluster_service_cidr" {
  default = "10.32.0.0/24"
}

variable "pods_cidr" {
  default = "172.17.X.0/24"
}

variable "count_master" {
    default = 3
}

variable "count_worker" {
    default = 2
}

