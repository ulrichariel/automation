# Assignment 2 – NestJS Hello World with Azure DevOps CI/CD

## 1) Overview
This repository is a minimal **NestJS** application designed to demonstrate a simple but disciplined delivery workflow for the Release Manager / DevOps Engineer assessment.

The application is intentionally small:
- `GET /` returns a Hello World payload
- `GET /health` returns health and release metadata
- `GET /health/live` returns a liveness response
- `GET /health/ready` returns a readiness response suitable for smoke validation

The focus of this submission is not application complexity. The focus is the **build, validation, security, release, deployment, promotion, and documentation structure**.

## 2) Solution summary
The solution includes:
- a minimal NestJS application
- a YAML-based Azure DevOps pipeline (`azure-pipelines.yml`)
- automatic deployment to **dev** after merge to `main`
- controlled promotion of the **same built Docker image** to **QA** and **production**
- a **Gitleaks** secret scan that fails the pipeline if a secret is detected
- an **npm audit** dependency gate that blocks on critical findings and publishes a report for review
- a **Trivy** container image scan that blocks on critical image vulnerabilities and publishes a vulnerability report
- Docker health checks and post-deployment smoke validation
- documented **GitHub branch protection / ruleset** expectations for `main`
- release-version and commit traceability through image tags, metadata artifacts, and the `/health` endpoint

## 3) Repository structure
```text
.
├── .github/
│   └── pull_request_template.md
├── Dockerfile
├── README.md
├── azure-pipelines.yml
├── package.json
├── package-lock.json
├── tsconfig.json
├── tsconfig.build.json
├── nest-cli.json
├── jest.config.ts
├── .gitleaks.toml
├── deploy/
│   ├── dev.env
│   ├── qa.env
│   └── prod.env
├── docs/
│   └── github-azure-configuration.md
├── scripts/
│   ├── deploy.sh
│   └── smoke-test.sh
└── src/
    ├── app.controller.ts
    ├── app.controller.spec.ts
    ├── app.module.ts
    ├── app.service.ts
    ├── health.controller.ts
    ├── health.controller.spec.ts
    └── main.ts
```

## 4) Prerequisites
- Node.js 20+
- npm
- Docker
- Azure DevOps pipeline agent capable of running Docker
- Azure DevOps **Environments** configured for `dev`, `qa`, and `prod`
- a public **GitHub** repository connected to Azure Pipelines

## 5) Setup steps
```bash
npm ci
```

## 6) Run locally
### Run directly with NestJS
```bash
npm run build
npm run start:prod
```

Default local endpoints:
- `http://localhost:3000/`
- `http://localhost:3000/health`
- `http://localhost:3000/health/live`
- `http://localhost:3000/health/ready`

### Run with Docker
```bash
docker build --build-arg BUILD_ID=local --build-arg SOURCE_COMMIT=local -t nest-hello-release-demo:local .
./scripts/deploy.sh dev nest-hello-release-demo:local deploy/dev.env nest-hello-release-demo-dev 3000
./scripts/smoke-test.sh http://localhost:3000/health/ready dev local ready
```

## 7) How the pipeline works
The pipeline is split into five stages:

### Stage 1 – Validate
Runs on pull requests and on `main`:
- install dependencies with `npm ci`
- run unit tests
- compile the NestJS application
- run **Gitleaks** secret scan
- generate an **npm audit** report and block on critical dependency vulnerabilities

If any blocking checks fail, the pipeline stops before image creation.

### Stage 2 – Build, scan, and package
Runs on merge to `main` only:
- build a Docker image
- tag it with the Azure DevOps build ID
- stamp image metadata with the build ID and source commit
- run **Trivy** against the built image and publish the scan report
- save the image as a `.tar` artifact
- publish release metadata and security artifacts

### Stage 3 – Deploy to Dev
Runs automatically after build:
- downloads the published image artifact
- loads the exact same image
- deploys to the `dev` environment using `deploy/dev.env`
- waits for the Docker health check to pass
- runs a smoke test against `GET /health/ready`

### Stage 4 – Deploy to QA
Runs after successful dev deployment:
- targets the Azure DevOps `qa` environment
- promotes the **same image artifact** that was deployed to dev
- deploys it using `deploy/qa.env`
- waits for container health
- runs the smoke test again against `GET /health/ready`

### Stage 5 – Deploy to Production
Runs after successful QA deployment:
- targets the Azure DevOps `prod` environment
- promotes the **same approved image artifact** to production
- deploys it using `deploy/prod.env`
- waits for container health
- runs the smoke test against `GET /health/ready`

**Approval model:** the intended governance control is to configure **approval/checks on the Azure DevOps `qa` and `prod` environments**. That keeps approval tied to the target environment rather than to an ad hoc manual task in YAML.

## 8) Deployment trigger model
- **Pull request to `main`**: validation only
- **Merge to `main`**: validation, build, deploy to dev, then promotion to QA and production through Azure DevOps environment-level approval/checks

This structure keeps deployment out of the PR path while still validating every change before merge.

## 9) Environment handling
This repository uses three environments:
- **dev**
- **qa**
- **prod**

Environment-specific behavior is controlled through environment files:
- `deploy/dev.env`
- `deploy/qa.env`
- `deploy/prod.env`

The application reads `APP_ENV`, and the `/health` endpoint returns both the active environment, release version, and source commit. This makes environment separation and artifact traceability visible during smoke testing and post-deployment verification.

### Promotion model
The pipeline promotes the **same built Docker image** from dev to QA to production. It does **not** rebuild separately per environment. Only configuration changes by environment.

This is intentional because it demonstrates a cleaner release pattern:
- build once
- validate once
- scan once
- promote the same immutable artifact forward
- keep environment-specific configuration separate from the artifact

### Environment realism note
For this assessment, the environments are intentionally lightweight so the solution stays easy to review and reproduce. The separation demonstrated here is:
- distinct Azure DevOps deployment environments (`dev`, `qa`, and `prod`)
- separate environment configuration files
- separate container names and ports
- the same immutable image promoted forward

In a fuller hosted implementation, these would map to distinct infrastructure targets with managed secrets, stronger network isolation, environment-specific approvals, and platform-level observability.

## 10) Security checks implemented
### 1. Gitleaks
I chose **Gitleaks** as the first mandatory security control.

Why:
- low friction to integrate
- directly relevant to CI/CD hygiene
- fails early before a change is promoted further

### 2. npm audit
I added `npm audit` to generate a dependency vulnerability report and enforce a blocking threshold at **critical** severity. In a mature workflow, this threshold would typically be paired with a formal exception process for accepted risks.

### 3. Trivy image scan
I added **Trivy** after the Docker build to generate an image vulnerability report and enforce a blocking threshold at **critical** severity.

### Expected action if a security control fails
If a security check fails:
1. stop promotion immediately
2. remediate the issue
3. rotate credentials if applicable
4. rebuild and rerun the pipeline

## 11) GitHub branch protection and Azure status checks
Because the source repository is hosted on **GitHub**, branch governance should be implemented through **GitHub branch protection or rulesets**, with Azure Pipelines supplying the required status checks.

Recommended settings for `main`:
- direct pushes disabled
- pull request required for merge
- minimum **1 approving review**
- Azure Pipeline validation required before merge
- squash merge preferred
- optional: linked work item or issue required

**Important setup note:** run the Azure Pipeline successfully at least once against the GitHub repository before selecting it as a required status check in GitHub. GitHub only lets you require checks that have already reported a successful status for that repo.

## 12) Fork PR security for a public GitHub repo
For a public GitHub repository, pull requests from forks should be treated as **validation-only**.

This pipeline already avoids deployments on pull requests. In Azure DevOps, the recommended additional control is to **keep secrets unavailable to fork PR builds** and to avoid exposing any deployment-capable credentials during PR validation.

That means:
- PR builds validate code, tests, and security checks only
- build and deployment stages run on merge to `main`, not on fork PRs
- Azure service connections, secret variables, and environment approvals are only used after merge in trusted pipeline runs

See `docs/github-azure-configuration.md` for the exact recommended GitHub and Azure DevOps settings.

## 13) Assumptions, shortcuts, and trade-offs
This exercise is intentionally simple. I made the following design choices:

- I kept the application minimal because the objective is the delivery workflow, not feature complexity.
- I used **Docker image artifact promotion** rather than a live container registry to keep the submission easy to review and reproduce.
- I used environment files for configuration rather than a managed secret store because this is a small demo.
- I documented GitHub branch protection / ruleset expectations because actual enforcement depends on repository settings rather than files in source control.
- I added three practical security controls rather than a full enterprise security stack to keep the signal clear and explainable. The dependency and image scans publish reports and use a blocking threshold so the workflow can support risk-based review rather than only pass/fail output.
- I committed a lockfile and used `npm ci` so local runs, the Docker build, and the pipeline all use the same dependency graph.
- The QA and production environments assume Azure DevOps environment approvals/checks are configured outside YAML.

## 14) What I would improve in a fuller implementation
If this were expanded into a mature production implementation, I would add:
- Azure Key Vault or secure variable groups for secrets
- a real container registry rather than artifact-based image transfer
- infrastructure-as-code for environment provisioning
- richer observability with structured logs, metrics, traces, and alerts
- progressive deployment strategies such as blue/green or canary
- stronger release metadata, automated release notes, and CAB evidence generation
- rollback automation and post-release review workflow
- a non-root container user (appuser with dropped privileges)
- Dockerfile build determinism
- CI/deploy workflow separation
