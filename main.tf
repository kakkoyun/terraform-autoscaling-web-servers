###############################################################################
# VARIABLES
###############################################################################

variable "aws_shared_crendetial_file_path" {
  description = <<-DESC
  The file path to access AWS credentials.
  If this specified, aws_access_key and aws_secret_key will be ignored.
  DESC

  default = "~/.aws/creds"
}

variable "aws_profile" {
  description = <<-DESC
  The profile that specifies necessary credentials in shared credential file.
  This needs to be specified when aws_shared_crendetial_file_path used.
  DESC

  default = "personal"
}

variable "aws_region" {
  default = "eu-central-1"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"

  default = 8080
}

###############################################################################
# PROVIDERS
###############################################################################

provider "aws" {
  shared_credentials_file = "${var.aws_shared_crendetial_file_path}"
  profile                 = "${var.aws_profile}"
  region                  = "${var.aws_region}"
}

###############################################################################
# DATA
###############################################################################

data "aws_availability_zones" "available" {}

###############################################################################
# RESOURCES
###############################################################################

resource "aws_security_group" "example_elb" {
  name = "terraform-example-elb-security-group"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "example_instace" {
  name = "terraform-example-instance-security-group"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "example" {
  instance_type   = "t2.micro"
  image_id        = "ami-76801819"
  security_groups = ["${aws_security_group.example_instace.id}"]

  user_data = <<-EOF
            #!/bin/bash
            echo "Simplicity is greatest sophistication!" > index.html
            nohup busybox httpd -f -p "${var.server_port}" &
            EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones   = ["${data.aws_availability_zones.available.names}"]

  min_size = 2
  max_size = 11

  load_balancers    = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-autscaling-group-example"
    propagate_at_launch = true
  }
}

resource "aws_elb" "example" {
  name               = "terraform-example-elb"
  security_groups    = ["${aws_security_group.example_elb.id}"]
  availability_zones = ["${data.aws_availability_zones.available.names}"]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }
}

###############################################################################
# OUTPUT
###############################################################################

output "aws_elb_public_dns" {
  value = "${aws_elb.example.dns_name}"
}
