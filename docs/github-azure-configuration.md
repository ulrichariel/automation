# GitHub and Azure DevOps configuration for a public repository

This repository is designed for a **public GitHub source repository** with **Azure Pipelines** used as the CI/CD engine.

## 1) GitHub repository settings
Configure branch protection or a ruleset for `main` with at least the following:

- require a pull request before merging
- require at least 1 approving review
- require status checks to pass before merge
- select the Azure Pipeline validation check as a required status check
- block direct pushes to `main`
- disable force pushes to `main`
- optionally require conversation resolution before merge
- optionally prefer squash merge for a cleaner history

### Important sequence
GitHub only lets you require status checks that have already run successfully on the repository. The recommended sequence is:

1. connect the GitHub repo to Azure Pipelines
2. run the pipeline successfully once on `main`
3. add that Azure Pipeline check as a required GitHub status check

## 2) Azure DevOps pipeline settings
Recommended settings for the Azure Pipeline:

- YAML pipeline connected to the GitHub repo
- PR trigger enabled for `main` to run validation only
- merge-to-main trigger enabled for full build and deployment flow
- Azure DevOps environments created for `dev`, `qa`, and `prod`
- approvals/checks configured on `qa` and `prod`
- service connections or deployment credentials only used in post-merge stages

## 3) Fork PR security
For public repositories, treat pull requests from forks as **validation-only**.

Recommended controls:

- do not expose secrets to fork PR builds
- do not allow deployment stages to run on PR builds
- do not attach production-capable credentials to validation-only stages
- keep environment approvals/checks outside the PR path

This repository already reflects that model in the YAML pipeline:
- PRs run validation and security checks only
- build/package/deploy stages run only on trusted post-merge executions from `main`

## 4) Why this separation matters
This model provides three useful protections:

1. **branch governance** is enforced by GitHub, where the source of truth for merges lives
2. **release governance** is enforced by Azure DevOps environments, where deployments are approved
3. **fork PR safety** is preserved because untrusted code paths do not receive deployment secrets or trigger deployments
