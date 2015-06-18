require 'sparkle_formation'
require 'json'
require 'aws-sdk'

class CloudFormationTemplate
  OUTPUT_TEMPLATE_PATH = File.expand_path(File.dirname(__FILE__)) + '/../dest/'

  def template_path(template_name)
    File.expand_path(File.dirname(__FILE__)) + "/../src/#{template_name}.rb"
  end

  def create(spf_template_path)
    JSON.pretty_generate(
      SparkleFormation.compile("#{spf_template_path}")
    )
  end

  def write_file(body, template_name)
    file_path = OUTPUT_TEMPLATE_PATH + template_name + '.template'
    File.write(file_path, body)
  end

  def upload_template(body, template_name)
    s3 = Aws::S3::Client.new(
      region: 'ap-northeast-1'
    )

    s3.put_object(
      bucket: @s3_bucket,
      key:    "jmeter-cluster/#{@environment}/#{template_name}.template",
      body:   body
    )
  end
end