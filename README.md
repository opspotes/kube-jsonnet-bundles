# kube-jsonnet-bundles

Set of opinionated Kubernetes components written in Jsonnet.

## Usage

Get it using [jb](https://github.com/jsonnet-bundler/jsonnet-bundler):
```
jb install github.com/jsonnet-bundler/jsonnet-bundler@master
```

Deploy components using [tk](https://github.com/grafana/tanka):
```jsonnet
{
  (import 'kube-jsonnet-bundles/<name>/main.libsonnet') {
    // override fields
  }
}
```
