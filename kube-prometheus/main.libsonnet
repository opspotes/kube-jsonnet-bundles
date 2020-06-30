(import 'kube-prometheus/kube-prometheus.libsonnet') {
  namespace:: 'monitoring',
  prometheusNamespaces:: [],  // extra namespaces to discover

  _config+:: {
    namespace: $.namespace,
    versions+: {
      prometheus: 'v2.17.0',
    },
    prometheus+:: {
      namespaces+: $.prometheusNamespaces,
      replicas: 1,
    },
    alertmanager+:: {
      replicas: 1,
    },
  },

  prometheus+::: {
    // Workaround for https://github.com/grafana/tanka/issues/277
    roleSpecificNamespaces: super.roleSpecificNamespaces.items,
    roleBindingSpecificNamespaces: super.roleBindingSpecificNamespaces.items,
  },

  grafana+::: {
    // Workaround for https://github.com/grafana/tanka/issues/277
    dashboardDefinitions: super.dashboardDefinitions.items,
  },

  promOperator: std.prune($.prometheusOperator),
  promAdapter: $.prometheusAdapter,
  alertMgr: std.prune($.alertmanager),
  kubeStateM: std.prune($.kubeStateMetrics),
  nodeExp: std.prune($.nodeExporter),
}
