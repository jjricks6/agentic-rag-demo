# Terraform Helper Scripts

Utility scripts for managing Terraform configuration and deployment.

## Available Scripts

### generate-backend-configs.sh

Automatically generates `backend.hcl` files for all environments from the backend Terraform outputs.

**Usage**:
```bash
cd terraform/scripts
./generate-backend-configs.sh
```

**What it does**:
1. Reads backend Terraform outputs (bucket name, table name, region)
2. Generates `environments/dev/backend.hcl`
3. Generates `environments/prod/backend.hcl`

**When to use**:
- After creating the backend infrastructure
- When setting up on a new machine
- When backend configuration changes

**Output files**:
- `environments/dev/backend.hcl`
- `environments/prod/backend.hcl`

**Note**: `backend.hcl` files are gitignored (account-specific), while `backend.hcl.example` files are tracked.

## Manual Backend Configuration

If you prefer to configure manually:

### Option 1: Use backend.hcl file

```bash
cd environments/dev

# Copy example
cp backend.hcl.example backend.hcl

# Edit with your values
# nano backend.hcl

# Initialize
terraform init -backend-config=backend.hcl
```

### Option 2: Command-line flags

```bash
cd environments/dev

terraform init \
  -backend-config="bucket=YOUR_BUCKET" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_TABLE"
```

### Option 3: Environment variables (for CI/CD)

```bash
export TF_CLI_ARGS_init="-backend-config=bucket=YOUR_BUCKET -backend-config=key=dev/terraform.tfstate"
terraform init
```

## CI/CD Integration

For GitHub Actions, use secrets and workflow variables:

```yaml
- name: Terraform Init
  run: |
    terraform init \
      -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
      -backend-config="key=${{ env.ENVIRONMENT }}/terraform.tfstate" \
      -backend-config="region=${{ secrets.AWS_REGION }}" \
      -backend-config="dynamodb_table=${{ secrets.TF_STATE_LOCK_TABLE }}"
```

## Troubleshooting

### Script fails: "Backend not deployed"

**Solution**: Deploy backend first
```bash
cd ../backend
terraform init
terraform apply
cd ../scripts
./generate-backend-configs.sh
```

### Script fails: "Could not retrieve backend outputs"

**Solution**: Ensure backend is applied
```bash
cd ../backend
terraform apply
terraform output
```

### backend.hcl not found during init

**Solution**: Generate or copy from example
```bash
# Option 1: Auto-generate
cd terraform/scripts
./generate-backend-configs.sh

# Option 2: Manual copy
cd terraform/environments/dev
cp backend.hcl.example backend.hcl
# Edit with your values
```

---

**Last Updated**: 2026-02-05
