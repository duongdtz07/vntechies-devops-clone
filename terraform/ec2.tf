resource "aws_security_group" "app" {
  name        = "${var.env}-app-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "${var.env}-app-sg"
  }
}

resource "aws_instance" "app" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public-subnet-B.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/app-install.sh")
  tags = {
    Name = "${var.env}-app-server"
  }
}
