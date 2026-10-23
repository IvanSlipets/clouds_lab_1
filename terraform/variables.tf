variable "aws_region" {
  description = "AWS region for the entire lab"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Resource prefix (short lower-case letters, numbers and hyphens)"
  type        = string
  default     = "clouds-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,17}[a-z0-9]$", var.project_name))
    error_message = "Use 3-19 lower-case letters, digits and hyphens; start with a letter and end with a letter/digit."
  }
}

variable "database_name" {
  type    = string
  default = "nutrition"
}

variable "db_username" {
  type    = string
  default = "nutrition_user"
}

variable "db_instance_class" {
  description = "Check the availability and pricing for your selected region"
  type        = string
  default     = "db.t3.micro"
}

variable "image_tag" {
  description = "Initial image tag pushed from Docker during first apply"
  type        = string
  default     = "bootstrap"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
}

variable "create_budget" {
  description = "Enable only if you need another AWS Budget; an account budget already exists"
  type        = bool
  default     = false
}

variable "monthly_budget_usd" {
  type    = number
  default = 15
}

variable "github_repository" {
  description = "GitHub repository in OWNER/REPO format"
  type        = string
}

variable "github_oidc_subject" {
  description = "repo:IvanSlipets@183843418/clouds_lab_1@1429441518:ref:refs/heads/main"
  type        = string
}