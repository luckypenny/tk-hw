variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "ap-northeast-2"
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/terraform.pub
DESCRIPTION
  default = "ssh_key/id_tk_web.pub"
}

variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "id_tk_web"
}