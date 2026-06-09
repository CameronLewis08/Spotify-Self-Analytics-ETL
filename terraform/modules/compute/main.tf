# ── AMI Data Source ───────────────────────────────────────────────────────────
# Looks up the latest Amazon Linux 2023 AMI dynamically so you never hardcode a stale ID.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── SSH Key Pair ──────────────────────────────────────────────────────────────
# TODO: Create resource "aws_key_pair" "etl"
#   - key_name   = "spotify-etl-key"
#   - public_key = file("~/.ssh/spotify-etl.pub")
#
#   First generate a key pair locally (run this in PowerShell / Git Bash):
#     ssh-keygen -t rsa -b 4096 -f ~/.ssh/spotify-etl
#   This creates two files: spotify-etl (private) and spotify-etl.pub (public).
#   Terraform uploads the PUBLIC key to AWS. The private key stays on your machine.
#   To SSH in later: ssh -i ~/.ssh/spotify-etl ec2-user@<ec2_public_ip>

# ── Security Group (EC2) ──────────────────────────────────────────────────────
# TODO: Create resource "aws_security_group" "ec2"
#   - name        = "spotify-etl-ec2-sg"
#   - description = "SSH from developer IP only; all outbound"
#   - vpc_id      = var.vpc_id
#   - ingress block: from_port = 22, to_port = 22, protocol = "tcp"
#                    cidr_blocks = [var.your_ip]
#                    description = "SSH from developer IP only"
#   - egress block:  from_port = 0, to_port = 0, protocol = "-1"
#                    cidr_blocks = ["0.0.0.0/0"]
#                    description = "All outbound — needed to reach Spotify API, apt, pip"

# ── EC2 Instance ──────────────────────────────────────────────────────────────
# TODO: Create resource "aws_instance" "etl"
#   - ami                    = data.aws_ami.amazon_linux_2023.id
#   - instance_type          = "t3.medium"   (2 vCPU, 4 GB — comfortable for Airflow + dbt)
#   - subnet_id              = var.public_subnet_id
#   - vpc_security_group_ids = [aws_security_group.ec2.id]
#   - iam_instance_profile   = var.instance_profile
#   - key_name               = aws_key_pair.etl.key_name
#   - root_block_device block: volume_size = 20, volume_type = "gp3"
#   - tags: Name = "spotify-etl"
