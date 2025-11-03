# Home Media Server

A unified Helm chart for deploying a complete media automation stack on Kubernetes/OKD.

## Applications

This chart deploys:
- **Jellyfin**: Media server and streaming platform
- **Sonarr**: TV series management and automation
- **Radarr**: Movie management and automation
- **Prowlarr**: Indexer manager for *arr apps
- **SABnzbd**: Usenet download client

## Features

- **Single Chart**: One `helm install` deploys all applications
- **Unified Configuration**: All settings in one `values.yaml` file
- **Shared Storage**: Common downloads PVC for SABnzbd, Sonarr, and Radarr
- **Path-Based Routing**: Single hostname with different paths per app
- **Auto-Configuration**: URL bases automatically configured for *arr apps
- **OKD/OpenShift Ready**: Restrictive security contexts and Routes enabled by default
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
  
  paths:
    jellyfin: ""          # Root path
    prowlarr: "/prowlarr"
    sonarr: "/sonarr"
    radarr: "/radarr"
    sabnzbd: "/sabnzbd"
  
  # OpenShift Route (enabled by default for OKD)
  route:
    enabled: true
    hostname: "media.local"
    tls:
      termination: edge
      insecureEdgeTerminationPolicy: Redirect
  
  # Standard Ingress (alternative to Route)
  ingress:
    enabled: false
    className: ""
    hostname: "media.local"
    annotations: {}
    tls: []
```

### URL Structure

With the default configuration, apps are accessible at:
- Jellyfin: `https://media.local/`
- Prowlarr: `https://media.local/prowlarr`
- Sonarr: `https://media.local/sonarr`
- Radarr: `https://media.local/radarr`
- SABnzbd: `https://media.local/sabnzbd`

The *arr apps (Prowlarr, Sonarr, Radarr) are automatically configured with the correct URL base via initContainers that modify their `config.xml` files on startup. SABnzbd is configured via the `SABNZBD_URL_BASE` environment variable. Jellyfin serves at the root path and requires no special configuration.

### Routing Options

The chart supports two routing methods:

**OpenShift Routes** (default, `global.route.enabled: true`):
- Native OpenShift/OKD routing with path-based routing
- TLS termination at the router
- Recommended for OKD environments

**Standard Ingress** (alternative, `global.ingress.enabled: true`):
- Kubernetes-native ingress for standard k8s clusters
- Supports custom ingress classes and annotations
- Use when Routes are not available

**Note:** Enable only one routing method at a time (either Route or Ingress, not both).

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

All apps mount this PVC at `/media` and use subdirectories:
- **SABnzbd**: Downloads to `/media/downloads`
- **Sonarr**: Monitors `/media/downloads`, organizes to `/media/tv`
- **Radarr**: Monitors `/media/downloads`, organizes to `/media/movies`
- **Jellyfin**: Streams from `/media/tv`, `/media/movies`, etc.

This approach avoids unnecessary file copies - Sonarr and Radarr can hardlink or move files within the same filesystem, which is instant and doesn't duplicate data.

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

### Per-App Configuration

Each application can be enabled/disabled and configured individually:

```yaml
jellyfin:
  enabled: true
  image:
    repository: jellyfin/jellyfin
    tag: "10.11.1"
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
  # ... additional settings
```

See `chart/values.yaml` for all available options.

### Advanced Configuration

**Using Existing PVCs:**

If you have existing PersistentVolumeClaims, you can reference them instead of creating new ones:

```yaml
jellyfin:
  persistence:
    config:
      existingClaim: "my-jellyfin-config"

shared:
  media:
    enabled: false  # Don't create new PVC

# Then reference existing PVC in apps
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

### Hardware Acceleration for Jellyfin

Jellyfin supports hardware-accelerated transcoding using Intel Quick Sync or NVIDIA NVENC. Both options are disabled by default for compatibility.

**Intel Quick Sync:**

To enable Intel Quick Sync, you need to mount the `/dev/dri` device from the host:

```yaml
jellyfin:
  hardwareAcceleration:
    intelQuickSync:
      enabled: true
      devicePath: /dev/dri  # Default path
      videoGroupId: 44      # Video group GID (44 on most systems, 39 on some)
      createSCC: true       # Set to true only if you have cluster-admin privileges
```

This will:
- Mount the `/dev/dri` host device into the container
- Add the video group to the container for device access
- Allow Jellyfin to use Intel Quick Sync for hardware transcoding

**For OpenShift/OKD:**

The chart can automatically create a custom SecurityContextConstraints (SCC) for Jellyfin with Intel Quick Sync support. However, **this requires cluster-admin privileges**.

- **If you have cluster-admin access**: Set `createSCC: true` and the chart will create the SCC automatically
- **If deploying in namespaced mode**: Set `createSCC: false` (default) and ask a cluster admin to create the SCC manually

**Manual SCC Creation (for cluster admins):**

If you don't have cluster-admin privileges or prefer to create the SCC separately, a cluster administrator can apply this SCC:

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: jellyfin-quicksync
  annotations:
    kubernetes.io/description: "SCC for Jellyfin with Intel Quick Sync hardware acceleration. Allows access to /dev/dri device for transcoding."
allowHostDirVolumePlugin: true
allowPrivilegedContainer: false
allowedCapabilities: []
defaultAddCapabilities: []
fsGroup:
  type: RunAsAny
groups: []
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
  - KILL
  - MKNOD
  - SETUID
  - SETGID
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - hostPath
  - persistentVolumeClaim
  - projected
  - secret
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
users:
  - system:serviceaccount:YOUR_NAMESPACE:media-stack-jellyfin
```

Replace `YOUR_NAMESPACE` with your actual namespace (e.g., `media`). The service account name follows the pattern `<release-name>-jellyfin`.

After the SCC is created, deploy the chart with Quick Sync enabled but SCC creation disabled:

```yaml
jellyfin:
  hardwareAcceleration:
    intelQuickSync:
      enabled: true
      createSCC: false  # Don't try to create SCC (already exists)
```

**NVIDIA NVENC:**

To enable NVIDIA GPU acceleration, you must first install the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html) in your cluster. Then enable:

```yaml
jellyfin:
  hardwareAcceleration:
    nvidia:
      enabled: true
      gpuLimit: 1  # Number of GPUs to allocate
      resourceName: nvidia.com/gpu  # GPU resource name
```

This will:
- Request GPU resources from the NVIDIA device plugin
- Automatically mount NVIDIA device files (`/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`)
- Allow Jellyfin to use NVENC for hardware transcoding

**Important Notes:**
- Enable only ONE acceleration method at a time (either Quick Sync or NVIDIA, not both)
- After enabling hardware acceleration, configure it in Jellyfin's web UI under `Dashboard → Playback → Transcoding`
- For Intel Quick Sync on OKD/OpenShift, a custom SCC is automatically created by the Helm chart
- For NVIDIA NVENC, the GPU Operator typically works with the default `restricted-v2` SCC
- Consider using node selectors or affinity rules to schedule Jellyfin on nodes with the appropriate hardware:

```yaml
jellyfin:
  nodeSelector:
    feature.node.kubernetes.io/gpu.present: "true"
    # Or target a specific node by hostname:
    # kubernetes.io/hostname: "p320-node"
```

## Images

This chart uses:
- **Jellyfin**: `jellyfin/jellyfin:10.11.1` (official)
- **Prowlarr**: `ghcr.io/home-operations/prowlarr:2.1.5`
- **Sonarr**: `ghcr.io/home-operations/sonarr:4.0.16.2942`
- **Radarr**: `ghcr.io/home-operations/radarr:6.0.3.10276`
- **SABnzbd**: `ghcr.io/home-operations/sabnzbd:4.5.5`

The `home-operations` images are community-maintained and rootless-compatible, replacing the archived `onedr0p` images. Specific versions are pinned by default but can be overridden in `values.yaml`.

## Requirements

- Kubernetes 1.19+ or OKD/OpenShift 4.x
- Helm 3.x
- Persistent volume provisioning
- For shared downloads: Storage class supporting ReadWriteMany

## Security

All containers run with:
- Non-root user (dynamically assigned on OKD)
- Read-only root filesystem
- Dropped capabilities
- Seccomp profile

## Uninstall

```bash
helm uninstall media-stack -n media
```

Note: PVCs are not automatically deleted and must be removed manually if desired.

## License

MIT
