local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'external-secrets',
  namespace:: 'kube-system',
  containerImage:: 'godaddy/kubernetes-external-secrets',
  containerImageTag:: '4.0.0',
  enablePodMonitor:: true,
  logLevel:: 'info',
  awsRegion:: error 'awsRegion required',
  iamRoleArn:: error 'iamRoleArn required',

  metadata_:: {
    namespace: $.namespace,
    labels: k.labels($.name, 'external-secrets'),
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
        apiGroups: [''],
        resources: ['secrets'],
        verbs: ['create', 'update'],
      },
      {
        apiGroups: [''],
        resources: ['namespaces'],
        verbs: ['get', 'list', 'watch'],
      },
      {
        apiGroups: ['apiextensions.k8s.io'],
        resources: ['customresourcedefinitions'],
        resourceNames: ['externalsecrets.kubernetes-client.io'],
        verbs: ['get', 'update'],
      },
      {
        apiGroups: ['kubernetes-client.io'],
        resources: ['externalsecrets'],
        verbs: ['get', 'watch', 'list'],
      },
      {
        apiGroups: ['kubernetes-client.io'],
        resources: ['externalsecrets/status'],
        verbs: ['get', 'update'],
      },
      {
        apiGroups: ['apiextensions.k8s.io'],
        resources: ['customresourcedefinitions'],
        verbs: ['create'],
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

  local clusterRoleBindingAuth_ = k.ClusterRoleBinding($.name + '-auth') {
    metadata+: $.metadata_ {
      namespace: null,
    },
    subjects_: [
      serviceAccount_,
    ],
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'system:auth-delegator',
    },
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
              env_+: {
                AWS_REGION: $.awsRegion,
                LOG_LEVEL: $.logLevel,
              },
              ports_+: {
                metrics: { containerPort: 3001 },
              },
            },
          },
          securityContext: {
            runAsNonRoot: true,
            fsGroup: 65534,
          },
        },
      },
    },
  },

  local podMonitor_ = k.PodMonitor($.name) {
    metadata+: $.metadata_,
    spec+: {
      podMetricsEndpoints: [{ interval: '30s', port: 'metrics' }],
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
  clusterRoleBindingAuth: std.prune(clusterRoleBindingAuth_),
  deployment: std.prune(deployment_),
  podMonitor: if $.enablePodMonitor then std.prune(podMonitor_),
}
