{
  PodSecurityPolicy(name): $._Object('policy/v1beta1', 'PodSecurityPolicy', name) {
    metadata: {
      name: name,
    },
    spec: {},
  },

  APIService(name): $._Object('apiregistration.k8s.io/v1', 'APIService', name) {
    metadata: {
      name: name,
      labels: {},
    },
    spec: {},
  },

  MutatingWebhookConfiguration(name): $._Object('admissionregistration.k8s.io/v1', 'MutatingWebhookConfiguration', name) {
    metadata: {
      name: name,
      labels: {},
    },
    webhooks: [],
  },

  ValidatingWebhookConfiguration(name): $._Object('admissionregistration.k8s.io/v1', 'ValidatingWebhookConfiguration', name) {
    metadata: {
      name: name,
      labels: {},
    },
    webhooks: [],
  },

  // cert-manager

  Certificate(name): $._Object('cert-manager.io/v1alpha2', 'Certificate', name),

  ClusterIssuer(name): $._Object('cert-manager.io/v1alpha2', 'ClusterIssuer', name),

  Issuer(name): $._Object('cert-manager.io/v1alpha2', 'Issuer', name),

  // prometheus-operator

  PodMonitor(name): $._Object('monitoring.coreos.com/v1', 'PodMonitor', name) {
    spec: {
      podMetricsEndpoints: error 'podMetricsEndpoints required',
      selector: {
        matchLabels: error 'matchLabels required',
      },
    },
  },

  ServiceMonitor(name): $._Object('monitoring.coreos.com/v1', 'ServiceMonitor', name) {
    spec: {
      endpoints: error 'endpoints required',
      selector: {
        matchLabels: error 'matchLabels required',
      },
    },
  },
}
