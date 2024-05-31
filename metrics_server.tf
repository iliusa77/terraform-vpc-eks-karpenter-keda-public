### Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "6.13.1"
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "apiService.create"
    value = "true"
  }
}