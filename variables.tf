variable "name" {
  type        = string
  description = "Name used to identify deployed container and all related resources."
}
variable "image" {
  type        = string
  description = "Image name and tag to deploy."
}
variable "paths" {
  type        = map(any)
  description = "Object mapping local paths to container paths"
  default     = {}
}

variable "additional_hosts" {
  type        = map(string)
  description = "Map of additional hosts to be added to the ingress."
  default     = {}
}
variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources must be created."
}
variable "ingress" {
  type = object({
    host          = string
    ingress_class = optional(string, "kong")
    annotations   = optional(map(string), {})

  })
  default = null
}
variable "service" {
  type = object({
    container_port = number
    target_port    = number
    type           = string
    https_enabled  = bool
    annotations    = optional(map(string), {})
    healthcheck = object({
      path                  = string
      initial_delay_seconds = number
      timeout_seconds       = number
      success_threshold     = number
      failure_threshold     = number
      period_seconds        = number
    })
  })
  default = null
}
variable "service_account_annotations" {
  type        = map(string)
  description = "Annotations to be added to the service account resource."
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
