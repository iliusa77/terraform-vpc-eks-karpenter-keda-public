resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.8.2"
  namespace        = "keda"
  create_namespace = true

  set {
    name  = "serviceAccount.operator.annotations.eks.amazonaws.com/role-arn"
    value = aws_iam_role.keda-operator.arn
  }
}

### KEDA ScaleObject
data "kubectl_path_documents" "keda_scaledobject" {
  pattern = "./templates/keda_scaledobject.yaml"
  vars = {
  }
}

resource "kubectl_manifest" "keda_scaledobject" {
  for_each  = toset(data.kubectl_path_documents.keda_scaledobject.documents)
  yaml_body = each.value
}

### Nginx Deployment
data "kubectl_path_documents" "nginx_deployment" {
  pattern = "./templates/nginx_deployment.yaml"
  vars = {
  }
}

resource "kubectl_manifest" "nginx_deployment" {
  for_each  = toset(data.kubectl_path_documents.nginx_deployment.documents)
  yaml_body = each.value
}