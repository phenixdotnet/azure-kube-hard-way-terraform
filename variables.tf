variable "prefix" {
  default = "kubetest"
}

variable "location" {
  default = "West Europe"
}

variable "count_master" {
    default = 1
}

variable "count_agent" {
    default = 1
}

variable "cloud_init_file" {
  default = "cloud_init.cfg"
}