#!/bin/bash
set -euo pipefail

readonly prom_url="<<TODO>>"
# give some small overhead to real quota to allow for current apps running that might in future get a default requests from the limitrange when they are rescheduled
readonly quota_mem_limit_bytes="$(( 1 * 1024 * 1024 * 1024 ))" # 3 Gi
readonly quota_cpu_limit_cores=1


promtool query instant "$prom_url" "namespace_memory:kube_pod_container_resource_requests:sum >= $quota_mem_limit_bytes" -o json | jq -r ".[].metric.namespace" > /tmp/mem-ok-namespaces

promtool query instant "$prom_url" "namespace_cpu:kube_pod_container_resource_requests:sum >= $quota_cpu_limit_cores" -o json | jq -r ".[].metric.namespace" > /tmp/cpu-ok-namespaces

# exclude certain namespaces from queries, here only kube-system
readonly custom_quota_cpu_mem_namespaces="$(comm /tmp/cpu-ok-namespaces /tmp/mem-ok-namespaces -1 -2 | grep -v kube-system)"
readonly custom_quota_cpuonly_namespaces="$(comm /tmp/cpu-ok-namespaces /tmp/mem-ok-namespaces -2 -3 | grep -v kube-system)"
readonly custom_quota_memonly_namespaces="$(comm /tmp/cpu-ok-namespaces /tmp/mem-ok-namespaces -1 -3 | grep -v kube-system)"

echo "namespaces needing custom quota for cpu & mem:"
while IFS= read -r ns; do 
  if [ -n "$ns" ]; then
    mem_req="$(promtool query instant "$prom_url" "namespace_memory:kube_pod_container_resource_requests:sum{namespace=\"${ns}\"}" -o json | jq -r ".[].value[1]")"
    cpu_req="$(promtool query instant "$prom_url" "namespace_cpu:kube_pod_container_resource_requests:sum{namespace=\"${ns}\"}" -o json | jq -r ".[].value[1]")"
    echo "{ns: \"$ns\", mem: \"$(( mem_req / ( 1000 * 1000 )))\", cpu: \"$cpu_req\" }"
  fi
done <<< "$custom_quota_cpu_mem_namespaces"

echo "namespaces needing custom quota for cpu only:"
while IFS= read -r ns; do 
  if [ -n "$ns" ]; then
    mem_req="$quota_mem_limit_bytes"
    cpu_req="$(promtool query instant "$prom_url" "namespace_cpu:kube_pod_container_resource_requests:sum{namespace=\"${ns}\"}" -o json | jq -r ".[].value[1]")"
    echo "{ns: \"$ns\", mem: \"$mem_req\", cpu: \"$cpu_req\" }"
  fi
done <<< "$custom_quota_cpuonly_namespaces"


echo "namespaces needing custom quota for mem:"
while IFS= read -r ns; do 
  if [ -n "$ns" ]; then
    mem_req="$(promtool query instant "$prom_url" "namespace_memory:kube_pod_container_resource_requests:sum{namespace=\"${ns}\"}" -o json | jq -r ".[].value[1]")"
    cpu_req="$(promtool query instant "$prom_url" "namespace_cpu:kube_pod_container_resource_requests:sum{namespace=\"${ns}\"}" -o json | jq -r ".[].value[1]")"
    echo "{ns: \"$ns\", mem: \"$mem_req\", cpu: \"$cpu_req\" }"
  fi
done <<< "$custom_quota_memonly_namespaces"


