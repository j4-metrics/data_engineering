terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    atlas = {
      source  = "ariga/atlas"
      version = "0.3.0"
    }
  }
}

// Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

// This data object is going to be
// holding all the available availability
// zones in our defined region
data "aws_availability_zones" "available" {
  state = "available"
}

// Create a data object called "ubuntu" that holds the latest
// Ubuntu 20.04 server AMI
data "aws_ami" "ubuntu" {
  // We want the most recent AMI
  most_recent = "true"

  // We are filtering through the names of the AMIs. We want the 
  // Ubuntu 20.04 server
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  // We are filtering through the virtualization type to make sure
  // we only find AMIs with a virtualization type of hvm
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  // This is the ID of the publisher that created the AMI. 
  // The publisher of Ubuntu 20.04 LTS Focal is Canonical 
  // and their ID is 099720109477
  owners = ["099720109477"]
}

// Create a VPC named "cred_card_vpc"
resource "aws_vpc" "cred_card_vpc" {
  // Here we are setting the CIDR block of the VPC
  // to the "vpc_cidr_block" variable
  cidr_block = "10.0.0.0/16"
  // We want DNS hostnames enabled for this VPC
  enable_dns_hostnames = true

  // We are tagging the VPC with the name "cred_card_vpc"
  tags = {
    Name = "cred_card_vpc"
  }
}

// Create an internet gateway named "cred_card_igw"
// and attach it to the "cred_card_vpc" VPC
resource "aws_internet_gateway" "cred_card_igw" {
  // Here we are attaching the IGW to the 
  // cred_card_vpc VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // We are tagging the IGW with the name cred_card_igw
  tags = {
    Name = "cred_card_igw"
  }
}

// Create a group of public subnets based on the variable subnet_count.public
resource "aws_subnet" "cred_card_public_subnet" {
  // count is the number of resources we want to create
  // here we are referencing the subnet_count.public variable which
  // current assigned to 1 so only 1 public subnet will be created
  count = 1

  // Put the subnet into the "cred_card_vpc" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // We are grabbing a CIDR block from the "public_subnet_cidr_blocks" variable
  // since it is a list, we need to grab the element based on count,
  // since count is 1, we will be grabbing the first cidr block 
  // which is going to be 10.0.1.0/24
  cidr_block = "10.0.1.0/24"

  // We are grabbing the availability zone from the data object we created earlier
  // Since this is a list, we are grabbing the name of the element based on count,
  // so since count is 1, and our region is us-east-2, this should grab us-east-2a
  availability_zone = data.aws_availability_zones.available.names[count.index]

  // We are tagging the subnet with a name of "cred_card_public_subnet_" and
  // suffixed with the count
  tags = {
    Name = "cred_card_public_subnet_${count.index}"
  }
}

// Create a group of private subnets based on the variable subnet_count.private
resource "aws_subnet" "cred_card_private_subnet" {
  // count is the number of resources we want to create
  // here we are referencing the subnet_count.private variable which
  // current assigned to 2, so 2 private subnets will be created
  count = 2

  // Put the subnet into the "cred_card_vpc" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // We are grabbing a CIDR block from the "private_subnet_cidr_blocks" variable
  // since it is a list, we need to grab the element based on count,
  // since count is 2, the first subnet will grab the CIDR block 10.0.101.0/24
  // and the second subnet will grab the CIDR block 10.0.102.0/24
  cidr_block = var.private_subnet_cidr_blocks[count.index]

  // We are grabbing the availability zone from the data object we created earlier
  // Since this is a list, we are grabbing the name of the element based on count,
  // since count is 2, and our region is us-east-2, the first subnet should
  // grab us-east-2a and the second will grab us-east-2b
  availability_zone = data.aws_availability_zones.available.names[count.index]

  // We are tagging the subnet with a name of "cred_card_private_subnet_" and
  // suffixed with the count
  tags = {
    Name = "cred_card_private_subnet_${count.index}"
  }
}

// Create a public route table named "cred_card_public_rt"
resource "aws_route_table" "cred_card_public_rt" {
  // Put the route table in the "cred_card_vpc" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // Since this is the public route table, it will need
  // access to the internet. So we are adding a route with
  // a destination of 0.0.0.0/0 and targeting the Internet 	 
  // Gateway "cred_card_igw"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cred_card_igw.id
  }
}

// Here we are going to add the public subnets to the 
// "cred_card_public_rt" route table
resource "aws_route_table_association" "public" {
  // count is the number of subnets we want to associate with
  // this route table. We are using the subnet_count.public variable
  // which is currently 1, so we will be adding the 1 public subnet
  count = 1

  // Here we are making sure that the route table is
  // "cred_card_public_rt" from above
  route_table_id = aws_route_table.cred_card_public_rt.id

  // This is the subnet ID. Since the "cred_card_public_subnet" is a 
  // list of the public subnets, we need to use count to grab the
  // subnet element and then grab the id of that subnet
  subnet_id = aws_subnet.cred_card_public_subnet[count.index].id
}

// Create a private route table named "cred_card_private_rt"
resource "aws_route_table" "cred_card_private_rt" {
  // Put the route table in the "cred_card_VPC" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // Since this is going to be a private route table, 
  // we will not be adding a route
}

// Here we are going to add the private subnets to the
// route table "cred_card_private_rt"
resource "aws_route_table_association" "private" {
  // count is the number of subnets we want to associate with
  // the route table. We are using the subnet_count.private variable
  // which is currently 2, so we will be adding the 2 private subnets
  count = 2

  // Here we are making sure that the route table is
  // "cred_card_private_rt" from above
  route_table_id = aws_route_table.cred_card_private_rt.id

  // This is the subnet ID. Since the "cred_card_private_subnet" is a
  // list of private subnets, we need to use count to grab the
  // subnet element and then grab the ID of that subnet
  subnet_id = aws_subnet.cred_card_private_subnet[count.index].id
}

// Create a security group for the EC2 instances called "cred_card_web_sg"
resource "aws_security_group" "cred_card_web_sg" {
  // Basic details like the name and description of the SG
  name        = "cred_card_web_sg"
  description = "Security group for cred_card web servers"
  // We want the SG to be in the "cred_card_vpc" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // The first requirement we need to meet is "EC2 instances should 
  // be accessible anywhere on the internet via HTTP." So we will 
  // create an inbound rule that allows all traffic through
  // TCP port 80.
  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // The second requirement we need to meet is "Only you should be 
  // "able to access the EC2 instances via SSH." So we will create an 
  // inbound rule that allows SSH traffic ONLY from your IP address
  ingress {
    description = "Allow SSH from my computer"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    // This is using the variable "my_ip"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  // This outbound rule is allowing all outbound traffic
  // with the EC2 instances
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Here we are tagging the SG with the name "cred_card_web_sg"
  tags = {
    Name = "cred_card_web_sg"
  }
}

// Create a security group for the RDS instances called "cred_card_db_sg"
resource "aws_security_group" "cred_card_db_sg" {
  // Basic details like the name and description of the SG
  name        = "cred_card_db_sg"
  description = "Security group for cred_card databases"
  // We want the SG to be in the "cred_card_vpc" VPC
  vpc_id = aws_vpc.cred_card_vpc.id

  // The third requirement was "RDS should be on a private subnet and 	
  // inaccessible via the internet." To accomplish that, we will 
  // not add any inbound or outbound rules for outside traffic.

  // The fourth and finally requirement was "Only the EC2 instances 
  // should be able to communicate with RDS." So we will create an
  // inbound rule that allows traffic from the EC2 security group
  // through TCP port 5432, which is the port that Postgres
  // communicates through
  ingress {
    description     = "Allow MySQL traffic from only the web sg"
    from_port       = "5432"
    to_port         = "5432"
    protocol        = "tcp"
    // Add the Bastion host Security Group ID here
    security_groups = [aws_security_group.cred_card_web_sg.id]
  }

  // Here we are tagging the SG with the name "cred_card_db_sg"
  tags = {
    Name = "cred_card_db_sg"
  }
}

// Create a db subnet group named "cred_card_db_subnet_group"
resource "aws_db_subnet_group" "cred_card_db_subnet_group" {
  // The name and description of the db subnet group
  name        = "cred_card_db_subnet_group"
  description = "DB subnet group for cred_card"

  // Since the db subnet group requires 2 or more subnets, we are going to
  // loop through our private subnets in "cred_card_private_subnet" and
  // add them to this db subnet group
  subnet_ids = [for subnet in aws_subnet.cred_card_private_subnet : subnet.id]
}

// Create a DB instance called "cred_card_database"
resource "aws_db_instance" "cred_card_database" {
  // The amount of storage in gigabytes that we want for the database. This is 
  // being set by the settings.database.allocated_storage variable, which is 
  // set to 10
  allocated_storage = 10

  // The engine we want for our database. This is being set by the 
  // settings.database.engine variable, which is set to "mysql"
  engine = "postgres"

  // The version of our database engine. This is being set by the 
  // settings.database.engine_version variable, which is set to "8.0.27"
  engine_version = "15"

  // The instance type for our DB. This is being set by the 
  // settings.database.instance_class variable, which is set to "db.t2.micro"
  instance_class = "db.t3.micro"

  // This is the name of our database. This is being set by the
  // settings.database.db_name variable, which is set to "cred_card"
  db_name = "cred_card"

  // The master user of our database. This is being set by the
  // db_username variable, which is being declared in our secrets file
  username = var.db_username

  // The password for the master user. This is being set by the 
  // db_username variable, which is being declared in our secrets file
  password = var.db_password

  // This is the DB subnet group "cred_card_db_subnet_group"
  db_subnet_group_name = aws_db_subnet_group.cred_card_db_subnet_group.id

  // This is the security group for the database. It takes a list, but since
  // we only have 1 security group for our db, we are just passing in the
  // "cred_card_db_sg" security group
  vpc_security_group_ids = [aws_security_group.cred_card_db_sg.id]

  // This refers to the skipping final snapshot of the database. It is a 
  // boolean that is set by the settings.database.skip_final_snapshot
  // variable, which is currently set to true.
  skip_final_snapshot = true
}

// Create a PEM (and OpenSSH) formatted private key.
resource "tls_private_key" "cred_card_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// Create a key pair named "cred_card_kp"
resource "aws_key_pair" "cred_card_kp" {
  // Give the key pair a name
  key_name = "cred_card_kp"

  // This is going to be the public key of our
  // ssh key. We'll get the OpenSSH part of the 
  // cred_card_key to be our public key.
  public_key = tls_private_key.cred_card_key.public_key_openssh
}

// Use local_file resource to download the public key locally on your system
resource "local_file" "local_pub_key" {
  filename = "cred_card_kp.pub"
  // Avoid the key to be public visible.
  file_permission = "0400"
  // Public Key 
  content = tls_private_key.cred_card_key.public_key_openssh
}

// Use local_file resource to download the private key locally on your system
resource "local_file" "local_pri_key" {
  filename = "cred_card_kp.pem"
  // Avoid the key to be public visible.
  file_permission = "0400"
  // Private Key
  content = tls_private_key.cred_card_key.private_key_pem
}

// Create an EC2 instance named "cred_card_web"
resource "aws_instance" "cred_card_web" {
  // count is the number of instance we want
  // since the variable settings.web_app.cont is set to 1, we will only get 1 EC2
  count = 1

  // Here we need to select the ami for the EC2. We are going to use the
  // ami data object we created called ubuntu, which is grabbing the latest
  // Ubuntu 20.04 ami
  ami = data.aws_ami.ubuntu.id

  // This is the instance type of the EC2 instance. The variable
  // settings.web_app.instance_type is set to "t2.micro"
  instance_type = "t2.micro"

  // The subnet ID for the EC2 instance. Since "cred_card_public_subnet" is a list
  // of public subnets, we want to grab the element based on the count variable.
  // Since count is 1, we will be grabbing the first subnet in  	
  // "cred_card_public_subnet" and putting the EC2 instance in there
  subnet_id = aws_subnet.cred_card_public_subnet[count.index].id

  // The key pair to connect to the EC2 instance. We are using the "cred_card_kp" key 
  // pair that we created
  key_name = aws_key_pair.cred_card_kp.key_name

  // The security groups of the EC2 instance. This takes a list, however we only
  // have 1 security group for the EC2 instances.
  vpc_security_group_ids = [aws_security_group.cred_card_web_sg.id]

  // We are tagging the EC2 instance with the name "cred_card_db_" followed by
  // the count index
  tags = {
    Name = "cred_card_web_${count.index}"
  }
}

// Create an Elastic IP named "cred_card_web_eip" for each
// EC2 instance
resource "aws_eip" "cred_card_web_eip" {
  // count is the number of Elastic IPs to create. It is
  // being set to the variable settings.web_app.count which
  // refers to the number of EC2 instances. We want an
  // Elastic IP for every EC2 instance
  count = 1

  // The EC2 instance. Since cred_card_web is a list of 
  // EC2 instances, we need to grab the instance by the 
  // count index. Since the count is set to 1, it is
  // going to grab the first and only EC2 instance
  instance = aws_instance.cred_card_web[count.index].id

  // We want the Elastic IP to be in the VPC
  vpc = true

  // Here we are tagging the Elastic IP with the name
  // "cred_card_web_eip_" followed by the count index
  tags = {
    Name = "cred_card_web_eip_${count.index}"
  }
}