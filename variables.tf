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

variable "subnet_bits" {
  default = "24"
}

variable "count_master" {
    default = 3
}

variable "count_worker" {
    default = 1
}

