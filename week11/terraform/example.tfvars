# Template for environment-specific Terraform variables.
#
# Copy this file to dev.tfvars (or staging.tfvars, prod.tfvars, ...) and fill
# in real values. The actual *.tfvars files are gitignored so secrets stay out
# of version control. Only this template is committed.
#
# Usage:
#   cp example.tfvars dev.tfvars
#   # edit dev.tfvars with real values
#   terraform apply -var-file=dev.tfvars

environment      = "dev"
nginx_replicas   = 2
backend_replicas = 2

# PostgreSQL credentials - REQUIRED, no defaults provided in variables.tf
postgres_user     = "CHANGE_ME"
postgres_password = "CHANGE_ME"
postgres_db       = "CHANGE_ME"

# Optional: pin to a specific image tag built by CI (e.g. sha-a1b2c3d)
# nginx_image   = "yourdockerhubuser/nginx:main"
# backend_image = "yourdockerhubuser/backend:main"
