# Part of a hack for module-to-module dependencies.
# https://github.com/hashicorp/terraform/issues/1178#issuecomment-449158607
# and
# https://github.com/hashicorp/terraform/issues/1178#issuecomment-473091030
# Make sure to add this null_resource.dependency_getter to the `depends_on`
# attribute to all resource(s) that will be constructed first within this
# module:
resource "null_resource" "dependency_getter" {
  triggers = {
    my_dependencies = "${join(",", var.dependencies)}"
  }

  lifecycle {
    ignore_changes = [
      triggers["my_dependencies"],
    ]
  }
}

resource "null_resource" "zookeeper_operator" {
  triggers = {
    hash = filesha256("${path.module}/config/zk-operator.yaml")
  }

  provisioner "local-exec" {
    command = "kubectl -n ${var.kubectl_namespace} apply -f ${"${path.module}/config/zk-operator.yaml"}"
  }

  depends_on = [
    "null_resource.dependency_getter",
  ]
}

resource "helm_release" "solr_operator" {
  depends_on = ["null_resource.dependency_getter"]
  name       = "solr-operator"

  repository = var.helm_repository
  repository_username = var.helm_repository_username
  repository_password = var.helm_repository_password

  chart      = "solr-operator"
  version    = var.chart_version
  namespace  = var.helm_namespace
  timeout    = 1200

  values = [
    "${var.values}",
  ]

}

# Part of a hack for module-to-module dependencies.
# https://github.com/hashicorp/terraform/issues/1178#issuecomment-449158607
resource "null_resource" "dependency_setter" {
  # Part of a hack for module-to-module dependencies.
  # https://github.com/hashicorp/terraform/issues/1178#issuecomment-449158607
  # List resource(s) that will be constructed last within the module.
  depends_on = [
    "null_resource.zookeeper_operator",
    "helm_release.solr_operator"
  ]
}
