def set_vpc_cidr_template(prefix_ip)
  cidr_blocks = {
    :range     => "#{prefix_ip}.0.0/16",
    :master    => "#{prefix_ip}.1.0/24",
    :slave     => "#{prefix_ip}.2.0/24",
  }
end

config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../../../config.yml')
cidr_blocks = set_vpc_cidr_template config['jmeter_cluster']['vpc_ip_range']

SparkleFormation.build do
  mappings.vpc_cidr_block do
    _set(config['jmeter_cluster']['environment'], cidr_blocks)
  end
end