provider "aws" {
    region = "eu-west-3"
    access_key = ""
    secret_key = ""
  }

#Create VPC
  resource "aws_vpc" "myvpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      "Name" = "MyProjectVPC"
    }
  }

#Create Subnets
  resource "aws_subnet" "Mysubnet01" {
    vpc_id                  = aws_vpc.myvpc.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = "eu-west-3a"
    map_public_ip_on_launch = true
    tags = {
      "Name" = "MyPublicSubnet01"
    }
  }

  resource "aws_subnet" "Mysubnet02" {
    vpc_id                  = aws_vpc.myvpc.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = "eu-west-3b"
    map_public_ip_on_launch = true
    tags = {
      "Name" = "MyPublicSubnet02"
    }
  }
  resource "aws_subnet" "Mysubnet03" {
    vpc_id                  = aws_vpc.myvpc.id
    cidr_block              = "10.0.3.0/24"
    availability_zone       = "eu-west-3c"
    map_public_ip_on_launch = true
    tags = {
      "Name" = "MyPublicSubnet03"
    }
  }

  # Create Internet Gateway 
  resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
      "Name" = "MyIGW"
    }
  }

  # Create Route Table
  resource "aws_route_table" "myroutetable" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
      "Name" = "MyPublicRouteTable"
    }
  }

  # Create a Route 
  resource "aws_route" "myigw_route" {
    route_table_id         = aws_route_table.myroutetable.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.myigw.id
  }

  
  resource "aws_route_table_association" "Mysubnet01_association" {
    route_table_id = aws_route_table.myroutetable.id
    subnet_id      = aws_subnet.Mysubnet01.id
  }

  resource "aws_route_table_association" "Mysubnet02_association" {
    route_table_id = aws_route_table.myroutetable.id
    subnet_id      = aws_subnet.Mysubnet02.id
  }

  resource "aws_route_table_association" "Mysubnet03_association" {
    route_table_id = aws_route_table.myroutetable.id
    subnet_id      = aws_subnet.Mysubnet03.id
  }


 #sec group
  resource "aws_security_group" "allow_tls" {
    name_prefix   = "allow_tls_"
    description   = "Allow TLS inbound traffic"
    vpc_id        = aws_vpc.myvpc.id

    ingress {
      description = "TLS from VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

 #IAM role
  resource "aws_iam_role" "master" {
    name = "ed-eks-master"

    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role" "worker" {
    name = "ed-eks-worker"

    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  resource "aws_iam_policy" "autoscaler" {
    name = "ed-eks-autoscaler-policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeTags",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeLaunchTemplateVersions"
          ],
          "Effect": "Allow",
          "Resource": "*"
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "x-ray" {
    policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "s3" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "autoscaler" {
    policy_arn = aws_iam_policy.autoscaler.arn
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_instance_profile" "worker" {
    depends_on = [aws_iam_role.worker]
    name       = "ed-eks-worker-new-profile"
    role       = aws_iam_role.worker.name
  }

 #Create EKS CLUST
  resource "aws_eks_cluster" "eks" {
    name     = "pc-eks"
    role_arn = aws_iam_role.master.arn

    vpc_config {
      subnet_ids = [aws_subnet.Mysubnet01.id, aws_subnet.Mysubnet02.id,aws_subnet.Mysubnet03.id]
    }

    tags = {
      "Name" = "MyEKS"
    }

    depends_on = [
      aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
      aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
      aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    ]
  }

  resource "aws_instance" "kubectl-server" {
    ami                         = "ami-0f5ee92e2d63afc18"  
    key_name                    = "mumbai-kp" 
    instance_type               = "t2.micro"
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.Mysubnet01.id
    vpc_security_group_ids      = [aws_security_group.allow_tls.id]

    tags = {
      Name = "kubectl"
    }
  }

  resource "aws_eks_node_group" "node-grp" {
    cluster_name    = aws_eks_cluster.eks.name
    node_group_name = "pc-node-group"
    node_role_arn   = aws_iam_role.worker.arn
    subnet_ids      = [aws_subnet.Mysubnet01.id, aws_subnet.Mysubnet02.id]
    capacity_type   = "ON_DEMAND"
    disk_size       = 20
    instance_types  = ["t2.small"]

    remote_access {
      ec2_ssh_key               = "mumbai-kp"
      source_security_group_ids = [aws_security_group.allow_tls.id]
    }

    labels = {
      env = "dev"
    }

    scaling_config {
      desired_size = 2
      max_size     = 2
      min_size     = 1
    }

    update_config {
      max_unavailable = 1
    }

    depends_on = [
      aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
      aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
      aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    ]
  }
