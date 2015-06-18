require 'net/ssh'
require 'net/scp'
require 'aws-sdk'
require 'yaml'
require "date"

class ConnectServer
  JMETER_PROPERTIES = '/var/apache-jmeter-2.13/bin/jmeter.properties'
  EC2 = Aws::EC2::Client.new(
    region: 'ap-northeast-1'
  )
  LOGIN_USER = 'ec2-user'

  def initialize(config)
    @environment = config['jmeter_cluster']['environment']
    @master_host = get_master_host
    @jmeter_result_path = config['jmeter_cluster']['remote_result_path']
  end

  def main
    reload_remote_hosts
    upload_jmx_file
    delete_remote_result
    run_attack
    download_result
  end

  def download_result
    now_date = DateTime.now.strftime("%Y%m%d%H%M%S")
    local_path = "./results/#{now_date}.csv"
    remote_path = jmeter_result_path
    download(local_path, remote_path)
  end

  def delete_remote_result
    remote_path = jmeter_result_path
    command!("rm -rf #{remote_path}")
  end

  private
    def reload_remote_hosts
      servers = get_remote_hosts.chop
      command!("sed -i '/^remote_hosts=/d' #{JMETER_PROPERTIES}")
      command!("echo remote_hosts=#{servers} >> #{JMETER_PROPERTIES}")
    end

    def instances_default_filter
      [
        { name: 'tag-key',   values: ['Service'] },
        { name: 'tag-key',   values: ['Env'] },
        { name: 'tag-key',   values: ['Role'] },
        { name: 'tag-value', values: ['jmeter-cluster'] },
        { name: 'tag-value', values: [@environment] },
        { name: 'instance-state-name', values: ['running'] }
      ]
    end

    def get_instances_master_filter
      master_filter = [
        { name: 'tag-value', values: ['master'] },
      ]

      master_filter.concat(instances_default_filter)
    end

    def get_instances_slave_filter
      slave_filter = [
        { name: 'tag-value', values: ['slave'] },
      ]

      slave_filter.concat(instances_default_filter)
    end

    def get_master_host
      instances = EC2.describe_instances(filters: get_instances_master_filter)
      server = '';
      instances.data.reservations.each do |reservation|
        reservation.instances.each do |instance|
          server = instance.public_dns_name
        end
      end

      server
    end

    def get_remote_hosts
      instances = EC2.describe_instances(filters: get_instances_slave_filter)

      servers = '';
      instances.data.reservations.each do |reservation|
        reservation.instances.each do |instance|
          servers += instance.public_dns_name + ':1099,'
        end
      end

      servers
    end

    def upload_jmx_file
      local_jmx_path = File.expand_path(File.dirname(__FILE__)) + '/../upload.jmx'
      remote_jmx_path = '/tmp/upload.jmx'
      upload!(local_jmx_path, remote_jmx_path)
    end

    def run_attack
      command!('/var/apache-jmeter-2.13/bin/jmeter -n -t /tmp/upload.jmx -r')
    end

    def upload!(local_path, remote_path)
      Net::SCP.start(@master_host, LOGIN_USER) do |scp|
        scp.upload!(local_path, remote_path)
      end
    end

    def download(local_path, remote_path)
      Net::SCP.start(@master_host, LOGIN_USER) do |scp|
        scp.download(remote_path, local_path)
      end
    end

    def command!(command)
      Net::SSH.start(@master_host, LOGIN_USER) do |ssh|
        ssh.exec!(command)
      end
    end
end

config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')
connect_server = ConnectServer.new config
connect_server.main