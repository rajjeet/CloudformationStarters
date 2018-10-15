instance = search("aws_opsworks_instance").first
layer = search("aws_opsworks_layer").first
stack = search("aws_opsworks_stack").first

Chef::Log.info("************* This instance's instance ID is '#{instance['instance_id']}' ****************")
Chef::Log.info("************* This instance's public IP address is '#{instance['public_ip']}' ****************")
Chef::Log.info("************* This instance belongs to the layer '#{layer['name']}' ****************")
Chef::Log.info("************* This instance belongs to the stack '#{stack['name']}' ****************")
Chef::Log.info("************* This stack gets its cookbooks from #{stack['custom_cookbooks_source']['url']} ****************")