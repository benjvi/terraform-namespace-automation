#!/bin/bash
set -euo pipefail

readonly prom_url="<<TODO>>"
# give some small overhead to real quota to allow for current apps running that might in future get a default requests from the limitrange when they are rescheduled
readonly quota_mem_limit_bytes="$(( 3 * 1024 * 1024 * 1024 ))" # 3 Gi
readonly quota_cpu_limit_cores=2


promtool query instant "$prom_url" "namespace_memory:kube_pod_container_resource_requests:sum < $quota_mem_limit_bytes" -o json | jq -r ".[].metric.namespace" > /tmp/mem-ok-namespaces

promtool query instant "$prom_url" "namespace_cpu:kube_pod_container_resource_requests:sum < $quota_cpu_limit_cores" -o json | jq -r ".[].metric.namespace" > /tmp/cpu-ok-namespaces

namespaces="$(comm /tmp/cpu-ok-namespaces /tmp/mem-ok-namespaces -1 -2 | grep -v kube-system)"

echo "namespaces=$(echo "$namespaces" | jq -c --raw-input -s 'split("\n") | map(select(. != ""))')" > terraform.tfvars

cat terraform.tfvars
#TODO: split to separate script
terraform init
while IFS= read -r ns; do 
  if [ -n "$ns" ]; then
    terraform import "module.namespaces[\"${ns}\"].kubernetes_namespace.ns" "$ns" || true
  fi
done <<< "$namespaces"
 
terraform plan
