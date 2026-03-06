# Home Media Server

A unified Helm chart for deploying a complete media automation stack on Kubernetes.

## Applications

This chart deploys:
- **Jellyfin**: Media server and streaming platform
- **Plex**: Media server and streaming platform
- **Sonarr**: TV series management and automation
- **Radarr**: Movie management and automation
- **Prowlarr**: Indexer manager for *arr apps
- **SABnzbd**: Usenet download client

## Features

- **Single Chart**: One `helm install` deploys all applications
- **Unified Configuration**: All settings in one `values.yaml` file
- **Shared Storage**: Common media PVC for all apps, with optional NFS backing
- **Subdomain-Based Routing**: Each app gets its own subdomain (e.g., jellyfin.media.local, sonarr.media.local)
- **GatewayAPI Support**: HTTPRoute resources for modern Kubernetes Gateway API ingress
- **Centralized Settings**: Timezone and routing configured globally

## Quick Start

Install the chart:

```bash
helm install media-stack ./chart -n media --create-namespace
```

Upgrade an existing installation:

```bash
helm upgrade media-stack ./chart -n media
```

## Configuration

### Global Settings

All apps share these global configurations in `values.yaml`:

```yaml
global:
  timezone: "UTC"
  baseDomain: "media.local"  # Base domain for all subdomains

  # GatewayAPI HTTPRoute (enabled by default)
  httpRoute:
    enabled: true
    parentRef:
      name: media-gateway
      namespace: default
    annotations: {}

  # Standard Ingress (alternative to HTTPRoute)
  ingress:
    enabled: false
    className: ""
    annotations: {}
    tls: []
```

### URL Structure

With the default configuration, apps are accessible at their own subdomains:
- Jellyfin: `https://jellyfin.media.local/`
- Plex: `https://plex.media.local/`
- Prowlarr: `https://prowlarr.media.local/`
- Sonarr: `https://sonarr.media.local/`
- Radarr: `https://radarr.media.local/`
- SABnzbd: `https://sabnzbd.media.local/`

### Routing Options

The chart supports two routing methods:

**GatewayAPI HTTPRoutes** (default, `global.httpRoute.enabled: true`):
- Kubernetes Gateway API routing with subdomain-based routing
- Requires a Gateway controller (e.g., Envoy Gateway, Contour, Istio) with a configured Gateway named `media-gateway`
- Recommended for modern Kubernetes clusters

**Standard Ingress** (alternative, `global.ingress.enabled: true`):
- Kubernetes-native ingress for clusters with a traditional Ingress controller
- Creates individual Ingress resources per app (one subdomain per Ingress)
- Supports custom ingress classes and annotations

**Note:** Enable only one routing method at a time (either HTTPRoute or Ingress, not both).

### Shared Media Storage

By default, a single shared `ReadWriteMany` PVC is created and mounted by all apps:

```yaml
shared:
  media:
    enabled: true
    storageClass: ""
    accessMode: ReadWriteMany
    size: 500Gi
```

All apps mount this PVC and use subdirectories:
- **SABnzbd**: Downloads to `/media/downloads`
- **Sonarr**: Monitors `/media/downloads`, organizes to `/media/tv`
- **Radarr**: Monitors `/media/downloads`, organizes to `/media/movies`
- **Jellyfin**: Streams from `/media/tv`, `/media/movies`, etc.
- **Plex**: Streams from `/data/tv`, `/data/movies`, etc.

This approach avoids unnecessary file copies — Sonarr and Radarr can hardlink or move files within the same filesystem, which is instant and doesn't duplicate data.

**NFS-backed shared storage:**

To use an NFS share as the shared media PVC, enable NFS mode. This creates a static PersistentVolume bound directly to your NFS export:

```yaml
shared:
  media:
    enabled: true
    accessMode: ReadWriteMany
    size: 500Gi
    nfs:
      enabled: true
      server: "192.168.1.100"   # NFS server IP or hostname
      path: "/mnt/media"        # Exported NFS path
```

When NFS is enabled, `storageClass` is ignored and static binding is used instead.

**Post-Installation Configuration:**

After deploying, configure each app through its web UI:

1. **SABnzbd** (`Settings → Folders`):
   - Temporary Download Folder: `/media/downloads/incomplete`
   - Completed Download Folder: `/media/downloads/complete`

2. **Sonarr** (`Settings → Media Management`):
   - Root Folder: `/media/tv`
   - Download Client settings should point to `/media/downloads/complete`

3. **Radarr** (`Settings → Media Management`):
   - Root Folder: `/media/movies`
   - Download Client settings should point to `/media/downloads/complete`

4. **Jellyfin** (`Dashboard → Libraries`):
   - Add library with folder: `/media/tv` for TV shows
   - Add library with folder: `/media/movies` for movies

5. **Plex** (`Settings → Libraries`):
   - Add library with folder: `/data/tv` for TV shows
   - Add library with folder: `/data/movies` for movies

### Per-App Subdomain Configuration

Each application has its own subdomain and optional basePath settings:

```yaml
jellyfin:
  enabled: true
  ingress:
    subdomain: "jellyfin"      # Accessible at jellyfin.media.local
    basePath: ""               # No path prefix (serves from /)

plex:
  enabled: true
  ingress:
    subdomain: "plex"          # Accessible at plex.media.local
    basePath: ""

sonarr:
  enabled: true
  ingress:
    subdomain: "sonarr"        # Accessible at sonarr.media.local
    basePath: ""

radarr:
  enabled: true
  ingress:
    subdomain: "radarr"        # Accessible at radarr.media.local
    basePath: ""

prowlarr:
  enabled: true
  ingress:
    subdomain: "prowlarr"      # Accessible at prowlarr.media.local
    basePath: ""

sabnzbd:
  enabled: true
  ingress:
    subdomain: "sabnzbd"       # Accessible at sabnzbd.media.local
    basePath: ""
```

### Plex Claim Token

To register your Plex server with your Plex account on first deploy, provide a claim token:

```yaml
plex:
  claimToken: "claim-xxxxxxxxxxxxxxxxxxxx"
```

Get your token from [plex.tv/claim](https://www.plex.tv/claim/). Tokens expire after 4 minutes, so deploy immediately after generating one.

### Authentik / Internal Proxy

- **Disable external routing for specific apps:** If you want Authentik's outpost (running inside the cluster) to proxy requests to an application directly, disable that app's ingress so no public HTTPRoute/Ingress is created. The application's `Service` stays `ClusterIP` and remains reachable inside the cluster by the outpost.

- **Per-app settings (example):**

```yaml
sonarr:
  ingress:
    enabled: false    # don't create an external HTTPRoute/Ingress for Sonarr
  service:
    annotations:
      internal.authentik.io/expose: "true"  # optional marker for your outpost

radarr:
  ingress:
    enabled: false
  service:
    annotations: {}

prowlarr:
  ingress:
    enabled: false
  service:
    annotations: {}

sabnzbd:
  ingress:
    enabled: false
  service:
    annotations: {}
```

The outpost can reach services using Kubernetes DNS (e.g., `sonarr.media.svc.cluster.local`). Adding service annotations is optional but useful if you want the outpost to auto-discover targets.

### Advanced Configuration

**Using Existing PVCs:**

```yaml
jellyfin:
  persistence:
    config:
      existingClaim: "my-jellyfin-config"

shared:
  media:
    enabled: false  # Don't create new PVC

sonarr:
  persistence:
    media:
      existingClaim: "my-existing-media-pvc"
```

**SABnzbd Hostname Whitelist:**

SABnzbd requires hostname whitelisting for security. The chart automatically includes the service names and route hostname. Add custom hostnames if needed:

```yaml
sabnzbd:
  hostnameWhitelist: "custom.domain.com,another.domain.com"
```

**Custom Volumes and Volume Mounts:**

Each app supports additional volumes and mounts via `extraVolumes` and `extraVolumeMounts`:

```yaml
sonarr:
  extraVolumes:
    - name: scripts
      configMap:
        name: sonarr-scripts
  extraVolumeMounts:
    - name: scripts
      mountPath: /scripts
      readOnly: true
```

### Hardware Acceleration

Both Jellyfin and Plex support hardware-accelerated transcoding using Intel Quick Sync or NVIDIA NVENC. Both options are disabled by default.

**Intel Quick Sync:**

```yaml
jellyfin:   # or plex:
  hardwareAcceleration:
    intelQuickSync:
      enabled: true
      devicePath: /dev/dri  # Default path
      videoGroupId: 44      # Video group GID (44 on most systems, 39 on some)
```

This mounts the `/dev/dri` host device into the container and adds the video group for device access.

**NVIDIA NVENC:**

Requires the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html) installed in your cluster.

```yaml
jellyfin:   # or plex:
  hardwareAcceleration:
    nvidia:
      enabled: true
      gpuLimit: 1                    # Number of GPUs to allocate
      resourceName: nvidia.com/gpu   # GPU resource name
      runtimeClassName: nvidia
```

**Important Notes:**
- Enable only ONE acceleration method at a time (either Quick Sync or NVIDIA, not both)
- After enabling hardware acceleration, configure it in the app's web UI under transcoding settings
- When hardware acceleration is enabled, you can pin the pod to nodes with the hardware using the per-acceleration scheduling fields:

```yaml
jellyfin:
  hardwareAcceleration:
    intelQuickSync:
      enabled: true
      nodeSelector:
        kubernetes.io/hostname: "node-with-igpu"
      tolerations: []
      affinity: {}

    nvidia:
      enabled: true
      nodeSelector:
        node-role.kubernetes.io/gpu: "true"
      tolerations: []
      affinity: {}
```

## Images

This chart uses:
- **Jellyfin**: `jellyfin/jellyfin:10.11.6` (official)
- **Plex**: `ghcr.io/home-operations/plex:1.43.0`
- **Prowlarr**: `ghcr.io/home-operations/prowlarr:2.3.2`
- **Sonarr**: `ghcr.io/home-operations/sonarr:4.0.16`
- **Radarr**: `ghcr.io/home-operations/radarr:6.1.1`
- **SABnzbd**: `ghcr.io/home-operations/sabnzbd:4.5.5`

The `home-operations` images are community-maintained and rootless-compatible. Specific versions are pinned by default but can be overridden in `values.yaml`.

## Requirements

- Kubernetes 1.19+
- Helm 3.x
- Persistent volume provisioning
- For shared downloads: Storage class supporting ReadWriteMany (or NFS)
- For GatewayAPI HTTPRoutes: A Gateway API-compatible controller with a configured Gateway

## Security

All containers run with:
- Non-root user (`65534` by default, configurable per app)
- Read-only root filesystem
- Dropped capabilities
- Seccomp profile (RuntimeDefault)

## Uninstall

```bash
helm uninstall media-stack -n media
```

Note: PVCs are not automatically deleted and must be removed manually if desired.

## License

MIT
