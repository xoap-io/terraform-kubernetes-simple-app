locals {
  labels = merge(var.context.tags, {
    "managed-by" = "terraform"
  })
}
resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = merge(local.labels, {
      k8s-app = var.name
    })
    annotations = var.service_account_annotations

  }
  automount_service_account_token = true
}
resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = merge(local.labels, {
      k8s-app = var.name
    })
  }
  spec {
    replicas = 2
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
    }
    selector {
      match_labels = {
        k8s-app = var.name
      }
    }
    template {
      metadata {
        labels = {
          k8s-app = var.name
        }
      }
      spec {
        service_account_name = join("", kubernetes_service_account.this.metadata[*].name)
        dynamic "volume" {
          for_each = var.paths
          content {
            name = "${var.name}-data-${replace(volume.key, "/", "-")}"
            host_path {
              path = volume.key
            }
          }
        }
        container {
          image = var.image
          name  = var.name
          security_context {
            capabilities {
              drop = ["NET_RAW"]
            }
          }
          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "port" {
            for_each = var.service != null ? toset(["1"]) : toset([])
            content {
              container_port = var.service.container_port
              name           = var.service.https_enabled ? "https" : "http"
              protocol       = "TCP"

            }
          }
          dynamic "liveness_probe" {
            for_each = var.service != null ? toset(["1"]) : toset([])
            content {
              http_get {
                path   = var.service.healthcheck.path
                port   = var.service.container_port
                scheme = var.service.https_enabled ? "HTTPS" : "HTTP"
              }
              initial_delay_seconds = var.service.healthcheck.initial_delay_seconds
              timeout_seconds       = var.service.healthcheck.timeout_seconds
              success_threshold     = var.service.healthcheck.success_threshold
              failure_threshold     = var.service.healthcheck.failure_threshold
              period_seconds        = var.service.healthcheck.period_seconds
            }

          }
          dynamic "readiness_probe" {
            for_each = var.service != null ? toset(["1"]) : toset([])
            content {
              http_get {
                path   = var.service.healthcheck.path
                port   = var.service.container_port
                scheme = var.service.https_enabled ? "HTTPS" : "HTTP"
              }
              failure_threshold = 12
              success_threshold = 1
              period_seconds    = 10

            }

          }
          resources {
            limits   = var.resource_config.limits
            requests = var.resource_config.requests
          }
          dynamic "volume_mount" {
            for_each = var.paths
            content {
              name       = "${var.name}-data-${replace(volume_mount.key, "/", "-")}"
              mount_path = volume_mount.value
            }
          }
        }
      }

    }
  }
  lifecycle {
    ignore_changes = [
      spec[0].replicas,
      metadata[0].annotations["field.cattle.io/publicEndpoints"],
      metadata[0].annotations["cattle.io/status"],
      metadata[0].annotations["lifecycle.cattle.io/create.namespace-auth"]

    ]
  }
}

resource "kubernetes_service" "this" {
  count = var.service != null ? 1 : 0
  metadata {
    name        = var.name
    namespace   = var.namespace
    labels      = local.labels
    annotations = var.service.annotations
  }
  spec {
    selector = {
      k8s-app = kubernetes_deployment.this.metadata[0].labels.k8s-app
    }
    port {
      name        = var.service.https_enabled ? "https" : "http"
      port        = var.service.target_port
      target_port = var.service.https_enabled ? "https" : "http"
    }

    type = var.service.type
  }
}
resource "kubernetes_ingress_v1" "this" {
  count                  = var.ingress != null ? 1 : 0
  wait_for_load_balancer = true
  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.ingress.annotations
    labels      = local.labels
  }
  spec {
    ingress_class_name = var.ingress.ingress_class
    rule {
      host = var.ingress.host
      http {
        path {
          path = "/"

          backend {
            service {
              name = kubernetes_service.this[0].metadata[0].name
              port {
                number = var.service.target_port
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.additional_hosts
      content {
        host = rule.key
        http {
          path {
            path = rule.value

            backend {
              service {
                name = kubernetes_service.this[0].metadata[0].name
                port {
                  number = var.service.target_port
                }
              }
            }
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations["field.cattle.io/publicEndpoints"],
      metadata[0].annotations["cattle.io/status"],
      metadata[0].annotations["lifecycle.cattle.io/create.namespace-auth"],
    ]
  }
}
resource "kubernetes_horizontal_pod_autoscaler" "this" {
  metadata {
    name      = "hpa-${var.name}"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    max_replicas                      = var.hpa.max_replicas
    min_replicas                      = var.hpa.min_replicas
    target_cpu_utilization_percentage = var.hpa.target_cpu_utilization_percentage
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.this.metadata[0].name
    }

  }
}
resource "kubernetes_pod_disruption_budget" "this" {
  metadata {
    name      = "pdb-${var.name}"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    min_available = "50%"
    selector {
      match_labels = {
        k8s-app = kubernetes_deployment.this.metadata[0].labels.k8s-app
      }
    }
  }
}
