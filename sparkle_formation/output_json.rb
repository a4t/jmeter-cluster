require 'yaml'
require File.expand_path(File.dirname(__FILE__)) + '/src/cloud_formation'

config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')
cloud_formation = CloudFormation.new config
cloud_formation.main 'main'