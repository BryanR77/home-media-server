# Home Media Server

A unified Helm chart for deploying a complete media automation stack on Kubernetes/OKD.

## Applications

This chart deploys:
- **Jellyfin**: Media server and streaming platform
- **Sonarr**: TV series management and automation
- **Prowlarr**: Indexer manager for *arr apps
- **SABnzbd**: Usenet download client

## Features

- **Single Chart**: One `helm install` deploys all applications
- **Unified Configuration**: All settings in one `values.yaml` file
- **Shared Storage**: Common downloads PVC for SABnzbd and Sonarr
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
- SABnzbd: `https://media.local/sabnzbd`

The *arr apps (Prowlarr, Sonarr) are automatically configured with the correct URL base via initContainers that modify their `config.xml` files on startup. SABnzbd is configured via the `SABNZBD_URL_BASE` environment variable. Jellyfin serves at the root path and requires no special configuration.

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
- **Jellyfin**: Streams from `/media/tv`, `/media/movies`, etc.

This approach avoids unnecessary file copies - Sonarr can hardlink or move files within the same filesystem, which is instant and doesn't duplicate data.

**Post-Installation Configuration:**

After deploying, configure each app through its web UI:

1. **SABnzbd** (`Settings → Folders`):
   - Temporary Download Folder: `/media/downloads/incomplete`
   - Completed Download Folder: `/media/downloads/complete`

2. **Sonarr** (`Settings → Media Management`):
   - Root Folder: `/media/tv`
   - Download Client settings should point to `/media/downloads/complete`

3. **Jellyfin** (`Dashboard → Libraries`):
   - Add library with folder: `/media/tv` for TV shows
   - Add library with folder: `/media/movies` for movies (if using Radarr)

### Per-App Configuration

Each application can be enabled/disabled and configured individually:

```yaml
jellyfin:
  enabled: true
  image:
    repository: jellyfin/jellyfin
    tag: "latest"
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

## Images

This chart uses:
- **Jellyfin**: `jellyfin/jellyfin:latest` (official)
- **Prowlarr**: `ghcr.io/home-operations/prowlarr:2.1.5`
- **Sonarr**: `ghcr.io/home-operations/sonarr:4.0.16.2942`
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
