output "backend_service_name" {
  description = "Nom del servei Backend"
  value       = kubernetes_service.backend.metadata[0].name
}

output "backend_cluster_ip" {
  description = "ClusterIP del servei Backend"
  value       = kubernetes_service.backend.spec[0].cluster_ip
}

output "postgres_service_name" {
  description = "Nom del servei Postgres"
  value       = kubernetes_service.postgres.metadata[0].name
}

output "nginx_service_name" {
  description = "Nom del servei Nginx"
  value       = kubernetes_service.nginx.metadata[0].name
}
