resource "helm_release" "kube_ops_view" {
  name             = "kube-ops-view"
  repository       = "https://charts.christianhuth.de"
  chart            = "kube-ops-view"
  namespace        = "kube-ops-view"
  create_namespace = true
}