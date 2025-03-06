apiVersion: v1
kind: Config
clusters:
- name: yc-cluster
  cluster:
    server: ${endpoint}
    certificate-authority-data: ${cluster_ca}
users:
- name: yc-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: yc
      args:
      - k8s
      - create-token
      #- --cluster-id=${k8s_cluster_id}
      - --profile=default
contexts:
- name: yc-context
  context:
    cluster: yc-cluster
    user: yc-user
current-context: yc-context