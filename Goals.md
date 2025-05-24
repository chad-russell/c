## Homelab Compute Cluster Bootstrap: Project Goals for Nix Flake

**Project Objective:** To bootstrap and configure a 4-node highly available compute cluster using NixOS and a declarative Nix Flake. The primary goal is to deploy and manage various homelab applications (e.g., Mealie, Open WebUI, Paperless-ngx) ensuring high availability through automated failover.

**Hardware Configuration (per node, 4 nodes total):**
* RAM: 16GB
* Storage: 1x 2TB NVMe SSD (dedicated for Ceph OSD)
* Networking: 1GbE

**Core Infrastructure & Software Stack:**
* **Operating System:** NixOS, managed declaratively via a unified Nix Flake for all four nodes.
* **Storage Backend:** SeaweedFS, configured across all four compute nodes.
    * **SeaweedFS Deployment:** To be managed by the NixOS SeaweedFS module or declarative configuration.
    * **SeaweedFS Roles per Node:** Each of the 4 nodes will participate in the SeaweedFS cluster.
        * **Volume Servers:** One volume server will be configured on the 2TB SSD of each of the four nodes, providing distributed storage.
        * **Master Servers:** A total of 3 master servers will be deployed across three of the four nodes to ensure quorum and high availability.
        * **Filer Servers:** At least 2 filer servers will be deployed for redundancy, co-located with master servers if practical. The filer provides a POSIX-like interface for applications.
    * **SeaweedFS Data Redundancy & Pools:**
        * A primary replicated collection will be configured for application data.
        * **Configuration:** Replication will be set to `001` (one replica on a different node) or higher, depending on desired redundancy. This ensures data safety and availability, allowing operations to continue if a node fails. (Adjust replication factor as needed for your risk/capacity balance.)
        * **Usable Capacity (approximate):** (4 nodes * 2TB/node) / (replication factor) = usable storage, e.g., with 2x replication, ~4TB usable.
    * **SeaweedFS Storage Provisioning:**
        * **FUSE Mounts:** SeaweedFS will be mounted via FUSE on all four NixOS compute nodes to provide shared, persistent storage for application data, configuration files, etc.
        * **Optional Block Storage:** SeaweedFS supports S3 and block device emulation for specific workloads (e.g., databases requiring dedicated block storage) if deemed necessary.
* **Application High Availability (HA):**
    * **Mechanism:** Keepalived will be used to manage a Virtual IP (VIP) for application services.
    * **Failover:** An active/passive setup is desired. If a node hosting an active application instance fails, Keepalived will automatically fail over the VIP and the application service(s) to one of the remaining healthy nodes.
    * **State Management:** Application state will be maintained on the shared CephFS, ensuring data is immediately available to the application instance on the failover node.
* **Workload Types:**
    * Podman containers.
    * Native Nix applications running as systemd units.

**Desired Outcome from Nix Flake:**
* A fully declarative configuration for all four compute nodes.
* Automated setup of NixOS.
* Automated deployment and configuration of the Ceph cluster as described above (OSDs, MONs, MGRs, CephFS).
* Automated setup and configuration of Keepalived for application HA.
* Base configuration for deploying applications (Podman, systemd units) that utilize the CephFS storage.
* The system should be resilient, allowing one compute node to fail without loss of service for applications configured with Keepalived.

**Exclusions (for this specific Nix Flake bootstrap):**
* Configuration of the separate NAS device.
* Deployment of the actual end-user applications (Mealie, Open WebUI, etc.) – the Flake should prepare the *platform* for them.

This description should give the LLM a solid understanding of what you're aiming to build with your Nix Flake