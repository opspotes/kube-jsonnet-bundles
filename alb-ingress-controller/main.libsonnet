local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'alb-ingress-controller',
  namespace:: 'kube-system',
  containerImage:: 'docker.io/amazon/aws-alb-ingress-controller',
  containerImageTag:: 'v1.1.6',
  ingressClass:: 'alb',
  clusterName:: error 'clusterName required',
  iamRoleArn:: error 'iamRoleArn required',

  local labels = k.labels($.name, 'ingress'),

  metadata_:: {
    namespace: $.namespace,
    labels: labels,
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
            default: k.Container($.name) {
              image: $.containerImage + ':' + $.containerImageTag,
              args: [
                '--ingress-class=' + $.ingressClass,
                '--cluster-name=' + $.clusterName,
              ],
            },
          },
        },
      },
    },
  },

  serviceAccount: std.prune(serviceAccount_),
  clusterRole: std.prune(clusterRole_),
  clusterRoleBinding: std.prune(clusterRoleBinding_),
  deployment: std.prune(deployment_),
}
