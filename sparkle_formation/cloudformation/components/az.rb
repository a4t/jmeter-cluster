config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../../../config.yml')

SparkleFormation.build do
  set!('AWSTemplateFormatVersion', '2010-09-09')

  mappings.availability_zone do
    _set(config['jmeter_cluster']['environment'],
      :Master   => 'ap-northeast-1b',
      :Slave    => 'ap-northeast-1b'
    )
  end
end