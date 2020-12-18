#Cluster ECS

resource "aws_ecs_cluster" "ecs" {
  name = "${var.ecs_cluster}"

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------
#Key Pair
resource "aws_key_pair" "key" {
  key_name = "${var.ecs_cluster}-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7f56ewMZz4WLRzKLy8mnJ2ZS1gWhDiE3A4UinEqlogZQCuibNRSsF8C9oXg6IlxdeqBet5Zx4jf/qgTuEDVCF7QyyYxFtNKctSX901spJXhpusx4k9aMPmsTHGCj7DL1mHKwrvb7fSdJcsffo8R/3NWzP7bBcwLgZeTw/vSYvECNnco7yvPhIiHSvTfggj8s4tVEMb8vqkvfDJm6gRTpw3+KsA2yZGuiSFNQQcpbckVwbP5iSbalmJkRBPV5PWVx1wYLkSuPY4b6wAYyggfJ50rRO5Pvs7xhyJ7cXxTflE1OalZNpSLkAErYn4uuiW6az4BMHTB2aTVt98JEeoIwF"
}

#-------------------------------------------------
# IAM Roles

resource "aws_iam_role" "iam_role" {
  name = "${var.ecs_cluster}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

#atachando policys 
resource "aws_iam_role_policy_attachment" "ecs-service-role" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "ecs-service-for-ec2-role" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
    role       = "${aws_iam_role.iam_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name  = "${var.ecs_cluster}-ecs"
  role = "${aws_iam_role.iam_role.name}"
}

#--------------------------------------------------------------------------------
#SG-ALB	
resource "aws_security_group" "alb-sg" {
  name = "${var.ecs_cluster}-alb-sg"
  description = "${var.ecs_cluster}-alb-sg"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

# https
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ecs_cluster}-alb-sg"
    env  = "terraform"
  }
}

#---------------------------------------------------
#ALB
resource "aws_alb" "ecs-load-balancer" {
    name                = "${var.ecs_cluster}-load-balancer"
    security_groups     = ["${aws_security_group.alb-sg.id}"]
    subnets             = ["${var.subnet_1}", "${var.subnet_2}", "${var.subnet_3}"]

    tags {
      Name = "${var.ecs_cluster}-load-balancer"
    }
}

resource "aws_alb_target_group" "default-target" {
    name                = "${var.ecs_cluster}-default-target"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = "${var.vpc_id}"

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }

lifecycle {
    create_before_destroy = true
  }

  depends_on = ["aws_alb.ecs-load-balancer"] // HERE!
}


resource "aws_alb_listener" "alb-listener" {
    load_balancer_arn = "${aws_alb.ecs-load-balancer.arn}"
    port              = "80"
    protocol          = "HTTP"

    default_action {
        target_group_arn = "${aws_alb_target_group.default-target.arn}"
        type             = "forward"
    }
}


#---------------------------------------------------------------------------
#Cluster SG
resource "aws_security_group" "cluster-sg" {
  name = "${var.ecs_cluster}-ec2-sg"
  description = "${var.ecs_cluster}-ec2-sg"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
# SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }
# HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }

# https
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"]
  }


  tags = {
    Name = "${var.ecs_cluster}-ec2-sg"
    env  = "terraform"
  }
}

#---------------------------------------------------------------------------
resource "aws_launch_configuration" "launch-configuration" {
    name                        = "${var.ecs_cluster}-launch-configuration"
    image_id                    = "${var.ami_id}"
    instance_type               = "${var.instance_type}"
    iam_instance_profile        = "${aws_iam_instance_profile.ecs-instance-profile.arn}"

    root_block_device {
      volume_type = "gp2"
      volume_size = 30
      delete_on_termination = true
    }

    lifecycle {
      create_before_destroy = true
    }

    security_groups             = ["${aws_security_group.cluster-sg.id}", "${aws_security_group.alb-sg.id}"]
    key_name                    = "${var.ecs_cluster}-key"
    user_data                   = <<EOF
                                  #!/bin/bash
                                  echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
                                  yum -y update
                                  yum -y upgrade
                                  yum install -y docker htop screen
                                  service docker start
                                  sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
                                  sudo systemctl enable amazon-ssm-agent
                                  sudo systemctl start amazon-ssm-agent
                                  #Installing cloudwatch metrics
                                  yum install perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA zip unzip -y
                                  mkdir /home/ec2-user/aws-mon-install
                                  cd /home/ec2-user/aws-mon-install
                                  curl http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip -O
                                  unzip CloudWatchMonitoringScripts-1.2.1.zip
                                  #configure cron
                                  (crontab -l ;  echo "* * * * * /home/ec2-user/aws-mon-install/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --swap-util --swap-used --disk-space-util --disk-space-used --disk-space-avail --disk-path=/ --from-cron") | crontab
                                  EOF
}
#Autoescaling
resource "aws_autoscaling_group" "ecs-autoscaling-group" {
    name                        = "${var.ecs_cluster}-autoscaling-group"
    max_size                    = "${var.max_instance_size}"
    min_size                    = "${var.min_instance_size}"
    desired_capacity            = "${var.desired_capacity}"
    vpc_zone_identifier         = ["${var.subnet_4}", "${var.subnet_5}", "${var.subnet_6}"]
    launch_configuration        = "${aws_launch_configuration.launch-configuration.name}"
    health_check_type           = "ELB"
tag {
    key = "Name"
    value = "node-cluster-${var.ecs_cluster}"
    propagate_at_launch = true
  }
}

#--------------------------------------------------------------------
resource "aws_autoscaling_policy" "memory-scale-up" {
    name = "memory-scale-up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
}

resource "aws_autoscaling_policy" "memory-scale-down" {
    name = "memory-scale-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
}

resource "aws_cloudwatch_metric_alarm" "memory-high" {
    alarm_name = "mem-util-high"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "MemoryUtilization"
    namespace = "System/Linux"
    period = "120"
    statistic = "Average"
    threshold = "80"
    alarm_description = "This metric monitors ec2 memory for high utilization on agent hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.memory-scale-up.arn}"
    ]
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
    }
}

resource "aws_cloudwatch_metric_alarm" "memory-low" {
    alarm_name = "mem-util-low"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "MemoryUtilization"
    namespace = "System/Linux"
    period = "120"
    statistic = "Average"
    threshold = "80"
    alarm_description = "This metric monitors ec2 memory for low utilization on agent hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.memory-scale-down.arn}"
    ]
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
    }
}

#------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu-scale-up" {
    name = "cpu-scale-up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
}

resource "aws_autoscaling_policy" "cpu-scale-down" {
    name = "cpu-scale-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-high" {
    alarm_name = "cpu-util-high"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "300"
    statistic = "Average"
    threshold = "80"
    alarm_description = "This metric monitors ec2 CPU for high utilization on hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.cpu-scale-up.arn}"
    ]
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
    }
}

resource "aws_cloudwatch_metric_alarm" "cpu-low" {
    alarm_name = "cpu-util-low"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "300"
    statistic = "Average"
    threshold = "80"
    alarm_description = "This metric monitors ec2 CPU for high utilization on hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.cpu-scale-down.arn}"
    ]
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.ecs-autoscaling-group.name}"
    }
}

#-------------------------------------------------------------------
# NGINX Service
resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.iam_role.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.default-target.id}"
    container_name   = "nginx"
    container_port   = "80"
  }

  lifecycle {
    ignore_changes = ["task_definition"]
  }
}

resource "aws_ecs_task_definition" "nginx" {
  family = "${var.ecs_cluster}-nginx"

  container_definitions = <<EOF
[
  {
    "portMappings": [
      {
        "hostPort": 80,
        "protocol": "tcp",
        "containerPort": 80
      }
    ],
    "cpu": 256,
    "memory": 300,
    "image": "nginx:latest",
    "essential": true,
    "name": "nginx",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.ecs_cluster}/ecs/nginx",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
}

resource "aws_cloudwatch_log_group" "nginx" {
  name = "${var.ecs_cluster}/ecs/nginx"
}
