# Milestone 1 — Infrastructure (Terraform) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Scope:** Tasks 1–7 create scaffold files — agent executes these. Tasks 8–10 require AWS credentials and human confirmation — follow them manually.

**Goal:** Five Terraform modules so a single `terraform apply` provisions VPC, S3 bucket, IAM role, RDS PostgreSQL instance, and EC2 instance — with SSH access confirmed.

**Architecture:** Root `terraform/main.tf` already exists (scaffolded). Create child modules under `terraform/modules/`. Dependency order: networking (no deps) → storage + IAM (no deps from networking) → compute (needs networking + IAM) → database (needs networking + compute's SG ID). Remote state migrates to S3 after the first successful apply.

**Tech Stack:** Terraform CLI ≥1.5, AWS provider ~>5.0, Amazon VPC / S3 / IAM / RDS PostgreSQL 15 (db.t3.micro) / EC2 (t3.medium)

---

## Task 1: AWS Account Prerequisites (Manual)

No files. Browser + terminal only. **Complete these before writing any Terraform.**

- [ ] **Step 1: Create AWS account**

  https://aws.amazon.com → "Create an AWS Account". A credit card is required, but every resource in this milestone fits the AWS Free Tier (12 months).

- [ ] **Step 2: Enable MFA on root user**

  AWS Console (top-right username) → Security credentials → Multi-factor authentication → Assign MFA device. Use an authenticator app (Google Authenticator, Authy). **Never use root credentials day-to-day** — MFA is just the safety net.

- [ ] **Step 3: Create IAM user for Terraform**

  IAM → Users → Create user → name: `terraform-user` → Permissions: Attach policies directly → `AdministratorAccess` → Create user.

  Then: click the user → Security credentials → Create access key → Use case: **Command Line Interface (CLI)** → copy **Access Key ID** and **Secret Access Key**. This is the only time the secret is shown.

- [ ] **Step 4: Configure AWS CLI**

  ```bash
  aws configure
  ```
  Enter: Access Key ID, Secret Access Key, default region `us-east-1`, output `json`.

- [ ] **Step 5: Verify credentials**

  ```bash
  aws sts get-caller-identity
  ```
  Expected:
  ```json
  {
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
  }
  ```
  Save the 12-digit `Account` value — it becomes part of your S3 bucket name.

- [ ] **Step 6: Install Terraform CLI**

  Download from https://developer.hashicorp.com/terraform/downloads → add to PATH.
  ```bash
  terraform version
  ```
  Expected: `Terraform v1.x.x`

- [ ] **Step 7: Create `terraform/terraform.tfvars`**

  ```bash
  cp terraform/terraform.tfvars.example terraform/terraform.tfvars
  ```
  Fill in the three values. Find your IP with:
  ```bash
  curl checkip.amazonaws.com
  ```
  Append `/32` to that IP (e.g. `1.2.3.4/32`).

---

## Task 2: Scaffold `modules/networking`

**Files:**
- Create: `terraform/modules/networking/variables.tf`
- Create: `terraform/modules/networking/main.tf`
- Create: `terraform/modules/networking/outputs.tf`

- [ ] **Step 1: Create `variables.tf`**

```hcl
# Networking is self-contained — it defines its own CIDR blocks.
# No input variables needed. Other modules consume its outputs.
```

- [ ] **Step 2: Create `main.tf`**

```hcl
# ── VPC ──────────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_vpc" "main"
#   - cidr_block: "10.0.0.0/16"  (65,536 IPs — plenty of headroom)
#   - enable_dns_hostnames = true  ← RDS endpoint won't resolve inside the VPC without this
#   - enable_dns_support   = true  ← required for the Route 53 resolver to work

# ── Internet Gateway ──────────────────────────────────────────────────────────
# TODO: Create resource "aws_internet_gateway" "main"
#   - Attach to the VPC: vpc_id = aws_vpc.main.id
#   - The IGW is the VPC's front door to the public internet.
#   - Without it, EC2 can't reach the Spotify API or download apt/dnf packages.

# ── Public Subnet ─────────────────────────────────────────────────────────────
# TODO: Create resource "aws_subnet" "public"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.1.0/24"  (256 IPs)
#   - availability_zone: "us-east-1a"
#   - map_public_ip_on_launch = true  ← EC2 gets a routable IP automatically on launch

# ── Private Subnets (for RDS) ─────────────────────────────────────────────────
# TODO: Create resource "aws_subnet" "private_a"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.2.0/24", availability_zone: "us-east-1a"
#
# TODO: Create resource "aws_subnet" "private_b"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.3.0/24", availability_zone: "us-east-1b"
#
#   Why two private subnets in different AZs?
#   RDS subnet groups require subnets in ≥2 Availability Zones — this is an AWS constraint,
#   not optional. RDS itself will use only one AZ unless you enable Multi-AZ.

# ── Route Table ───────────────────────────────────────────────────────────────
# TODO: Create resource "aws_route_table" "public"
#   - vpc_id: aws_vpc.main.id
#   - Add a route block:
#       cidr_block = "0.0.0.0/0"
#       gateway_id = aws_internet_gateway.main.id
#   - This tells all internet-bound traffic from the public subnet to go through the IGW.

# TODO: Create resource "aws_route_table_association" "public"
#   - subnet_id:      aws_subnet.public.id
#   - route_table_id: aws_route_table.public.id
#   - Without this association, the route table exists but isn't applied to any subnet.
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "vpc_id" {
  description = "VPC ID — passed to compute and database modules"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID — EC2 instance goes here"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs in ≥2 AZs — required by the RDS subnet group"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
```

- [ ] **Step 4: Run `terraform init`**

  ```bash
  cd terraform && terraform init
  ```
  Expected: `Terraform has been successfully initialized!`
  (Run this once after creating the first module; subsequent modules don't need a re-init until `apply`.)

- [ ] **Step 5: Commit**

  ```bash
  git add terraform/modules/networking/
  git commit -m "feat: scaffold networking module"
  ```

---

## Task 3: Scaffold `modules/storage`

**Files:**
- Create: `terraform/modules/storage/variables.tf`
- Create: `terraform/modules/storage/main.tf`
- Create: `terraform/modules/storage/outputs.tf`

- [ ] **Step 1: Create `variables.tf`**

```hcl
variable "account_id" {
  description = "AWS account ID — appended to bucket name to guarantee global uniqueness"
  type        = string
}
```

- [ ] **Step 2: Create `main.tf`**

```hcl
# ── S3 Bucket ──────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket" "raw"
#   - bucket: "spotify-analytics-${var.account_id}"
#   - S3 bucket names are globally unique across ALL AWS accounts worldwide.
#     Appending your account ID is the standard pattern to avoid name collisions.

# ── Versioning ─────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket_versioning" "raw"
#   - bucket: aws_s3_bucket.raw.id
#   - versioning_configuration { status = "Enabled" }
#   - NOTE: Since AWS provider v4+, versioning is a separate resource, not a nested block
#     inside aws_s3_bucket. The Terraform docs will show you the correct structure.
#   - Why version? Protects against accidental overwrites of raw JSON files.

# ── Server-Side Encryption ─────────────────────────────────────────────────────
# TODO: Create resource "aws_s3_bucket_server_side_encryption_configuration" "raw"
#   - bucket: aws_s3_bucket.raw.id
#   - Use SSE-S3 (AES256) — no extra cost, no KMS key to manage.
#   - rule block → apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "bucket_name" {
  description = "S3 bucket name — used in .env (S3_BUCKET) and by the S3Loader"
  value       = aws_s3_bucket.raw.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN — used by IAM module to scope the policy to this bucket only"
  value       = aws_s3_bucket.raw.arn
}
```

- [ ] **Step 4: Commit**

  ```bash
  git add terraform/modules/storage/
  git commit -m "feat: scaffold storage module"
  ```

---

## Task 4: Scaffold `modules/iam`

**Files:**
- Create: `terraform/modules/iam/variables.tf`
- Create: `terraform/modules/iam/main.tf`
- Create: `terraform/modules/iam/outputs.tf`

- [ ] **Step 1: Create `variables.tf`**

```hcl
variable "s3_bucket_arn" {
  description = "ARN of the raw S3 bucket — scopes the IAM policy to this bucket only"
  type        = string
}
```

- [ ] **Step 2: Create `main.tf`**

```hcl
# IAM has three parts that work together:
#   Role → defines WHO can assume it (trust policy)
#   Policy → defines WHAT actions are allowed (permission policy)
#   Instance Profile → wrapper that lets an EC2 instance USE the role

# ── IAM Role ──────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_role" "ec2_role"
#   - name: "spotify-analytics-ec2-role"
#   - assume_role_policy: a JSON trust policy that allows EC2 to assume this role.
#     Use jsonencode() to write it inline:
#       Effect    = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#       Action    = "sts:AssumeRole"

# ── IAM Policy ────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_policy" "ec2_policy"
#   - name: "spotify-analytics-ec2-policy"
#   - policy: a JSON document with two statements:
#
#     Statement 1 — S3 access:
#       Effect   = "Allow"
#       Actions  = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
#       Resource = ["${var.s3_bucket_arn}", "${var.s3_bucket_arn}/*"]
#       Why /*?  Bucket-level ARN grants ListBucket; object-level ARN (/*) grants Get/Put/Delete.
#       Both are needed.
#
#     Statement 2 — RDS IAM auth:
#       Effect   = "Allow"
#       Action   = "rds-db:connect"
#       Resource = "*"

# ── Attach Policy to Role ─────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_role_policy_attachment" "ec2_attach"
#   - role:       aws_iam_role.ec2_role.name
#   - policy_arn: aws_iam_policy.ec2_policy.arn

# ── Instance Profile ──────────────────────────────────────────────────────────
# TODO: Create resource "aws_iam_instance_profile" "ec2_profile"
#   - name: "spotify-analytics-ec2-profile"
#   - role: aws_iam_role.ec2_role.name
#   - EC2 instances can't directly use an IAM Role — they need this wrapper.
#     This profile name is what gets attached to the EC2 instance in the compute module.
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "instance_profile_name" {
  description = "Instance profile name — attached to EC2 in the compute module"
  value       = aws_iam_instance_profile.ec2_profile.name
}
```

- [ ] **Step 4: Commit**

  ```bash
  git add terraform/modules/iam/
  git commit -m "feat: scaffold iam module"
  ```

---

## Task 5: Scaffold `modules/compute`

**Files:**
- Create: `terraform/modules/compute/variables.tf`
- Create: `terraform/modules/compute/main.tf`
- Create: `terraform/modules/compute/outputs.tf`

- [ ] **Step 1: Generate SSH key pair (before writing Terraform)**

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/spotify_ec2
  ```
  This creates:
  - `~/.ssh/spotify_ec2` — private key. **Never share or commit this.**
  - `~/.ssh/spotify_ec2.pub` — public key. Referenced by Terraform.

- [ ] **Step 2: Create `variables.tf`**

```hcl
variable "vpc_id" {
  description = "VPC to place the EC2 security group in"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet where the EC2 instance will be launched"
  type        = string
}

variable "your_ip" {
  description = "Your public IP in CIDR notation (e.g. 1.2.3.4/32) — SSH restricted to this IP only"
  type        = string
}

variable "instance_profile" {
  description = "IAM instance profile name to attach — grants EC2 access to S3 and RDS"
  type        = string
}
```

- [ ] **Step 3: Create `main.tf`**

```hcl
# ── Security Group ─────────────────────────────────────────────────────────────
# TODO: Create resource "aws_security_group" "ec2_sg"
#   - name:   "spotify-analytics-ec2-sg"
#   - vpc_id: var.vpc_id
#
#   Ingress rule 1 — SSH:
#     protocol = "tcp", from_port = 22, to_port = 22
#     cidr_blocks = [var.your_ip]   ← YOUR IP ONLY
#     Exposing port 22 to 0.0.0.0/0 means bots will hammer it within hours. Restrict to your IP.
#
#   Ingress rule 2 — Airflow UI:
#     protocol = "tcp", from_port = 8080, to_port = 8080
#     cidr_blocks = [var.your_ip]   ← YOUR IP ONLY
#
#   Egress rule — allow all outbound:
#     protocol = "-1", from_port = 0, to_port = 0
#     cidr_blocks = ["0.0.0.0/0"]
#     EC2 needs outbound internet to call the Spotify API and download packages.

# ── Key Pair ───────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_key_pair" "deployer"
#   - key_name:   "spotify-analytics-key"
#   - public_key: file("~/.ssh/spotify_ec2.pub")
#   - The private key stays on your laptop. Terraform stores only the public key.
#   - If you lose the private key, you lose SSH access — recreate and re-apply.

# ── EC2 Instance ───────────────────────────────────────────────────────────────
# TODO: Create resource "aws_instance" "airflow"
#   - ami: look up the Amazon Linux 2023 AMI ID for us-east-1.
#     AWS Console → EC2 → Launch Instance → search "Amazon Linux 2023" → note the AMI ID.
#     Alternatively use a data source to fetch it dynamically:
#       data "aws_ami" "amzn_linux" {
#         most_recent = true
#         owners      = ["amazon"]
#         filter { name = "name", values = ["al2023-ami-*-x86_64"] }
#       }
#     Then: ami = data.aws_ami.amzn_linux.id
#
#   - instance_type:           "t3.medium"  (Airflow needs ~2 GB RAM; t3.micro OOMs the scheduler)
#   - subnet_id:               var.public_subnet_id
#   - vpc_security_group_ids:  [aws_security_group.ec2_sg.id]
#   - key_name:                aws_key_pair.deployer.key_name
#   - iam_instance_profile:    var.instance_profile
#
#   root_block_device block:
#     volume_size = 20   (GiB — enough for Docker images + Airflow logs)
#     volume_type = "gp3"
```

- [ ] **Step 4: Create `outputs.tf`**

```hcl
output "public_ip" {
  description = "EC2 public IP — SSH target and Airflow UI hostname"
  value       = aws_instance.airflow.public_ip
}

output "ec2_sg_id" {
  description = "EC2 security group ID — passed to database module to whitelist port 5432"
  value       = aws_security_group.ec2_sg.id
}
```

- [ ] **Step 5: Commit**

  ```bash
  git add terraform/modules/compute/
  git commit -m "feat: scaffold compute module"
  ```

---

## Task 6: Scaffold `modules/database`

**Files:**
- Create: `terraform/modules/database/variables.tf`
- Create: `terraform/modules/database/main.tf`
- Create: `terraform/modules/database/outputs.tf`

- [ ] **Step 1: Create `variables.tf`**

```hcl
variable "vpc_id" {
  description = "VPC to place the RDS security group in"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs in ≥2 different AZs — required by the DB subnet group"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "EC2 security group ID — only this SG is allowed inbound on port 5432"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
```

- [ ] **Step 2: Create `main.tf`**

```hcl
# ── DB Subnet Group ────────────────────────────────────────────────────────────
# TODO: Create resource "aws_db_subnet_group" "main"
#   - name:       "spotify-analytics-db-subnet-group"
#   - subnet_ids: var.private_subnet_ids
#   - RDS requires a subnet group to know which subnets it can use.
#     Using PRIVATE subnets ensures RDS has no public endpoint — only reachable from EC2.

# ── Security Group ─────────────────────────────────────────────────────────────
# TODO: Create resource "aws_security_group" "rds_sg"
#   - name:   "spotify-analytics-rds-sg"
#   - vpc_id: var.vpc_id
#
#   Ingress rule — PostgreSQL from EC2 only:
#     protocol              = "tcp"
#     from_port             = 5432
#     to_port               = 5432
#     source_security_group_id = var.ec2_sg_id   ← NOT cidr_blocks — reference the SG directly
#
#   This is the core security constraint: ONLY the EC2 instance can query the database.
#   Never open 5432 to 0.0.0.0/0 — that exposes your Postgres to the entire internet.
#   No egress rules needed: RDS doesn't initiate outbound connections.

# ── RDS Instance ───────────────────────────────────────────────────────────────
# TODO: Create resource "aws_db_instance" "postgres"
#   - identifier:          "spotify-analytics-db"
#   - engine:              "postgres"
#   - engine_version:      "15"
#   - instance_class:      "db.t3.micro"   ← Free Tier eligible
#   - allocated_storage:   20              (GiB, minimum)
#   - db_name:             "spotify_analytics"
#   - username:            "postgres"
#   - password:            var.db_password
#   - db_subnet_group_name:    aws_db_subnet_group.main.name
#   - vpc_security_group_ids:  [aws_security_group.rds_sg.id]
#   - publicly_accessible:     false   ← CRITICAL: keeps RDS private, only EC2 can reach it
#   - skip_final_snapshot:     true    ← fine for a personal project; set false for production
#   - multi_az:                false   ← single-AZ, saves cost
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "endpoint" {
  description = "RDS hostname — used in dbt profiles.yml and DATABASE_URL in .env"
  value       = aws_db_instance.postgres.address
  # .address = hostname only (e.g. foo.abc123.us-east-1.rds.amazonaws.com)
  # .endpoint = hostname:port — use .address so you can set the port separately
}
```

- [ ] **Step 4: Commit**

  ```bash
  git add terraform/modules/database/
  git commit -m "feat: scaffold database module"
  ```

---

## Task 7: Create `terraform/terraform.tfvars.example`

**Files:**
- Create: `terraform/terraform.tfvars.example`

- [ ] **Step 1: Create the file**

```hcl
# Copy this file to terraform.tfvars and fill in your values.
# terraform.tfvars is gitignored — never commit real credentials.

aws_region = "us-east-1"

# Your 12-digit AWS account ID.
# Find it: aws sts get-caller-identity --query Account --output text
account_id = "123456789012"

# Your current public IP + /32 to restrict SSH to only you.
# Find it: curl checkip.amazonaws.com  → append /32
your_ip = "1.2.3.4/32"

# RDS PostgreSQL master password.
# Rules: 8+ chars, no @, ", or /
# Alternatively pass via env var to avoid it ever touching disk:
#   export TF_VAR_db_password="your-password"
db_password = "changeme123!"
```

- [ ] **Step 2: Commit**

  ```bash
  git add terraform/terraform.tfvars.example
  git commit -m "feat: add terraform.tfvars.example"
  ```

---

## Task 8: Fill In All Modules and Validate (Manual)

**Before this task:** Complete Tasks 2–7 (scaffolds exist). Now you write the actual resource blocks.

Work through each module's `main.tf`. For each `# TODO:` block, write the resource. Use the AWS Terraform provider docs as your reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

- [ ] **Step 1: Fill in `modules/networking/main.tf`** — `aws_vpc`, `aws_internet_gateway`, 3× `aws_subnet`, `aws_route_table`, `aws_route_table_association`

- [ ] **Step 2: Fill in `modules/storage/main.tf`** — `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`

- [ ] **Step 3: Fill in `modules/iam/main.tf`** — `aws_iam_role`, `aws_iam_policy`, `aws_iam_role_policy_attachment`, `aws_iam_instance_profile`

- [ ] **Step 4: Fill in `modules/compute/main.tf`** — `aws_security_group`, `aws_key_pair`, `aws_instance`

- [ ] **Step 5: Fill in `modules/database/main.tf`** — `aws_db_subnet_group`, `aws_security_group`, `aws_db_instance`

- [ ] **Step 6: Validate all modules**

  ```bash
  cd terraform && terraform validate
  ```
  Expected: `Success! The configuration is valid.`

  If you get errors: Terraform error messages include the file name, line number, and a description. Read them carefully — they're almost always telling you exactly what's wrong.

- [ ] **Step 7: Review the plan (no changes yet)**

  ```bash
  terraform plan
  ```
  Scan the output. You should see roughly 18–22 resources planned:
  - Networking: 1 VPC, 3 subnets, 1 IGW, 1 route table, 1 association
  - Storage: 1 S3 bucket, 1 versioning config, 1 encryption config
  - IAM: 1 role, 1 policy, 1 attachment, 1 instance profile
  - Compute: 1 security group, 1 key pair, 1 EC2 instance
  - Database: 1 subnet group, 1 security group, 1 RDS instance

  If the count is wildly off, scroll through the plan output and find what's missing or unexpected.

---

## Task 9: First `terraform apply` (Manual)

- [ ] **Step 1: Apply**

  ```bash
  terraform apply
  ```
  Type `yes` when prompted. **RDS takes 5–10 minutes** — this is normal, don't interrupt it.

  Expected final line:
  ```
  Apply complete! Resources: N added, 0 changed, 0 destroyed.
  ```

- [ ] **Step 2: Capture outputs into `.env`**

  ```bash
  terraform output
  ```
  Copy the three values into your `.env` file:

  | Terraform output | `.env` key |
  |---|---|
  | `ec2_public_ip` | used for SSH and Airflow UI URL |
  | `rds_endpoint` | `DB_HOST` and `DATABASE_URL` |
  | `s3_bucket_name` | `S3_BUCKET` |

- [ ] **Step 3: SSH into EC2**

  ```bash
  ssh -i ~/.ssh/spotify_ec2 ec2-user@<ec2_public_ip>
  ```
  Expected: you get an EC2 shell prompt.

  If connection times out: your IP may have changed since you set `your_ip` in `terraform.tfvars`. Run `curl checkip.amazonaws.com` — if the IP changed, update `your_ip`, run `terraform apply` again to update the security group rule.

- [ ] **Step 4: Verify internet from EC2**

  ```bash
  curl -s https://api.spotify.com/v1/
  ```
  Expected: some JSON (or an auth error) — not a `curl: (6) Could not resolve host` error.

- [ ] **Step 5: Verify RDS from EC2**

  ```bash
  sudo dnf install -y postgresql15
  psql -h <rds_endpoint> -U postgres -d spotify_analytics
  ```
  Enter your `db_password`. Expected: `spotify_analytics=#` prompt.

  If connection refused: your RDS security group ingress rule may not reference the correct EC2 security group ID. Check `terraform output` and re-read the `rds_sg` TODO in the database module.

- [ ] **Step 6: Exit and commit milestone**

  ```bash
  exit  # leave the EC2 SSH session
  git add terraform/modules/
  git commit -m "milestone(M1): all modules filled in, apply successful, SSH verified"
  ```

---

## Task 10: Migrate Terraform State to S3 Remote Backend (Manual)

After the first apply, move state to S3 so it's safe if your laptop dies and shareable with future teammates.

- [ ] **Step 1: Create a separate S3 bucket for Terraform state**

  This is a different bucket from the raw-data bucket — state files contain sensitive info (RDS passwords, etc.) and should be isolated.

  ```bash
  aws s3api create-bucket \
    --bucket "spotify-analytics-tfstate-<account_id>" \
    --region us-east-1

  aws s3api put-bucket-versioning \
    --bucket "spotify-analytics-tfstate-<account_id>" \
    --versioning-configuration Status=Enabled
  ```

- [ ] **Step 2: Add backend block to `terraform/main.tf`**

  Find the `# TODO: after your first terraform apply...` comment in `main.tf`. Fill in the `backend "s3"` block inside the `terraform {}` block:

  ```hcl
  backend "s3" {
    bucket = "spotify-analytics-tfstate-<account_id>"
    key    = "spotify-analytics/terraform.tfstate"
    region = "us-east-1"
  }
  ```

- [ ] **Step 3: Migrate state**

  ```bash
  terraform init
  ```
  Terraform detects the new backend and prompts: `"Do you want to copy existing state to the new backend? (yes)"` → type `yes`.

  Expected: `Successfully configured the backend "s3"!`

- [ ] **Step 4: Verify state file is in S3**

  ```bash
  aws s3 ls s3://spotify-analytics-tfstate-<account_id>/spotify-analytics/
  ```
  Expected: `terraform.tfstate` listed.

- [ ] **Step 5: Commit**

  ```bash
  git add terraform/main.tf
  git commit -m "feat: migrate terraform state to S3 remote backend"
  ```

---

## Milestone 1 Complete ✓

You should now have:
- All 5 Terraform modules written and applied
- EC2 accessible via SSH
- RDS reachable from EC2 on port 5432
- S3 bucket provisioned
- Terraform state stored remotely in S3

**Next:** Milestone 2 — Airflow on EC2 (install Docker + Docker Compose on the EC2 instance, get both DAGs loading in the Airflow UI).
