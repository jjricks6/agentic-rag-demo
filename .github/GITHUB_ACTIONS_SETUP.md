# GitHub Actions Setup Guide

This guide will help you set up automated Terraform deployments using GitHub Actions.

## Cost Information

### GitHub Actions Pricing
- **Public repositories**: ✅ **FREE** unlimited minutes
- **Private repositories**:
  - 2,000 minutes/month FREE
  - $0.008/minute after free tier
  - Each Terraform deployment: ~2-5 minutes
  - **You get 400-1000 free deployments per month!**

## Prerequisites

1. ✅ GitHub account
2. ✅ AWS account with appropriate permissions
3. ✅ This repository pushed to GitHub

## Setup Steps

### Step 1: Create AWS IAM User for GitHub Actions

1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Users** → **Create user**
3. Username: `github-actions-terraform`
4. Click **Next**
5. Select **Attach policies directly**
6. Attach these policies:
   - `AdministratorAccess` (for demo/dev - restrict in production!)
   - Or create a custom policy with only needed permissions
7. Click **Next** → **Create user**
8. Click on the user → **Security credentials** → **Create access key**
9. Select **Application running outside AWS**
10. Click **Next** → **Create access key**
11. **⚠️ IMPORTANT**: Save the Access Key ID and Secret Access Key - you'll need them next!

### Step 2: Add AWS Credentials to GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these secrets:

   **Secret 1: AWS_ACCESS_KEY_ID**
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: Your AWS Access Key ID from Step 1

   **Secret 2: AWS_SECRET_ACCESS_KEY**
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: Your AWS Secret Access Key from Step 1

### Step 3: (Optional) Set Up Production Environment Protection

For the production workflow, enable environment protection:

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name: `production`
4. Click **Configure environment**
5. Enable **Required reviewers**
6. Add yourself as a reviewer
7. Click **Save protection rules**

This ensures production deployments require manual approval! ✅

### Step 4: Enable GitHub Actions

1. Go to **Settings** → **Actions** → **General**
2. Under **Actions permissions**, select:
   - **Allow all actions and reusable workflows**
3. Under **Workflow permissions**, select:
   - **Read and write permissions**
4. Click **Save**

### Step 5: Deploy the Backend First

The backend must be deployed before environments can be deployed.

1. Push code to `main` branch:
   ```bash
   git add .
   git commit -m "Add GitHub Actions workflows"
   git push origin main
   ```

2. Go to **Actions** tab in GitHub
3. Click **Terraform Backend Setup** workflow
4. Click **Run workflow** → **Run workflow**
5. Wait for completion (~2 minutes)

### Step 6: Deploy Dev Environment

After backend is deployed:

1. Make any change to `terraform/environments/dev/**`
2. Push to `main` branch
3. GitHub Actions will automatically:
   - Run `terraform plan`
   - Run `terraform apply`
   - Save agent config as artifact

**Or manually trigger**:
1. Go to **Actions** → **Terraform Dev Environment**
2. Click **Run workflow**

### Step 7: Deploy Production (Manual Approval Required)

Production deployments require manual approval:

1. Go to **Actions** → **Terraform Prod Environment**
2. Click **Run workflow**
3. Select **apply** from dropdown
4. Click **Run workflow**
5. Wait for plan to complete
6. **Review and approve** the deployment
7. Production will be deployed after approval

## Workflow Overview

### 1. `terraform-backend.yml`
- **Triggers**: Push to `main` or PR affecting `terraform/backend/**`
- **Actions**: Plans and applies backend infrastructure
- **Auto-apply**: Yes (on push to main)

### 2. `terraform-dev.yml`
- **Triggers**: Push to `main` or PR affecting dev environment
- **Actions**: Plans and applies dev infrastructure
- **Auto-apply**: Yes (on push to main)
- **Artifacts**: Saves `agent-config-dev.json`

### 3. `terraform-prod.yml`
- **Triggers**: Manual workflow dispatch
- **Actions**: Plans and applies prod infrastructure
- **Auto-apply**: No - requires manual approval via GitHub environment
- **Artifacts**: Saves `agent-config-prod.json`

## Workflow Behavior

### On Pull Request
- ✅ Runs `terraform plan`
- ✅ Posts plan as PR comment
- ❌ Does NOT apply changes

### On Push to Main
- ✅ Runs `terraform plan`
- ✅ Runs `terraform apply` (dev and backend only)
- ✅ Saves outputs as artifacts
- ❌ Production requires manual trigger + approval

### Manual Workflow Dispatch
- ✅ Can manually trigger any workflow
- ✅ Production requires approval

## Monitoring Deployments

### View Workflow Runs
1. Go to **Actions** tab
2. Click on a workflow run
3. View logs for each step

### Download Artifacts
1. Go to completed workflow run
2. Scroll to **Artifacts** section
3. Download `agent-config-dev.json` or `agent-config-prod.json`

### View Deployment Summary
- Each successful deployment shows a summary with:
  - Agent ID
  - Bucket names
  - Console links

## Security Best Practices

### ✅ DO:
- Use GitHub Secrets for AWS credentials
- Enable branch protection on `main`
- Require code review before merging
- Use production environment protection
- Regularly rotate AWS access keys
- Use least-privilege IAM policies

### ❌ DON'T:
- Commit AWS credentials to code
- Use root AWS account credentials
- Auto-apply production without review
- Share access keys

## Troubleshooting

### Workflow fails with "Access Denied"
- Check AWS credentials in GitHub Secrets
- Verify IAM user has required permissions
- Ensure credentials haven't expired

### "Backend initialization required"
- Deploy backend first using `terraform-backend.yml`
- Check backend was successfully created in AWS

### "No changes to apply"
- No infrastructure changes detected
- This is normal if nothing changed

### Production deployment not triggering
- Production requires manual workflow dispatch
- Go to Actions → Terraform Prod → Run workflow → Select "apply"
- Approve deployment when prompted

## Cost Optimization Tips

1. **Use workflow conditions** - Only run when necessary files change
2. **Cache Terraform** - Already configured in workflows
3. **Destroy dev environment** - When not needed:
   ```bash
   terraform destroy
   ```
4. **Monitor GitHub Actions usage**:
   - Go to Settings → Billing → Plans and usage
   - View Actions minutes used

## Advanced Configuration

### Customize Terraform Version
Edit `TF_VERSION` in workflow files:
```yaml
env:
  TF_VERSION: 1.5.0  # Change to desired version
```

### Add Additional Environments
1. Copy `terraform-dev.yml`
2. Rename to `terraform-staging.yml`
3. Update paths and environment names
4. Create `terraform/environments/staging/`

### Add Slack Notifications
Add this step after apply:
```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment completed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Next Steps

After successful deployment:

1. ✅ Build Lambda functions
2. ✅ Update Lambda code via GitHub Actions
3. ✅ Test agent via AWS CLI
4. ✅ Deploy Streamlit UI
5. ✅ Monitor CloudWatch logs

## Support

If you encounter issues:
1. Check workflow logs in GitHub Actions
2. Verify AWS credentials and permissions
3. Check Terraform state in S3
4. Review CloudWatch logs for runtime errors

---

**Last Updated**: 2026-02-05
