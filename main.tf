provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

####### Create VPC #########

resource "aws_vpc" "terraform-vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-demo-vpc"
  }
}

############ create subnets ###########

resource "aws_subnet" "subnet1" {
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    cidr_block = "192.168.0.0/24"


tags = {
  Name = "subnet1"
   }
}

resource "aws_subnet" "subnet2" {
    vpc_id = "${aws_vpc.terraform-vpc.id}"
    cidr_block = "192.168.1.0/24"

tags = {
  Name = "subnet2"
   }
}

################ internet gateway #################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

###################### create route table #####################

resource "aws_route_table" "terraform-rt" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
    tags = {
    Name = "terraformRouteTB"
  }
}

################ route table associations ###################

resource "aws_route_table_association" "terraformRouteTB" {
subnet_id = aws_subnet.subnet1.id
route_table_id = aws_route_table.terraform-rt.id
}

########## create ec2 instance with shell script #############

resource "aws_instance" "ec2Instance" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  user_data     = <<-EOF
               #!/bin/bash
               sudo apt-get update -y
               sudo apt-get install apache2 apache2-utils -y
               sudo apt install php7.4-cli -y
               sudo apt install libapache2-mod-php -y
               sudo apt-get install php-mysqlnd -y
               sudo apt install php-mysql -y
               sudo apt install php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
               sudo apt install mysql-client-core-8.0 -y
               cd /var/www/html
               sudo rm -R index.html
               sudo wget https://wordpress.org/latest.tar.gz
               sudo tar -xzvf latest.tar.gz
               sudo mv wordpress/* ./
               sudo chown -R www-data:www-data /var/www/html
               sudo systemctl restart apache2
               EOF
  tags = {
    Name = "wordpress"
  }
}
 
################## create s3 bucket #####################

resource "aws_s3_bucket" "b" {
  bucket = "charleybucket44"
  acl    = "private"

  tags = {
    Name        = "terraform-bucket"
    Environment = "Dev"
  }
}

################# Upload an object #######################

resource "aws_s3_bucket_object" "object" {
  for_each = fileset("wpsite/", "*")
bucket = aws_s3_bucket.b.id
  key    = "each.value"
  acl    = "private"  # or can be "public-read"
  source = "wpsite/${each.value}"
  etag = filemd5("wpsite/${each.value}")

}


#################### create IAM user #########################

resource "aws_iam_user" "user01" {
    name = "s3user1"
}

########## attach policy to IAM user ########

resource "aws_iam_policy_attachment" "attachment" {
   name = "attachment"
   users = aws_iam_user.user01.*.name
   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

################### create security group ###############

resource "aws_security_group" "wordpress-sg" {
   name = "wordpress-sg" 
   description = "sg for webserver open port 22,80,443"
   vpc_id = "${aws_vpc.terraform-vpc.id}"

   ingress {
    description = "allow port 22"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

 ingress {
    description = "allow port 80"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

 ingress {
    description = "allow port 443"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

 egress {
   description = "allow all ip and ports outbound"
    
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

tags = {
 Name = "webserver"
}
}
