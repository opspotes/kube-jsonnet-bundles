{
  // annotation helpers
  annotation(key, value): {
    metadata+: {
      annotations+: {
        [key]: value,
      },
    },
  },

  irsaAnnotation(roleArn): $.annotation('eks.amazonaws.com/role-arn', roleArn),

  ingressWhitelistAnnot(ipRanges, ingressKey='ingress'): {
    [ingressKey]+: $.annotation('nginx.ingress.kubernetes.io/whitelist-source-range', std.join(',', ipRanges)),
  },

  // label helpers

  labels(name, partOf): {
    'app.kubernetes.io/name': name,
    'app.kubernetes.io/part-of': partOf,
  },

  customObjectLabels(labels): {
    metadata+: {
      labels+: labels,
    },
  },

  customReplicationControllerLabels(labels): $.customObjectLabels(labels) {
    spec+: {
      selector+: {
        matchLabels+: labels,
      },
      template+: {
        metadata+: {
          labels+: labels,
        },
      },
    },
  },

  customServiceLabels(labels): $.customObjectLabels(labels) {
    spec+: {
      selector+: labels,
    },
  },

  // stuff
  podAntiAffinity(name): {
    podAntiAffinity: {
      requiredDuringSchedulingIgnoredDuringExecution: [{
        labelSelector: {
          matchExpressions: [{
            key: 'app.kubernetes.io/name',
            operator: 'In',
            values: [name],
          }],
        },
        topologyKey: 'kubernetes.io/hostname',
      }],
    },
  },

  appendContainerArguments(containers, containerName, arguments): (
    local f(container) = (
      if containerName == container.name then container { args+: arguments } else container
    );
    std.map(f, containers)
  ),
}
