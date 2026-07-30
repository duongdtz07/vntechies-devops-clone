# resource "random_password" "rds" {
#   length           = 16
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }

# resource "aws_db_subnet_group" "main" {
#   name       = "demo-db-subnet-group"
#   subnet_ids = [aws_subnet.public-subnet-A.id, aws_subnet.public-subnet-B.id]

#   tags = {
#     Name = "demo-db-subnet-group"
#   }
# }

# resource "aws_security_group" "rds" {
#   name        = "rds-sg"
#   description = "Allow PostgreSQL from within VPC"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     description = "PostgreSQL"
#     from_port   = 5432
#     to_port     = 5432
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "rds-sg"
#   }
# }

# resource "aws_db_instance" "main" {
#   identifier        = "demo-postgres"
#   engine            = "postgres"
#   engine_version    = "16"
#   instance_class    = "db.t3.micro"
#   allocated_storage = 20
#   storage_type      = "gp2"

#   db_name  = "demodb"
#   username = "dbadmin"
#   password = random_password.rds.result

#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   vpc_security_group_ids = [aws_security_group.rds.id]

#   multi_az            = true
#   publicly_accessible = true
#   skip_final_snapshot = true

#   tags = {
#     Name = "demo-postgres"
#   }
# }
