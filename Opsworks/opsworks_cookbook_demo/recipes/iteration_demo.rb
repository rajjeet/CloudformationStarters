stack = search("aws_opsworks_stack").first
Chef::Log.info("**************** Content of 'custom_cookbooks_source' *****************")

stack["custom_cookbooks_source"].each do |content|
  Chef::Log.info("********** '#{content}' **************")
end
