output "backend_service_name" {
  description = "The name of the Backend service"
  value       = kubernetes_service.backend.metadata[0].name
}

output "backend_cluster_ip" {
  description = "The ClusterIP of the Backend service"
  value       = kubernetes_service.backend.spec[0].cluster_ip
}

output "postgres_service_name" {
  description = "The name of the Postgres service"
  value       = kubernetes_service.postgres.metadata[0].name
}
