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
        service_account_name = join("", kubernetes_service_account.this.metadata.*.name)
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
          port {
            container_port = var.container_port
            name           = "http"
            protocol       = "TCP"
          }
          liveness_probe {
            http_get {
              path = var.health_check.path
              port = var.container_port
            }
            initial_delay_seconds = var.health_check.initial_delay_seconds
            timeout_seconds       = var.health_check.timeout_seconds
            success_threshold     = var.health_check.success_threshold
            failure_threshold     = var.health_check.failure_threshold
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
}
resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    selector = {
      k8s-app = kubernetes_deployment.this.metadata[0].labels.k8s-app
    }
    port {
      name        = "http"
      port        = var.service_port
      target_port = "http"
    }

    type = "ClusterIP"
  }
}
resource "kubernetes_ingress_v1" "this" {
  wait_for_load_balancer = true
  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.ingress_annotations
    labels      = local.labels
  }
  spec {
    tls {
      hosts       = [var.domain]
      secret_name = "cert-${var.name}"
    }
    rule {
      host = var.domain
      http {
        path {
          path = "/"

          backend {
            service {
              name = kubernetes_service.this.metadata.0.name
              port {
                number = var.container_port
              }
            }
          }
        }
      }
    }
  }
}
