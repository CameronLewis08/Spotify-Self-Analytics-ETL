# ── RDS Security Group ────────────────────────────────────────────────────────
# TODO: Create resource "aws_security_group" "rds"
#   - name        = "spotify-etl-rds-sg"
#   - description = "PostgreSQL from EC2 security group only"
#   - vpc_id      = var.vpc_id
#   - ingress block: from_port = 5432, to_port = 5432, protocol = "tcp"
#                    security_groups = [var.ec2_sg_id]   ← key: reference the SG, not a CIDR
#                    description     = "PostgreSQL from EC2 only"
#   - egress block:  from_port = 0, to_port = 0, protocol = "-1"
#                    cidr_blocks = ["0.0.0.0/0"]
#
#   Why security_groups instead of cidr_blocks?
#   Using the EC2 security group ID as the source means only your EC2 instance can
#   reach port 5432 — not any IP in the subnet, not even your laptop. More precise.

# ── DB Subnet Group ───────────────────────────────────────────────────────────
# TODO: Create resource "aws_db_subnet_group" "main"
#   - name       = "spotify-etl-db-subnet-group"
#   - subnet_ids = var.private_subnet_ids
#   - tags: Name = "spotify-etl-db-subnet-group"
#
#   Why: AWS requires RDS subnet groups to span ≥2 Availability Zones, even for
#   single-AZ instances. The two private subnets from the networking module satisfy this.

# ── RDS PostgreSQL Instance ───────────────────────────────────────────────────
# TODO: Create resource "aws_db_instance" "postgres"
#   - identifier        = "spotify-etl-db"
#   - engine            = "postgres"
#   - engine_version    = "16.3"
#   - instance_class    = "db.t3.micro"      ← free-tier eligible; upgrade later if needed
#   - allocated_storage = 20                  ← GB; gp2 minimum is 20
#   - storage_type      = "gp2"
#   - db_name           = "spotify_etl"
#   - username          = "postgres"
#   - password          = var.db_password
#   - db_subnet_group_name   = aws_db_subnet_group.main.name
#   - vpc_security_group_ids = [aws_security_group.rds.id]
#   - skip_final_snapshot    = true    ← OK for dev; set false in production
#   - publicly_accessible    = false   ← IMPORTANT: keep RDS private; EC2 is the only gateway in
#   - tags: Name = "spotify-etl-db"
