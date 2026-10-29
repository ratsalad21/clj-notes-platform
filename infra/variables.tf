variable "region" {
  type    = string
  default = "us-east-2"
}

variable "name" {
  type    = string
  default = "notes"
}

variable "github_repo" {
  type        = string
  description = "owner/repo-name of the GitHub repo"
  default     = "ratsalad21/clj-notes-platform"
}
