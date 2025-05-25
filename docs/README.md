# 🏠 Home Compute Cluster

**Project Objective:** Establish a resilient, maintainable home compute cluster using NixOS and a declarative Nix Flake approach. Prioritize simplicity, fast recovery, and progressive automation over traditional "true high availability". Ensure services can be recovered within hours using backup and configuration tooling.

**Hardware Configuration:**

* **Compute Nodes (4 total):**

  * RAM: 16GB
  * Storage: 1x 2TB SSD per node
  * Networking: 1GbE
* **NAS:**

  * RAM: 8GB
  * Storage: 4x 12TB drives (Btrfs/SnapRAID/Mergerfs up)

**Cluster Design Philosophy:**

* Independent, stateful workloads run on each compute node.
* No complex HA orchestration; focus on backup + rapid restoration.
* Backups are automated to NAS and optionally cloud (e.g., S3).
* High-value services can be restored via scripts or Nix Flake automation.
* Eventually introduce scripted recovery triggered by uptime monitoring.

**Core Infrastructure & Software Stack:**

* **Operating System:** NixOS, declaratively managed with a unified Flake.
* **Storage:**

  * **Primary App Storage:** Local per-node volumes
  * **Backups:** NAS with Btrfs or SnapRAID
* **Backup Strategy:**

  * Use tools like `btrbk` or `restic` for scheduled backups.
  * Snapshots for rapid rollback on compute nodes and NAS.
  * Offsite backups for critical data (e.g., S3 Glacier).
* **Monitoring & Recovery:**

  * Use tools like Uptime Kuma to monitor service health.
  * Define and script recovery actions (e.g., Nix deploy + restore volume).
* **Service Deployment:**

  * Mix of Podman containers and native Nix systemd services.
  * Each service has a designated primary node.
  * No active-active HA — instead, rely on simple failover scripts or reboots.

**Goals for Nix Flake Configuration:**

* Declarative configuration for all nodes.
* Reproducible setup of base services (Podman, logging, SSH, etc.).
* Scripts or modules for backup/restore of services.
* Optional: support future integration of Ceph and Keepalived.

**Out of Scope (initially):**

* Full distributed storage setup (e.g., Ceph/SeaweedFS HA config).
* Full HA with automatic failover.
* Kubernetes or similar orchestrators.

**Future Enhancements (Not immediate):**

* Declarative Ceph or distributed FS config (opt-in per service).
* Restore automation via systemd timers or monitoring hooks.
* Load balancing and failover via Keepalived (eventual)
* GitOps and Colmena/Deploy-RS pipeline for multi-node updates.

---

Made with ❤️ and NixOS for reliable home infrastructure. 