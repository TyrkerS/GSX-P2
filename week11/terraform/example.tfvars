# Plantilla de variables Terraform específiques per entorn.
#
# Copiar aquest fitxer a dev.tfvars (o staging.tfvars, prod.tfvars, ...) i
# omplir amb els valors reals. Els fitxers *.tfvars reals estan gitignorats
# perquè els secrets no acabin al control de versions. Només aquesta plantilla
# es commita.
#
# Ús:
#   cp example.tfvars dev.tfvars
#   # editar dev.tfvars amb els valors reals
#   terraform apply -var-file=dev.tfvars

environment      = "dev"
nginx_replicas   = 2
backend_replicas = 2

# Credencials de PostgreSQL - OBLIGATÒRIES, sense valors per defecte a variables.tf
postgres_user     = "CHANGE_ME"
postgres_password = "CHANGE_ME"
postgres_db       = "CHANGE_ME"

# Opcional: fixar un tag d'imatge específic construït pel CI (p.ex. sha-a1b2c3d)
# nginx_image   = "yourdockerhubuser/nginx:main"
# backend_image = "yourdockerhubuser/backend:main"
