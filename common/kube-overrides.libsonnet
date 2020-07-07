{
  // kube-libsonnet overrides
  RoleBinding(name): super.RoleBinding(name) {
    subjects: [
      {
        kind: o.kind,
        name: o.metadata.name,
        [if o.kind == 'ServiceAccount' then 'namespace']: o.metadata.namespace,
      }
      for o in self.subjects_
    ],
  },

  ClusterRoleBinding(name): $.RoleBinding(name) {
    kind: 'ClusterRoleBinding',
  },

  Container(name): super.Container(name) {
    envList(map):: [
      if std.type(map[x]) == 'object' then
        { name: x, valueFrom: map[x] }
      else if std.type(map[x]) == 'array' then
        { name: x, value: std.join(',', map[x]) }
      else
        { name: x, value: map[x] }
      for x in std.objectFields(map)
    ],
  },

  CronJob(name): super.CronJob(name) {
    spec+: {
      successfulJobsHistoryLimit: 3,
      failedJobsHistoryLimit: 3,
    },
  },

  Deployment(name): super.Deployment(name) {
    spec+: {
      revisionHistoryLimit: 3,
    },
  },

  Job(name): super.Job(name) {
    spec+: {
      completions: 1,
      parallelism: 1,
      ttlSecondsAfterFinished: 3600,
    },
  },

  Service(name): super.Service(name) {
    local this = self,

    target_ports:: [this.target_pod.spec.containers[0].ports[0].name],

    spec+: {
      ports: (
        [
          {
            name: port.name,
            port: port.containerPort,
            targetPort: port.containerPort,
            protocol: if std.objectHas(port, 'protocol') then port.protocol else 'TCP',
          }
          for port in std.flattenArrays(std.map(function(o) o.ports, this.target_pod.spec.containers))
          if std.count(this.target_ports, port.name) > 0
        ]
      ),
    },
  },

  StorageClass(name): super.StorageClass(name) {
    apiVersion: 'storage.k8s.io/v1',
  },
}
