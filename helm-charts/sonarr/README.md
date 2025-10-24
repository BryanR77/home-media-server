# Sonarr Helm Chart for OKD/OpenShift

This Helm chart deploys [Sonarr](https://sonarr.tv/) using the [LinuxServer.io](https://docs.linuxserver.io/images/docker-sonarr/) container image on OKD 4.19 or OpenShift Container Platform.

## Features

- **OKD/OpenShift Compatible**: Fully compatible with OKD 4.19 security requirements
- **Rootless Operation**: Runs as non-root user with appropriate security contexts
- **Persistent Storage**: Configurable persistent volumes for configuration, TV shows, and downloads
- **OpenShift Routes**: Native OpenShift routing with TLS termination
- **Security**: Implements restricted security context constraints
- **Scalability**: Optional horizontal pod autoscaling and pod disruption budgets

## Prerequisites

- OKD 4.19+ or OpenShift Container Platform 4.19+
- Helm 3.x
- Persistent storage available in the cluster
- Appropriate permissions to create resources in the target namespace

## Installation

### Quick Start

```bash
# Add the helm repository (if you have one)
# helm repo add home-media-server <repository-url>

# Install with default values
helm install sonarr ./sonarr

# Install with custom values
helm install sonarr ./sonarr -f my-values.yaml
```

### Configuration

#### Basic Configuration

Create a custom values file:

```yaml
# values-production.yaml
env:
  TZ: "America/New_York"

persistence:
  config:
    size: 2Gi
  tv:
    size: 500Gi
    existingClaim: "shared-media-storage"
  downloads:
    size: 100Gi
    existingClaim: "shared-downloads-storage"

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 200m
    memory: 512Mi

route:
  host: "sonarr.apps.mycluster.example.com"
```

Install with custom configuration:

```bash
helm install sonarr ./sonarr -f values-production.yaml
```

#### Storage Configuration

The chart supports three types of persistent storage:

1. **Config Storage** (`/config`): Sonarr configuration and database
2. **TV Storage** (`/tv`): TV show library location
3. **Downloads Storage** (`/downloads`): Download client output directory

You can either:
- Let the chart create new PVCs (default)
- Use existing PVCs by setting `existingClaim`
- Disable specific volumes if not needed

### OKD/OpenShift Specific Features

#### Security Context Constraints

The chart is designed to work with the `restricted-v2` SCC by default. The pod runs as:
- Non-root user (UID 568)
- Read-only root filesystem
- Dropped capabilities
- seccomp profile enabled

#### Routes vs Ingress

For OKD/OpenShift, use Routes instead of Ingress:

```yaml
# Disable Ingress (default)
ingress:
  enabled: false

# Enable OpenShift Route (default)
route:
  enabled: true
  host: "sonarr.apps.mycluster.example.com"
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### Advanced Configuration

#### Network Policies

Enable network policies for additional security:

```yaml
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
```

#### Pod Disruption Budget

For high availability:

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

#### Horizontal Pod Autoscaler

For automatic scaling (not typically needed for Sonarr):

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80
```

## Upgrading

```bash
# Upgrade to a new version
helm upgrade sonarr ./sonarr -f values-production.yaml

# Check upgrade status
helm status sonarr
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall sonarr
```

**Note**: This will not delete persistent volume claims. Delete them manually if needed:

```bash
oc delete pvc -l app.kubernetes.io/instance=sonarr
```

## Configuration Parameters

### Image Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Sonarr image repository | `lscr.io/linuxserver/sonarr` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Environment Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env.TZ` | Timezone | `UTC` |
| `env.PUID` | User ID | `568` |
| `env.PGID` | Group ID | `568` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8989` |

### Route Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `route.enabled` | Enable OpenShift Route | `true` |
| `route.host` | Route hostname | `""` (auto-generated) |
| `route.tls.termination` | TLS termination | `edge` |

### Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.config.enabled` | Enable config persistence | `true` |
| `persistence.config.size` | Config PVC size | `1Gi` |
| `persistence.tv.enabled` | Enable TV persistence | `true` |
| `persistence.tv.size` | TV PVC size | `100Gi` |
| `persistence.downloads.enabled` | Enable downloads persistence | `true` |
| `persistence.downloads.size` | Downloads PVC size | `50Gi` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.runAsUser` | Run as user ID | `568` |
| `podSecurityContext.runAsGroup` | Run as group ID | `568` |
| `podSecurityContext.fsGroup` | Filesystem group ID | `568` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem | `true` |

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure the security context is properly configured
   - Check that the storage class supports the required access modes
   - Verify PVC ownership and permissions

2. **Pod Fails to Start**
   - Check pod logs: `oc logs deployment/sonarr-sonarr`
   - Verify resource limits and requests
   - Ensure persistent volumes are available

3. **Route Not Accessible**
   - Verify route creation: `oc get route`
   - Check route configuration and TLS settings
   - Ensure service is properly configured

### Debugging Commands

```bash
# Check pod status
oc get pods -l app.kubernetes.io/name=sonarr

# View pod logs
oc logs -l app.kubernetes.io/name=sonarr -f

# Describe pod for events
oc describe pod -l app.kubernetes.io/name=sonarr

# Check persistent volumes
oc get pvc -l app.kubernetes.io/instance=sonarr

# Verify route
oc get route sonarr
```

## Support

For issues specific to:
- **Sonarr application**: Visit [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- **LinuxServer container**: Check [LinuxServer.io documentation](https://docs.linuxserver.io/images/docker-sonarr/)
- **OKD/OpenShift**: Consult [OKD documentation](https://docs.okd.io/)

## License

This Helm chart is released under the MIT License.