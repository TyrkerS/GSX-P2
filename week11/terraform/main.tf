terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# --- Nginx ---
resource "kubernetes_service" "nginx" {
  metadata {
    name   = "nginx-${var.environment}"
    labels = {
      app         = "nginx"
      environment = var.environment
    }
  }
  spec {
    selector = {
      app         = "nginx"
      environment = var.environment
    }
    port {
      port        = 80
      target_port = 8080
      node_port   = 30080
    }
    type = "NodePort"
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name   = "nginx-${var.environment}"
    labels = {
      app         = "nginx"
      environment = var.environment
    }
  }
  spec {
    replicas = var.nginx_replicas
    selector {
      match_labels = {
        app         = "nginx"
        environment = var.environment
      }
    }
    template {
      metadata {
        labels = {
          app         = "nginx"
          environment = var.environment
        }
      }
      spec {
        container {
          name              = "nginx"
          image             = var.nginx_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }
        }
      }
    }
  }
}

# --- ConfigMap & Secret ---
resource "kubernetes_config_map" "backend_config" {
  metadata {
    name   = "backend-config-${var.environment}"
    labels = {
      app         = "backend"
      environment = var.environment
    }
  }
  data = {
    PORT = "3000"
  }
}

resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name   = "postgres-secret-${var.environment}"
    labels = {
      app         = "postgres"
      environment = var.environment
    }
  }
  type = "Opaque"
  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_db
  }
}

# --- Services ---
resource "kubernetes_service" "backend" {
  metadata {
    name   = "backend-${var.environment}"
    labels = {
      app         = "backend"
      environment = var.environment
    }
  }
  spec {
    selector = {
      app         = "backend"
      environment = var.environment
    }
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name   = "postgres-${var.environment}"
    labels = {
      app         = "postgres"
      environment = var.environment
    }
  }
  spec {
    selector = {
      app         = "postgres"
      environment = var.environment
    }
    port {
      name        = "postgresql"
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

# --- Deployment & StatefulSet ---
resource "kubernetes_deployment" "backend" {
  metadata {
    name   = "backend-${var.environment}"
    labels = {
      app         = "backend"
      environment = var.environment
    }
  }
  spec {
    replicas = var.backend_replicas
    selector {
      match_labels = {
        app         = "backend"
        environment = var.environment
      }
    }
    template {
      metadata {
        labels = {
          app         = "backend"
          environment = var.environment
        }
      }
      spec {
        container {
          name              = "backend"
          image             = var.backend_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 3000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.backend_config.metadata[0].name
            }
          }

          env {
            name  = "PGHOST"
            value = kubernetes_service.postgres.metadata[0].name
          }
          env {
            name  = "PGPORT"
            value = "5432"
          }
          env {
            name = "PGUSER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "PGDATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["wget", "-q", "-O", "-", "http://localhost:3000/health"]
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }
          readiness_probe {
            exec {
              command = ["wget", "-q", "-O", "-", "http://localhost:3000/health"]
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }
        }
      }
    }
  }
}

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name   = "postgres-${var.environment}"
    labels = {
      app         = "postgres"
      environment = var.environment
    }
  }
  spec {
    service_name = kubernetes_service.postgres.metadata[0].name
    replicas     = 1
    selector {
      match_labels = {
        app         = "postgres"
        environment = var.environment
      }
    }
    template {
      metadata {
        labels = {
          app         = "postgres"
          environment = var.environment
        }
      }
      spec {
        container {
          name              = "postgres"
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres_secret.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user]
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "postgres-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
