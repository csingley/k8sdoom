#!/bin/bash
# k8s-poll.sh
# Bridge Kubernetes nodes to psdoom-ng format

if ! command -v kubectl &> /dev/null; then
    echo "k8s 0 ERROR 1"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "k8s 0 ERROR 1"
    exit 1
fi

kubectl get nodes -o json | jq -r '.items[] | [
  .metadata.name,
  (if (.status.conditions[] | select(.type=="Ready") | .status == "False") then 1
   elif (.spec.unschedulable == true) then 5
   elif (.spec.taints[]? | select(.effect == "NoSchedule")) then 4
   else 0 end)
] | @tsv' | while IFS=$'\t' read -r name type; do
  # Generate a stable positive integer PID from the node name
  # CRC32 % 1,000,000 ensures it's always a small positive int
  pid=$(echo "$name" | cksum | awk '{print ($1 % 1000000) + 1}')
  echo "k8s $pid $name $type"
done
