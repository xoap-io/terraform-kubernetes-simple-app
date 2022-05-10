output "namespace" {
  value       = var.namespace
  description = "The namespace where the resources will be created"
}
output "name" {
  value       = var.name
  description = "The name of the resources"
}
output "service" {
  value = kubernetes_service.this
}
output "ingress" {
  value = kubernetes_ingress_v1.this
}
output "deployment" {
  value = kubernetes_deployment.this
}
output "service_account" {
  value = kubernetes_service_account.this
}
