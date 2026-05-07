variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "backend_replicas" {
  description = "Number of backend replicas"
  type        = number
  default     = 2
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
  default     = "greendevcorp/backend:week9"
}

variable "postgres_user" {
  description = "PostgreSQL User. Required - provide via -var-file=<env>.tfvars (not committed)."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL Password. Required - provide via -var-file=<env>.tfvars (not committed)."
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "PostgreSQL Database name. Required - provide via -var-file=<env>.tfvars (not committed)."
  type        = string
  sensitive   = true
}

variable "nginx_image" {
  description = "Docker image for the Nginx service"
  type        = string
  default     = "greendevcorp/nginx:week9"
}

variable "nginx_replicas" {
  description = "Number of Nginx replicas"
  type        = number
  default     = 2
}
