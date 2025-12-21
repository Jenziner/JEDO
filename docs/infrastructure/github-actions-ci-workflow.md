# GitHub Actions CI Workflow – `ca-service`

## Purpose

The **Build & Push ca-service** workflow builds the `ca-service` Docker image, runs tests, scans the image for vulnerabilities, and pushes it to the Harbor project `services`.

The workflow runs automatically on every push to the `main` and `dev` branches when either the `ca-service` code or the workflow file itself changes.

***

## Triggers

```yaml
on:
  push:
    branches:
      - main
      - dev
    paths:
      - "services/ca-service/**"
      - ".github/workflows/build-ca-service.yml"
```

- Only runs when:
  - The `ca-service` service changes (`services/ca-service/**`), or  
  - The CI workflow definition is updated.

***

## Job: `build-test-push`

### Runner and Environment

- Runner: `ubuntu-latest`
- Global environment variables:

```yaml
env:
  HARBOR_REGISTRY: harbor.jedo.me
  HARBOR_PROJECT: services
  SERVICE_NAME: ca-service
```

These values define where the built image will be pushed in Harbor.

***

## Pipeline Steps

### 1. Checkout Source

- Uses `actions/checkout@v4`.
- Fetches the repository contents for the current commit.

### 2. Node Setup and Tests

- Uses `actions/setup-node@v4` with `node-version: 20`.
- In `services/ca-service`:
  - `npm ci` installs dependencies in a clean way.
  - `npm test` runs the unit tests.
- Ensures the service builds and tests pass before building the container image.

### 3. Docker Buildx and Harbor Login

- `docker/setup-buildx-action@v3` enables Docker Buildx for building images.
- `docker/login-action@v3` logs into Harbor using a robot account:
  - Username: `${{ secrets.HARBOR_ROBOT_SERVICES }}`
  - Password: `${{ secrets.HARBOR_ROBOT_SECRET_SERVICES }}`

This allows the workflow to push images to `harbor.jedo.me`.

### 4. Image Tag Calculation

- Step `Set image tags` computes a short SHA from `GITHUB_SHA`:

```bash
SHA_SHORT=${GITHUB_SHA::7}
echo "sha_tag=${SHA_SHORT}" >> $GITHUB_OUTPUT
```

- The resulting `sha_tag` is used as a unique image tag (e.g. `ca-service:d9747e8`).

### 5. Local Image Build (no push)

- Runs `docker build` in `services/ca-service`:

```bash
docker build \
  -t $HARBOR_REGISTRY/$HARBOR_PROJECT/$SERVICE_NAME:${{ steps.vars.outputs.sha_tag }} \
  .
```

- Uses `services/ca-service/Dockerfile`.
- The Dockerfile installs only production dependencies (via `npm install --omit=dev`), so dev dependencies (Jest/ESLint etc.) do not end up in the runtime image.

### 6. Trivy Setup

- Uses `aquasecurity/setup-trivy@v0.2.0` with `version: v0.56.1`.
- Installs Trivy and enables caching to speed up vulnerability scans.

### 7. Trivy Image Scan (hard gate)

- Uses `aquasecurity/trivy-action@master` with:

```yaml
with:
  scan-type: image
  image-ref: ${{ env.HARBOR_REGISTRY }}/${{ env.HARBOR_PROJECT }}/${{ env.SERVICE_NAME }}:${{ steps.vars.outputs.sha_tag }}
  format: table
  vuln-type: os,library
  severity: CRITICAL
  ignore-unfixed: true
  trivyignores: .trivyignore
  exit-code: 1
  timeout: 5m
  hide-progress: true
  skip-setup-trivy: true
```

- Behavior:
  - Scans the built image for OS and library vulnerabilities with severity `CRITICAL`.
  - Uses `.trivyignore` in the repository root to ignore a defined set of upstream vulnerabilities (Go runtime, Fabric/Fabric-CA, jsrsasign) that are already documented and allowlisted in Harbor.
  - If any other `CRITICAL` vulnerabilities remain, the step fails with exit code `1`, and the pipeline stops.
- This step is the **hard security gate** for the container image.

### 8. Trivy Filesystem Scan (Node – report only)

- Uses `aquasecurity/trivy-action@master` with:

```yaml
with:
  scan-type: fs
  scan-ref: ./services/ca-service
  vuln-type: library
  severity: HIGH,CRITICAL
  ignore-unfixed: true
  exit-code: 0
  skip-setup-trivy: true
```

- Behavior:
  - Scans the Node.js project directory (including `package.json` and lockfiles) for library vulnerabilities (`HIGH` and `CRITICAL`).
  - Includes dev dependencies (e.g. Jest/ESLint) to provide a full picture of dependency risks.
  - Always returns success (`exit-code: 0`), so it does **not** break the build.
- This step acts as a **reporting radar** for Node dependencies, not as a deployment gate.

### 9. Build & Push Image to Harbor

- Uses `docker/build-push-action@v5` with:

```yaml
with:
  context: ./services/ca-service
  file: ./services/ca-service/Dockerfile
  push: true
  tags: |
    ${{ env.HARBOR_REGISTRY }}/${{ env.HARBOR_PROJECT }}/${{ env.SERVICE_NAME }}:${{ steps.vars.outputs.sha_tag }}
    ${{ env.HARBOR_REGISTRY }}/${{ env.HARBOR_PROJECT }}/${{ env.SERVICE_NAME }}:latest
  cache-from: type=gha
  cache-to: type=gha,mode=max
```

- Rebuilds the image using Buildx and pushes it to Harbor with:
  - A commit-based tag (`<sha_tag>`).
  - The `latest` tag.
- Uses GitHub Actions cache for faster rebuilds.

***

## Security Model

The workflow applies a clear separation of responsibilities:

- **CI / Trivy image scan = hard gate**
  - The image scan with `exit-code: 1` decides whether an image is allowed to be built and pushed.
  - Only explicitly documented upstream vulnerabilities are ignored via `.trivyignore`, matching the Harbor CVE allowlist for this service.

- **CI / Trivy filesystem scan = advisory**
  - The filesystem scan surfaces all relevant Node.js library vulnerabilities (including dev dependencies) but does not block the pipeline.
  - This supports long‑term dependency hygiene without stopping deployments.

- **Harbor**
  - For this project, Harbor’s “Prevent vulnerable images from running” is disabled, so Harbor does not block pushes or deployments.
  - Harbor remains the place to view scan results and the per‑project CVE allowlist, while the actual enforcement happens in CI.