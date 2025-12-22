# GitHub Actions

## Purpose

The **Build & Push** workflows builds the Docker image, runs tests, scans the image for vulnerabilities, and pushes it to the Harbor project `app`, `chaincode` or `services`.

The workflow runs automatically on every push to the `main` and `dev` branches when either the `code` or the workflow file itself changes.

***

## Triggers (e.g. ca-service)

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

1. Checkout Source
2. Node Setup and Tests
3. Docker Buildx and Harbor Login
4. Image Tag Calculation
5. Local Image Build (no push)
6. Trivy Setup
7. Trivy Image Scan (hard gate)
- Behavior:
  - Scans the built image for OS and library vulnerabilities with severity `CRITICAL`.
  - Uses `.trivyignore` in the repository root to ignore a defined set of upstream vulnerabilities that are already documented and allowlisted in Harbor.
  - If any other `CRITICAL` vulnerabilities remain, the step fails with exit code `1`, and the pipeline stops.
- This step is the **hard security gate** for the container image.
8. Trivy Filesystem Scan (Node – report only)
- Behavior:
  - Scans the Node.js project directory (including `package.json` and lockfiles) for library vulnerabilities (`HIGH` and `CRITICAL`).
  - Includes dev dependencies (e.g. Jest/ESLint) to provide a full picture of dependency risks.
  - Always returns success (`exit-code: 0`), so it does **not** break the build.
- This step acts as a **reporting radar** for Node dependencies, not as a deployment gate.
9. Build & Push Image to Harbor

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