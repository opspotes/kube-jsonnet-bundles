local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'cluster-autoscaler',
  namespace:: 'kube-system',
  containerImage:: 'eu.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler',
  containerImageTag:: 'v1.16.5',
  awsRegion:: error 'awsRegion required',
  iamRoleArn:: error 'iamRoleArn required',
  clusterName:: error 'clusterName required',

  metadata_:: {
    namespace: $.namespace,
    labels: k.labels($.name, 'cluster-autoscaler'),
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
        resources: ['events', 'endpoints'],
        verbs: ['create', 'patch'],
      },
      {
        apiGroups: [''],
        resources: ['pods/eviction'],
        verbs: ['create'],
      },
      {
        apiGroups: [''],
        resources: ['pods/status'],
        verbs: ['update'],
      },
      {
        apiGroups: [''],
        resources: ['endpoints'],
        resourceNames: ['cluster-autoscaler'],
        verbs: ['get', 'update'],
      },
      {
        apiGroups: [''],
        resources: ['nodes'],
        verbs: ['watch', 'list', 'get', 'update'],
      },
      {
        apiGroups: [''],
        resources: ['pods', 'services', 'replicationcontrollers', 'persistentvolumeclaims', 'persistentvolumes'],
        verbs: ['watch', 'list', 'get'],
      },
      {
        apiGroups: ['extensions'],
        resources: ['replicasets', 'daemonsets'],
        verbs: ['watch', 'list', 'get'],
      },
      {
        apiGroups: ['policy'],
        resources: ['poddisruptionbudgets'],
        verbs: ['watch', 'list'],
      },
      {
        apiGroups: ['apps'],
        resources: ['statefulsets', 'replicasets', 'daemonsets'],
        verbs: ['watch', 'list', 'get'],
      },
      {
        apiGroups: ['storage.k8s.io'],
        resources: ['storageclasses', 'csinodes'],
        verbs: ['watch', 'list', 'get'],
      },
      {
        apiGroups: ['batch', 'extensions'],
        resources: ['jobs'],
        verbs: ['watch', 'list', 'get', 'patch'],
      },
      {
        apiGroups: ['coordination.k8s.io'],
        resources: ['leases'],
        verbs: ['create'],
      },
      {
        apiGroups: ['coordination.k8s.io'],
        resourceNames: ['cluster-autoscaler'],
        resources: ['leases'],
        verbs: ['get', 'update'],
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

  local role_ = k.Role($.name) {
    metadata+: $.metadata_,
    rules: [
      {
        apiGroups: [''],
        resources: ['configmaps'],
        verbs: ['create', 'list', 'watch'],
      },
      {
        apiGroups: [''],
        resources: ['configmaps'],
        resourceNames: ['cluster-autoscaler-status', 'cluster-autoscaler-priority-expander'],
        verbs: ['delete', 'get', 'update', 'watch'],
      },
    ],
  },

  local roleBinding_ = k.RoleBinding($.name) {
    metadata+: $.metadata_,
    subjects_: [
      serviceAccount_,
    ],
    roleRef_: role_,
  },

  local deployment_ = k.Deployment($.name) {
    metadata+: $.metadata_,
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: serviceAccount_.metadata.name,
          containers_+: {
            default: k.Container($.name) {
              command: [
                './cluster-autoscaler',
                '--v=0',
                '--stderrthreshold=info',
                '--cloud-provider=aws',
                '--skip-nodes-with-local-storage=false',
                '--skip-nodes-with-system-pods=false',
                '--expander=least-waste',
                '--balance-similar-node-groups',
                '--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/' + $.clusterName,
              ],
              image: $.containerImage + ':' + $.containerImageTag,
              imagePullPolicy: 'Always',
              env_+: {
                AWS_REGION: $.awsRegion,
              },
              resources: {
                limits: { cpu: '100m', memory: '300Mi' },
                requests: { cpu: '100m', memory: '300Mi' },
              },
              ports_+: {
                metrics: { containerPort: 8085 },
              },
              volumeMounts_+: {
                'ssl-certs': {
                  mountPath: '/etc/ssl/certs/ca-certificates.crt',
                  readOnly: true,
                },
              },
              livenessProbe: {
                httpGet: {
                  path: '/health-check',
                  port: 'metrics',
                },
                initialDelaySeconds: 10,
                timeoutSeconds: 10,
                periodSeconds: 10,
              },
            },
          },
          volumes_+: {
            'ssl-certs': {
              hostPath: {
                path: '/etc/ssl/certs/ca-bundle.crt',
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
      podMetricsEndpoints: [{ interval: '10s', port: 'metrics' }],
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
  role: std.prune(role_),
  roleBinding: std.prune(roleBinding_),
  deployment: std.prune(deployment_),
  podMonitor: std.prune(podMonitor_),
}
