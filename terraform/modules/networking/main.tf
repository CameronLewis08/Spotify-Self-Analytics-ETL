# ── VPC ──────────────────────────────────────────────────────────────────────
# TODO: Create resource "aws_vpc" "main"
#   - cidr_block: "10.0.0.0/16"  (65,536 IPs — plenty of headroom)
#   - enable_dns_hostnames = true  ← RDS endpoint won't resolve inside the VPC without this
#   - enable_dns_support   = true  ← required for the Route 53 resolver to work

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
# TODO: Create resource "aws_internet_gateway" "main"
#   - Attach to the VPC: vpc_id = aws_vpc.main.id
#   - The IGW is the VPC's front door to the public internet.
#   - Without it, EC2 can't reach the Spotify API or download apt/dnf packages.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# ── Public Subnet ─────────────────────────────────────────────────────────────
# TODO: Create resource "aws_subnet" "public"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.1.0/24"  (256 IPs)
#   - availability_zone: "us-east-1a"
#   - map_public_ip_on_launch = true  ← EC2 gets a routable IP automatically on launch

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}


# ── Private Subnets (for RDS) ─────────────────────────────────────────────────
# TODO: Create resource "aws_subnet" "private_a"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.2.0/24", availability_zone: "us-east-1a"
#

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

# TODO: Create resource "aws_subnet" "private_b"
#   - vpc_id: aws_vpc.main.id
#   - cidr_block: "10.0.3.0/24", availability_zone: "us-east-1b"
#

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}

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

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}


# TODO: Create resource "aws_route_table_association" "public"
#   - subnet_id:      aws_subnet.public.id
#   - route_table_id: aws_route_table.public.id
#   - Without this association, the route table exists but isn't applied to any subnet.

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}