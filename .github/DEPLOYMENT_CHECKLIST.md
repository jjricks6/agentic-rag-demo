# GitHub Actions Deployment Checklist

Quick checklist to get your infrastructure deployed via GitHub Actions.

## ⚡ Quick Setup (5 minutes)

### Step 1: Create AWS IAM User
- [ ] Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
- [ ] Create user: `github-actions-terraform`
- [ ] Attach policy: `AdministratorAccess` (or custom policy)
- [ ] Create access key for "Application outside AWS"
- [ ] Save Access Key ID and Secret Access Key

### Step 2: Configure GitHub Secrets
- [ ] Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
- [ ] Add secret: `AWS_ACCESS_KEY_ID` = [your access key]
- [ ] Add secret: `AWS_SECRET_ACCESS_KEY` = [your secret key]

### Step 3: Enable Bedrock Model Access
- [ ] Go to [Bedrock Console](https://console.aws.amazon.com/bedrock)
- [ ] Click **Model access**
- [ ] Enable: `Claude 3.5 Sonnet`
- [ ] Enable: `Titan Embeddings Text v2`
- [ ] Wait for approval (usually instant)

### Step 4: Push to GitHub
```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

### Step 5: Watch Deployment
- [ ] Go to **Actions** tab
- [ ] Watch **Terraform Backend Setup** run
- [ ] Watch **Terraform Dev Environment** run
- [ ] Check for green checkmarks ✅

### Step 6: Verify Deployment
- [ ] Download `agent-config-dev.json` artifact
- [ ] Check [AWS Bedrock Console](https://console.aws.amazon.com/bedrock)
- [ ] Verify agent appears in Agents list

## 🎯 What Gets Deployed Automatically

### On First Push to Main:
1. **Backend** (2-3 minutes):
   - S3 bucket for Terraform state
   - DynamoDB table for state locking
   - Encryption and versioning

2. **Dev Environment** (3-5 minutes):
   - S3 buckets (documents + vectors)
   - S3 Vector index
   - Bedrock agent with action groups
   - 2 Lambda functions (placeholders)
   - IAM roles and policies
   - CloudWatch logs and dashboard

**Total time**: ~5-8 minutes ⏱️

### On Subsequent Pushes:
- Only changed resources are updated
- Typically completes in 1-3 minutes

## 🔒 Production Environment (Manual)

Production requires manual trigger and approval:

### Step 1: Set Up Environment Protection
- [ ] Go to **Settings** → **Environments**
- [ ] Create environment: `production`
- [ ] Enable **Required reviewers**
- [ ] Add yourself as reviewer

### Step 2: Deploy Production
- [ ] Go to **Actions** → **Terraform Prod Environment**
- [ ] Click **Run workflow**
- [ ] Select **apply**
- [ ] Review plan when job pauses
- [ ] Approve deployment
- [ ] Monitor completion

## 📊 Monitoring

### View Workflow Runs
```
Actions tab → Select workflow → View logs
```

### Check AWS Resources
```bash
# After dev deployment completes
aws bedrock-agent list-agents --region us-east-1

# Check S3 buckets
aws s3 ls | grep agentic-rag-demo

# View agent details
aws bedrock-agent get-agent --agent-id <AGENT_ID>
```

### Check Costs
```
AWS Console → Billing → Cost Explorer
```

## ⚠️ Troubleshooting

### Workflow fails: "Access Denied"
**Solution**: Check GitHub Secrets are set correctly
```
Settings → Secrets and variables → Actions → Verify secrets exist
```

### Workflow fails: "Backend not initialized"
**Solution**: Backend must deploy first
```
Actions → Terraform Backend Setup → Run workflow
```

### Workflow fails: "Model not accessible"
**Solution**: Enable Bedrock model access
```
AWS Console → Bedrock → Model access → Enable models
```

### Workflow runs but nothing happens
**Solution**: Check path filters
```yaml
# In workflow file, ensure your changes match paths:
paths:
  - 'terraform/environments/dev/**'
```

## 💰 Cost Expectations

### GitHub Actions (FREE)
- Public repo: ∞ unlimited minutes
- Private repo: 2,000 minutes/month
- Each deployment: ~2-5 minutes
- **400-1000 free deployments/month**

### AWS Infrastructure
**Dev environment**:
- Base cost: ~$3/month
- Usage cost: ~$10-20/month
- **Total: ~$13-23/month**

**Prod environment**:
- Base cost: ~$11-20/month
- Usage cost: ~$80-250/month
- **Total: ~$100-270/month**

## ✅ Success Criteria

After deployment completes, verify:

- [ ] Workflow shows green checkmark ✅
- [ ] Agent appears in Bedrock console
- [ ] S3 buckets created
- [ ] S3 Vector bucket and index created
- [ ] Lambda functions deployed
- [ ] CloudWatch log group exists
- [ ] CloudWatch dashboard visible
- [ ] No errors in CloudWatch logs

## 🚀 Next Steps

After infrastructure is deployed:

1. **Build Lambda Functions**
   ```bash
   cd agent/lambda
   # Implement document_handler.py
   # Implement search_handler.py
   ./build.sh
   ```

2. **Deploy Updated Lambda Code**
   ```bash
   # Push Lambda code changes
   git add agent/lambda/
   git commit -m "Add Lambda function implementations"
   git push  # Triggers GitHub Actions
   ```

3. **Test the Agent**
   ```bash
   aws bedrock-agent-runtime invoke-agent \
     --agent-id <AGENT_ID> \
     --agent-alias-id <ALIAS_ID> \
     --session-id test-session \
     --input-text "Hello, can you help me?" \
     response.json
   ```

4. **Deploy Streamlit UI**
   ```bash
   cd ui/streamlit-app
   streamlit run app.py
   ```

## 📚 Additional Resources

- [GITHUB_ACTIONS_SETUP.md](.github/GITHUB_ACTIONS_SETUP.md) - Complete setup guide
- [WORKFLOWS_REFERENCE.md](.github/WORKFLOWS_REFERENCE.md) - Workflow reference
- [../docs/SETUP.md](../docs/SETUP.md) - Local development setup
- [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) - Deployment strategies

---

**Estimated Setup Time**: 10-15 minutes
**First Deployment**: 5-8 minutes
**Subsequent Deployments**: 1-3 minutes
