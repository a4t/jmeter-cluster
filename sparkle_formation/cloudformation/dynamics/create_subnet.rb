SparkleFormation.dynamic(:create_subnet) do |_name, _config={}|

  resources("subnet_#{_name}".to_sym) do
    type 'AWS::EC2::Subnet'
    properties do
      cidr_block _config[:cidr_block]
      availability_zone map!(:availability_zone, :environment, _name)
      vpc_id _ref(:vpc)
      tags _array(
        -> {
          key 'Name'
          value join!(['jmeter-', ref!(:environment), "-#{_name}"])
        }
      )
    end
  end

  resources("route_table_#{_name}") do
    type 'AWS::EC2::RouteTable'
    properties do
      vpc_id ref!(:vpc)
      tags _array(
        -> {
          key 'Name'
          value join!(['jmeter-', ref!(:environment), "-#{_name}"])
        }
      )
    end
  end

  resources("#{_name}_create_route") do
    type 'AWS::EC2::Route'
    properties do
      destinationCidrBlock '0.0.0.0/0'
      route_table_id ref!("route_table_#{_name}".to_sym)
      gateway_id ref!(:internet_gateway)
    end
  end

  resources("route_table_association_#{_name}".to_sym) do
    type 'AWS::EC2::SubnetRouteTableAssociation'
    properties do
      route_table_id ref!("route_table_#{_name}".to_sym)
      subnet_id ref!("subnet_#{_name}".to_sym)
    end
  end

end