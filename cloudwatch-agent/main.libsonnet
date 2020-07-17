local k = import 'kube-jsonnet-bundles/common/kube.libsonnet';

{
  name:: 'cloudwatch-agent',
  namespace:: 'monitoring',
  containerImage:: 'amazon/cloudwatch-agent',
  containerImageTag:: '1.245315.0',
  awsRegion:: error 'awsRegion required',
  clusterName:: error 'clusterName required',
  iamRoleArn:: error 'iamRoleArn required',

  metadata_:: {
    namespace: $.namespace,
    labels: k.labels($.name, 'monitoring'),
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
        resources: ['pods', 'nodes', 'endpoints'],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['apps'],
        resources: ['replicasets'],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['batch'],
        resources: ['jobs'],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: [''],
        resources: ['nodes/proxy'],
        verbs: ['get'],
      },
      {
        apiGroups: [''],
        resources: ['nodes/stats', 'configmaps', 'events'],
        verbs: ['create'],
      },
      {
        apiGroups: [''],
        resources: ['configmaps'],
        resourceNames: ['cwagent-clusterleader'],
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

  configFile_:: {
    agent: {
      region: $.awsRegion,
    },
    logs: {
      metrics_collected: {
        kubernetes: {
          cluster_name: $.clusterName,
          metrics_collection_interval: 60,
        },
      },
      force_flush_interval: 5,
    },
  },

  local config_ = k.ConfigMap($.name + '-config') {
    metadata+: $.metadata_,
    data: {
      'cwagentconfig.json': std.manifestJsonEx($.configFile_, ' '),
    },
  },

  local daemonset_ = k.DaemonSet($.name) {
    metadata+: $.metadata_,
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            default: k.Container('cloudwatch-agent') {
              image: $.containerImage + ':' + $.containerImageTag,
              env_+: {
                HOST_IP: {
                  fieldRef: {
                    fieldPath: 'status.hostIP',
                  },
                },
                HOST_NAME: {
                  fieldRef: {
                    fieldPath: 'spec.nodeName',
                  },
                },
                K8S_NAMESPACE: {
                  fieldRef: {
                    fieldPath: 'metadata.namespace',
                  },
                },
              },
              resources: {
                requests: { cpu: '200m', memory: '200Mi' },
                limits: { cpu: '200m', memory: '200Mi' },
              },
              volumeMounts_+: {
                cwagentconfig: {
                  mountPath: '/etc/cwagentconfig',
                },
                rootfs: {
                  mountPath: '/rootfs',
                  readOnly: true,
                },
                dockersock: {
                  mountPath: '/var/run/docker.sock',
                  readOnly: true,
                },
                varlibdocker: {
                  mountPath: '/var/lib/docker',
                  readOnly: true,
                },
                sys: {
                  mountPath: '/sys',
                  readOnly: true,
                },
                devdisk: {
                  mountPath: '/dev/disk',
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
            cwagentconfig: {
              configMap: {
                name: config_.metadata.name,
              },
            },
            rootfs: {
              hostPath: {
                path: '/',
              },
            },
            dockersock: {
              hostPath: {
                path: '/var/run/docker.sock',
              },
            },
            varlibdocker: {
              hostPath: {
                path: '/var/lib/docker',
              },
            },
            sys: {
              hostPath: {
                path: '/sys',
              },
            },
            devdisk: {
              hostPath: {
                path: '/dev/disk/',
              },
            },
          },
          serviceAccountName: serviceAccount_.metadata.name,
          terminationGracePeriodSeconds: 10,
        },
      },
    },
  },

  serviceAccount: std.prune(serviceAccount_),
  clusterRole: std.prune(clusterRole_),
  clusterRoleBinding: std.prune(clusterRoleBinding_),
  config: std.prune(config_),
  daemonset: std.prune(daemonset_),
}
