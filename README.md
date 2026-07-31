# Home Media Server

Helm chart and Argo CD manifests for running a full home media stack on Kubernetes.

The chart name is `media-stack` (current chart version: `0.2.1`) and deploys a set of applications that share a common media library and unified routing.

## What This Deploys

Default enabled apps:
- Jellyfin (media server)
- Plex (media server)
- Sonarr (TV automation)
- Radarr (movie automation)
- Prowlarr (indexer manager)
- SABnzbd (download client)
- Tautulli (Plex monitoring)
- Seerr (media request management)

Optional apps:
- Tdarr server (automated transcoding orchestration)
- Tdarr Node worker (dedicated transcoding worker)

## Repository Layout

```text
home-media-server/
  argocd/
    application.yaml
  chart/
    Chart.yaml
    values.yaml
    templates/
      *.yaml
```

## Deployment Options

### 1) Helm (local/manual)

```bash
helm install media-stack ./chart -n home-media-server --create-namespace
```

Upgrade:

```bash
helm upgrade media-stack ./chart -n home-media-server
```

### 2) Argo CD Multi-Source (recommended)

This repo includes `argocd/application.yaml` as a starter manifest. It expects:
- Source 1: this chart repo (`path: chart`)
- Source 2: a values repo mounted as `$values`

The file is a template and intentionally includes this placeholder:
- `https://github.com/<your-cluster-config-repo>.git`

In your homelab setup, this is implemented in `homelab-cluster-apps/apps/home-media-server.yaml` and points at:
- Chart repo: `BryanR77/home-media-server`
- Values repo: `BryanR77/homelab-cluster-apps-values`
- Values path: `$values/home-media-server/values.yaml`

## Core Configuration

All defaults live in `chart/values.yaml`.

### Global

```yaml
global:
  timezone: "UTC"
  baseDomain: "media.local"

  httpRoute:
    enabled: true
    parentRef:
      name: media-gateway
      namespace: default

  ingress:
    enabled: false
```

### Routing Model

Two routing modes are supported:
- Gateway API HTTPRoute (default)
- Kubernetes Ingress (optional)

Important behavior:
- HTTPRoute templates exist for Jellyfin, Plex, Prowlarr, Sonarr, Radarr, SABnzbd, Seerr, Tautulli, and Tdarr.
- Ingress templates currently exist for Jellyfin, Plex, Prowlarr, Sonarr, Radarr, SABnzbd, and Seerr.
- If you use Ingress-only mode and enable Tautulli or Tdarr, no Ingress is currently rendered for those two apps.

Use only one routing mode at a time.

### Shared Media Storage

The chart creates a shared media PVC by default:

```yaml
shared:
  media:
    enabled: true
    accessMode: ReadWriteMany
    size: 500Gi
```

NFS-backed static PV mode:

```yaml
shared:
  media:
    nfs:
      enabled: true
      server: "192.168.1.100"
      path: "/mnt/media"
```

When NFS is enabled, static binding is used and `storageClass` is ignored.

### Default Hostnames

With defaults (`baseDomain: media.local`):
- `jellyfin.media.local`
- `plex.media.local`
- `prowlarr.media.local`
- `sonarr.media.local`
- `radarr.media.local`
- `sabnzbd.media.local`
- `tautulli.media.local`
- `seerr.media.local`
- `tdarr.media.local` (when enabled)

### Storage Paths Used by Apps

Shared library conventions:
- SABnzbd downloads: `/media/downloads`
- Sonarr library: `/media/tv`
- Radarr library: `/media/movies`
- Jellyfin library root: `/media`
- Plex library root: `/data` (same shared PVC mounted at a different path)
- Tdarr server/node media mount: `/media`
- Tdarr transcode cache: `/temp`

## Hardware Acceleration

### Jellyfin and Plex

Both support:
- Intel Quick Sync via `/dev/dri`
- NVIDIA GPU resources (`nvidia.com/gpu`)

Enable one acceleration mode per app at a time.

### Tdarr Node

Tdarr Node supports:
- Intel VAAPI via Intel device plugin resource (default `gpu.intel.com/i915`)
- NVIDIA GPU resources (`nvidia.com/gpu`)

The template merges acceleration-specific node selectors/tolerations/affinity with base scheduling settings.

## Real Homelab Overrides (Current)

From `homelab-cluster-apps-values/home-media-server/values.yaml`:
- `global.timezone`: `America/Phoenix`
- `global.baseDomain`: `homelab.rawlinsnet.net`
- Gateway parent ref: `homelab-gateway` in `default`
- `jellyfin.enabled: false`
- `plex.hardwareAcceleration.nvidia.enabled: true`
- `tdarr.enabled: true`
- `tdarrNode.enabled: true`
- Shared media NFS enabled (`192.168.42.50:/mnt/media/shared-media`)

## App Setup After First Deploy

Recommended initial app-side paths:

1. SABnzbd folders:
   - Temporary: `/media/downloads/incomplete`
   - Completed: `/media/downloads/complete`
2. Sonarr root folder: `/media/tv`
3. Radarr root folder: `/media/movies`
4. Jellyfin libraries: `/media/tv`, `/media/movies`
5. Plex libraries: `/data/tv`, `/data/movies`
6. Seerr: sign in against Jellyfin/Plex/Emby, then connect Sonarr and Radarr via their in-cluster service DNS (e.g. `http://<release>-sonarr:8989`, `http://<release>-radarr:7878`)

## Notable Per-App Options

- Plex claim token:

```yaml
plex:
  claimToken: "claim-xxxxxxxxxxxxxxxxxxxx"
```

- SABnzbd hostname allowlist extension:

```yaml
sabnzbd:
  hostnameWhitelist: "custom.domain.com,another.domain.com"
```

The chart auto-populates service DNS names and, when HTTPRoute is enabled, app hostnames.

- Extra volumes/mounts (pattern available on apps):

```yaml
sonarr:
  extraVolumes: []
  extraVolumeMounts: []
```

## Default Images

- `jellyfin/jellyfin:10.11.6`
- `ghcr.io/home-operations/plex:1.43.0`
- `ghcr.io/home-operations/prowlarr:2.3.3`
- `ghcr.io/home-operations/sonarr:4.0.16`
- `ghcr.io/home-operations/radarr:6.1.1`
- `ghcr.io/home-operations/sabnzbd:4.5.5`
- `ghcr.io/home-operations/tautulli:2.16.1`
- `ghcr.io/seerr-team/seerr:v3.4.1`
- `haveagitgat/tdarr:2.62.01`
- `haveagitgat/tdarr_node:2.62.01`

## Requirements

- Kubernetes cluster with dynamic storage and/or NFS access
- Helm 3.x
- Gateway API controller (for HTTPRoute mode) or an Ingress controller (for Ingress mode)
- GPU device plugin/runtime when enabling hardware acceleration

## Security Defaults

Most app pods default to:
- non-root runtime
- dropped Linux capabilities
- `seccompProfile: RuntimeDefault`

Tdarr server/node are more permissive by default because of transcoding/runtime constraints.

## Uninstall

```bash
helm uninstall media-stack -n home-media-server
```

PVC/PV cleanup is intentionally manual.

## License

MIT
