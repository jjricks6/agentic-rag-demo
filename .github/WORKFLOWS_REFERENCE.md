# GitHub Actions Workflows Reference

Quick reference for working with the Terraform deployment workflows.

## Workflow Files

| File | Purpose | Auto-Deploy | Approval Required |
|------|---------|-------------|-------------------|
| `terraform-backend.yml` | Deploy Terraform backend | ✅ Yes (on push) | ❌ No |
| `terraform-dev.yml` | Deploy dev environment | ✅ Yes (on push) | ❌ No |
| `terraform-prod.yml` | Deploy prod environment | ❌ Manual only | ✅ Yes |

## Triggering Workflows

### Automatic Triggers

**Backend**: Pushes or PRs affecting backend
```bash
git add terraform/backend/
git commit -m "Update backend"
git push
```

**Dev Environment**: Pushes or PRs affecting dev
```bash
git add terraform/environments/dev/
git commit -m "Update dev environment"
git push
```

### Manual Triggers

**Production Deployment**:
1. Go to **Actions** → **Terraform Prod Environment**
2. Click **Run workflow**
3. Select **apply**
4. Click **Run workflow**
5. Approve when prompted

## Workflow Stages

### 1. Pull Request
```
PR Created → Plan → Comment on PR
```
- Runs terraform plan
- Posts plan as PR comment
- No apply

### 2. Push to Main (Dev/Backend)
```
Push → Plan → Apply → Save Outputs
```
- Runs terraform plan
- Auto-applies changes
- Saves config artifacts

### 3. Production Deployment
```
Manual Trigger → Plan → Wait for Approval → Apply → Save Outputs
```
- Requires manual trigger
- Requires approval
- Protected environment

## Viewing Results

### Workflow Status
```
Repository → Actions → Click workflow run
```

### Deployment Outputs
```
Workflow run → Summary → View outputs
```

### Download Artifacts
```
Workflow run → Artifacts section → Download
```

## Common Commands

### View GitHub Actions Locally (act)
```bash
# Install act
brew install act

# List workflows
act -l

# Run workflow locally
act push -W .github/workflows/terraform-dev.yml
```

### Check Workflow Syntax
```bash
# Install actionlint
brew install actionlint

# Lint workflows
actionlint .github/workflows/*.yml
```

## Environment Variables

Set these in workflow files:

```yaml
env:
  AWS_REGION: us-east-1      # AWS region
  TF_VERSION: 1.5.0          # Terraform version
```

## Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |

## Workflow Paths

Workflows trigger on changes to these paths:

**Backend**:
- `terraform/backend/**`
- `.github/workflows/terraform-backend.yml`

**Dev**:
- `terraform/environments/dev/**`
- `terraform/modules/**`
- `.github/workflows/terraform-dev.yml`

**Prod**:
- `terraform/environments/prod/**`
- `terraform/modules/**`
- `.github/workflows/terraform-prod.yml`

## Troubleshooting

### Workflow not triggering?
1. Check path filters match changed files
2. Verify branch is `main`
3. Check GitHub Actions are enabled

### Plan succeeds but apply fails?
1. Check AWS credentials
2. Verify IAM permissions
3. Check Terraform state lock

### Can't approve production?
1. Set up production environment in Settings
2. Add yourself as required reviewer
3. Check environment protection rules

## Best Practices

### ✅ DO
- Review plans before merging PRs
- Test in dev before deploying prod
- Use descriptive commit messages
- Monitor workflow runs
- Check CloudWatch after deployment

### ❌ DON'T
- Skip plan review
- Deploy directly to prod
- Commit sensitive data
- Disable required reviews

## Cost Monitoring

### Check Actions Usage
```
Settings → Billing → Plans and usage
```

### Optimize Costs
- Use `paths` filters to reduce runs
- Cache dependencies
- Destroy dev when not needed

## Advanced Usage

### Run specific job
```yaml
# In workflow file, add condition
if: github.event.inputs.job == 'plan'
```

### Add notifications
```yaml
- name: Slack notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Add approval timeout
```yaml
environment:
  name: production
timeout-minutes: 30
```

## Quick Links

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AWS Configure Credentials](https://github.com/aws-actions/configure-aws-credentials)

---

**Last Updated**: 2026-02-05
