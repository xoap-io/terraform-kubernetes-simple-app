variable "name" {
  type        = string
  description = "Name used to identify deployed container and all related resources."
}
variable "image" {
  type        = string
  description = "Image name and tag to deploy."
}
variable "ingress_class" {
  type        = string
  description = "Class name for ingress. defaults to kong"
  default     = "kong"
}
variable "paths" {
  type        = map(any)
  description = "Object mapping local paths to container paths"
  default     = {}
}
variable "domain" {
  type        = string
  description = "Domain that should be configured to route traffic from."
}
variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources must be created."
}
variable "container_port" {
  type        = string
  description = "Container port where to send to requests to."
}
variable "service_port" {
  type        = string
  description = "Port configured on the service side to receive requests (routed to the container port)."
}
variable "ingress_annotations" {
  type        = map(string)
  description = "Annotations to be added to the ingress resource."
}
variable "service_account_annotations" {
  type        = map(string)
  description = "Annotations to be added to the service account resource."
}
variable "health_check" {
  type = object({
    path                  = string
    initial_delay_seconds = number
    timeout_seconds       = number
    success_threshold     = number
    failure_threshold     = number
    period_seconds        = number
  })
  description = "Health check configuration."
}
variable "environment_variables" {
  type        = map(any)
  description = "Map with environment variables injected to the containers."
}
variable "resource_config" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })

    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "0.5"
      memory = "512Mi"
    }
    requests = {
      cpu    = "250m"
      memory = "50Mi"
    }
  }
  description = "Object with resource limits and requests."
}
variable "hpa" {
  type = object({
    max_replicas                      = number
    min_replicas                      = number
    target_cpu_utilization_percentage = number
  })
  description = "Object with autoscaler limits and requests."

}
variable "context" {
  type = object({
    organization = string
    environment  = string
    account      = string
    product      = string
    tags         = map(string)
  })
  description = "Default environmental context"
}
