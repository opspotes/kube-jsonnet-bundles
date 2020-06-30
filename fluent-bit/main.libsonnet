local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'fluent-bit',
  namespace:: 'monitoring',
  containerImage:: 'fluent/fluent-bit',
  containerImageTag:: '1.4.6',
  enableMonitoring:: true,

  metadata_:: {
    namespace: $.namespace,
    labels: k.labels($.name, 'logging'),
  },

  local serviceAccount_ = k.ServiceAccount($.name) {
    metadata+: $.metadata_,
  },

  local clusterRole_ = k.ClusterRole($.name + '-ro') {
    metadata+: $.metadata_ {
      namespace: null,
    },
    rules: [
      {
        apiGroups: [''],
        resources: ['namespaces', 'pods'],
        verbs: ['get', 'list', 'watch'],
      },
    ],
  },

  local clusterRoleBinding_ = k.ClusterRoleBinding($.name + '-ro') {
    metadata+: $.metadata_ {
      namespace: null,
    },
    subjects_: [
      serviceAccount_,
    ],
    roleRef_: clusterRole_,
  },

  local config_ = k.ConfigMap($.name + '-config') {
    metadata+: $.metadata_,
    data: {
      'fluent-bit.conf': importstr 'files/fluent-bit.conf',
      'functions.lua': importstr 'files/functions.lua',
      'parsers.conf': importstr 'files/parsers.conf',
    },
  },

  local daemonset_ = k.DaemonSet($.name) {
    metadata+: $.metadata_,
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            default: k.Container('fluent-bit') {
              image: $.containerImage + ':' + $.containerImageTag,
              resources: {
                requests: { cpu: '5m', memory: '10Mi' },
                limits: { cpu: '50m', memory: '100Mi' },
              },
              ports_+: {
                metrics: { containerPort: 2020 },
              },
              livenessProbe: {
                httpGet: {
                  path: '/',
                  port: 'metrics',
                },
                initialDelaySeconds: 30,
                timeoutSeconds: 2,
                periodSeconds: 10,
              },
              volumeMounts_+: {
                'fluent-bit-config': {
                  mountPath: '/fluent-bit/etc/',
                },
                'log-socket': {
                  mountPath: '/run/log-socket/',
                },
                varlog: {
                  mountPath: '/var/log',
                },
                varlibdockercontainers: {
                  mountPath: '/var/lib/docker/containers',
                  readOnly: true,
                },
              },
            },
          },
          tolerations: [
            { effect: 'NoExecute', operator: 'Exists' },
            { effect: 'NoSchedule', operator: 'Exists' },
          ],
          volumes_+: {
            'fluent-bit-config': {
              configMap: {
                name: config_.metadata.name,
              },
            },
            'log-socket': {
              hostPath: {
                path: '/run/log-socket/',
              },
            },
            varlog: {
              hostPath: {
                path: '/var/log',
              },
            },
            varlibdockercontainers: {
              hostPath: {
                path: '/var/lib/docker/containers',
              },
            },
          },
          serviceAccountName: serviceAccount_.metadata.name,
          terminationGracePeriodSeconds: 10,
        },
      },
    },
  },

  local podMonitor_ = k.PodMonitor($.name) {
    metadata+: $.metadata_,
    spec+: {
      podMetricsEndpoints: [{ interval: '10s', port: 'metrics', path: '/api/v1/metrics/prometheus' }],
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
  config: std.prune(config_),
  daemonset: std.prune(daemonset_),
  podMonitor: if $.enableMonitoring then std.prune(podMonitor_),
}
