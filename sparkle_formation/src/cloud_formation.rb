require 'aws-sdk'
require File.expand_path(File.dirname(__FILE__)) + '/cloud_formation_template'

class CloudFormation < CloudFormationTemplate
  def initialize(config)
    @environment = config['jmeter_cluster']['environment']
    @s3_bucket = config['jmeter_cluster']['s3_bucket']
    @cloudformation = Aws::CloudFormation::Client.new(
      region: 'ap-northeast-1'
    )
    @stack_name = "jmeter-cluster-#{@environment}"
  end

  def main(template_name)
    @template_url = "https://s3-ap-northeast-1.amazonaws.com/#{@s3_bucket}/jmeter-cluster/#{@environment}/#{template_name}.template"

    spf_template_path = template_path template_name
    body = create spf_template_path
    write_file(body, template_name)
    upload_template(body, template_name)
    run_stack
  end

  def run_stack
    update_stack unless create_stack
  end

  def create_stack
    begin
      @cloudformation.create_stack(
        stack_name: @stack_name,
        template_url: @template_url,
        capabilities: ["CAPABILITY_IAM"],
        tags: [
          {
            key: "Service",
            value: "jmeter-cluster",
          },
          {
            key: "Env",
            value: @environment,
          }
        ]
      )
      true
    rescue
      false
    end
  end

  def update_stack
    @cloudformation.update_stack(
      stack_name: @stack_name,
      template_url: @template_url,
      capabilities: ["CAPABILITY_IAM"],
    )
  end
end