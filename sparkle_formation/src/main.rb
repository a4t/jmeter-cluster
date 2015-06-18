config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../../config.yml')

SparkleFormation.new('main')
  .load(:ip_range)
  .load(:az)
.overrides do
  description 'Jmeter Cluster'

  parameters do
    my_cidr_ip do
      type 'String'
      default config['jmeter_cluster']['my_cidr_ip']
      description 'My CidrIp'
    end

    environment do
      description config['jmeter_cluster']['environment'].capitalize
      type 'String'
      default config['jmeter_cluster']['environment'].capitalize
    end

    slave_count do
      description 'Slave Instance count'
      type 'Number'
      default 1
    end
  end

  resources do
    vpc do
      type 'AWS::EC2::VPC'
      properties do
        cidr_block map!(:vpc_cidr_block, :environment, :range)
        instance_tenancy 'default'
        enable_dns_support true
        enable_dns_hostnames true
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-vpc'])
          }
        )
      end
    end

    internet_gateway do
      type 'AWS::EC2::InternetGateway'
      properties do
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-gateway'])
          }
        )
      end
    end

    internet_gateway_attach do
      type 'AWS::EC2::VPCGatewayAttachment'
      properties do
        vpc_id ref!(:vpc)
        internet_gateway_id ref!(:internet_gateway)
      end
    end

    master_security_group do
      type 'AWS::EC2::SecurityGroup'
      properties do
        group_description 'jmeter master server security group'
        vpc_id ref!(:vpc)
        security_group_ingress _array(
          -> {
            from_port 22
            to_port 22
            ip_protocol 'tcp'
            cidr_ip ref!(:my_cidr_ip)
          }
        )
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-master-server'])
          }
        )
      end
    end

    slave_elb_security_group do
      type 'AWS::EC2::SecurityGroup'
      properties do
        group_description 'jmeter slave elb security group'
        vpc_id ref!(:vpc)
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-slave-elb'])
          }
        )
      end
    end

    health_check_security_group do
      type 'AWS::EC2::SecurityGroup'
      properties do
        group_description 'jmeter elb health check security group'
        vpc_id ref!(:vpc)
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-health-check'])
          }
        )
      end
    end

    slave_security_group do
      type 'AWS::EC2::SecurityGroup'
      properties do
        group_description 'jmeter slave server security group'
        vpc_id ref!(:vpc)
        security_group_ingress _array(
          -> {
            from_port 22
            to_port 22
            ip_protocol 'tcp'
            source_security_group_id ref!(:master_security_group)
          },
          -> {
            from_port 22
            to_port 22
            ip_protocol 'tcp'
            cidr_ip ref!(:my_cidr_ip)
          }
        )
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-slave-server'])
          }
        )
      end
    end

    master_security_group_ingress do
      type 'AWS::EC2::SecurityGroupIngress'
      properties do
        group_id ref!(:master_security_group)
        from_port 0
        to_port 65535
        ip_protocol 'tcp'
        source_security_group_id ref!(:slave_security_group)
      end
    end

    slave_security_group_ingress do
      type 'AWS::EC2::SecurityGroupIngress'
      properties do
        group_id ref!(:slave_security_group)
        from_port 0
        to_port 65535
        ip_protocol 'tcp'
        source_security_group_id ref!(:master_security_group)
      end
    end

    health_check_security_group_ingress do
      type 'AWS::EC2::SecurityGroupIngress'
      properties do
        group_id ref!(:health_check_security_group)
        from_port 80
        to_port 80
        ip_protocol 'tcp'
        source_security_group_id ref!(:slave_elb_security_group)
      end
    end

    master_server_role do
      type 'AWS::IAM::Role'
      properties do
        assume_role_policy_document do
          version '2012-10-17'
          statement _array(
            -> {
              effect 'Allow'
              principal {
                service [
                  'ec2.amazonaws.com'
                ]
              }
              action _array(
                'sts:AssumeRole'
              )
            }
          )
        end
        path '/'
        policies _array(
          -> {
            policy_name 'ec2-describe-instances'
            policyDocument do
              version '2012-10-17'
              Statement _array(
                -> {
                 effect 'Allow'
                 action 'ec2:DescribeInstances'
                 resource '*'
                }
              )
            end
          }
        )
      end
    end

    master_server_instance_profile do
      type 'AWS::IAM::InstanceProfile'
      properties do
        path '/'
        roles _array(
          _ref(:master_server_role)
        )
      end
    end

    master_server do
      type 'AWS::EC2::Instance'
      properties do
        iam_instance_profile _ref(:master_server_instance_profile)
        image_id 'ami-cbf90ecb'
        instance_type 't2.micro'
        key_name key_pair = config['jmeter_cluster']['key_pair']
        monitoring false
        network_interfaces _array(
          -> {
            associate_public_ip_address true
            device_index 0
            group_set _array(
              ref!(:master_security_group)
            )
            subnet_id ref!(:subnet_master)
          }
        )
        user_data _cf_base64('#!/bin/bash

cd /var
wget http://ftp.jaist.ac.jp/pub/apache//jmeter/binaries/apache-jmeter-2.13.tgz
tar xvzf apache-jmeter-2.13.tgz
rm -rf apache-jmeter-2.13.tgz
chown -R ec2-user:ec2-user /var/apache-jmeter-2.13

gem install aws-sdk
        ')
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-master-server'])
          },
          -> {
            key 'Role'
            value 'master'
          }
        )
      end
    end

    slave_server_configuration do
      type 'AWS::AutoScaling::LaunchConfiguration'
      properties do
        image_id 'ami-cbf90ecb'
        associate_public_ip_address true
        instance_type 'c4.large'
        key_name config['jmeter_cluster']['key_pair']
        instance_monitoring false
        security_groups [
          ref!(:slave_security_group),
          ref!(:health_check_security_group)
        ]
        spot_price '0.05'
        user_data _cf_base64('#!/bin/bash

cd /var
wget http://ftp.jaist.ac.jp/pub/apache//jmeter/binaries/apache-jmeter-2.13.tgz
tar xvzf apache-jmeter-2.13.tgz
rm -rf apache-jmeter-2.13.tgz
/var/apache-jmeter-2.13/bin/jmeter-server -Djava.rmi.server.hostname=`curl -s http://169.254.169.254/latest/meta-data/public-hostname` -Dsun.net.inetaddr.ttl=0 &
        ')
      end
    end

    slave_server_scaling_group do
      type 'AWS::AutoScaling::AutoScalingGroup'
      properties do
        VPC_zone_identifier [ ref!(:subnet_slave) ]
        launch_configuration_name ref!(:slave_server_configuration)
        min_size ref!(:slave_count)
        max_size ref!(:slave_count)
        tags _array(
          -> {
            key 'Name'
            value join!(['jmeter-', ref!(:environment), '-slave-server'])
            propagate_at_launch true
          },
          -> {
            key 'Role'
            value 'slave'
            propagate_at_launch true
          }
        )
      end
    end
  end

  dynamic!(:create_subnet, 'Master', config = {
    :cidr_block => map!(:vpc_cidr_block, :environment, 'Master'),
  })

  dynamic!(:create_subnet, 'Slave', config = {
    :cidr_block => map!(:vpc_cidr_block, :environment, 'Slave'),
  })

  outputs do
    vpc do
      description 'VPC ID'
      value ref!(:vpc)
    end
  end
end