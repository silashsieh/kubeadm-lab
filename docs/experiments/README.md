# Experiment log

One file per drill, dated. Planned drills:

- etcd quorum: kill 1 CP node (cluster fine) vs 2 (API down) — observe both
- etcd snapshot save → break the cluster → restore
- `kubeadm upgrade` rolling through nodes one at a time
- drain/cordon + PodDisruptionBudget behavior with only 2 workers
- traffic path tracing: client → VIP/Ingress → Service → kube-proxy → CNI

These write-ups are the interview stories — record what actually happened,
including the failures.
