local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'alb-ingress-controller',
  namespace:: 'kube-system',
  containerImage:: 'docker.io/amazon/aws-alb-ingress-controller',
  containerImageTag:: 'v1.1.6',
  enableMonitoring:: true,
  ingressClass:: 'alb',
  clusterName:: error 'clusterName required',
  iamRoleArn:: error 'iamRoleArn required',

  metadata_:: {
    namespace: $.namespace,
    labels: k.labels($.name, 'ingress'),
  },

  local serviceAccount_ = k.ServiceAccount($.name) {
    metadata+: $.metadata_,
  } + k.irsaAnnotation($.iamRoleArn),

  local clusterRole_ = k.ClusterRole($.name) {
    metadata+: $.metadata_ {
      namespace: null,
    },
    rules: [
      {
        apiGroups: ['', 'extensions'],
        resources: ['configmaps', 'endpoints', 'events', 'ingresses', 'ingresses/status', 'services', 'pods/status'],
        verbs: ['create', 'get', 'list', 'update', 'watch', 'patch'],
      },
      {
        apiGroups: ['', 'extensions'],
        resources: ['nodes', 'pods', 'secrets', 'namespaces'],
        verbs: ['get', 'list', 'watch'],
      },
    ],
  },

  local clusterRoleBinding_ = k.ClusterRoleBinding($.name) {
    metadata+: $.metadata_ {
      namespace: null,
    },
    subjects_: [
      serviceAccount_,
    ],
    roleRef_: clusterRole_,
  },

  local deployment_ = k.Deployment($.name) {
    metadata+: $.metadata_,
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: serviceAccount_.metadata.name,
          containers_+: {
            default: k.Container('alb-ingress-controller') {
              image: $.containerImage + ':' + $.containerImageTag,
              args: [
                '--ingress-class=' + $.ingressClass,
                '--cluster-name=' + $.clusterName,
              ],
              ports_+: {
                metrics: { containerPort: 10254 },
              },
              livenessProbe: {
                httpGet: {
                  path: '/healthz',
                  port: 'metrics',
                },
                initialDelaySeconds: 30,
                periodSeconds: 10,
                timeoutSeconds: 1,
              },
              readinessProbe: self.livenessProbe {
                timeoutSeconds: 3,
              },
            },
          },
        },
      },
    },
  },

  local podMonitor_ = k.PodMonitor($.name) {
    metadata+: $.metadata_,
    spec+: {
      podMetricsEndpoints: [{ interval: '10s', port: 'metrics', path: '/metrics' }],
      namespaceSelector: {
        matchNames: [$.namespace],
      },
      selector: {
        matchLabels: $.metadata_.labels,
      },
    },
  },

  serviceAccount: std.prune(serviceAccount_),
  clusterRole: std.prune(clusterRole_),
  clusterRoleBinding: std.prune(clusterRoleBinding_),
  deployment: std.prune(deployment_),
  podMonitor: if $.enableMonitoring then std.prune(podMonitor_),
}
