web_app "my_site" do
  server_name node['hostname']
  docroot "/var/www/html"
  cookbook 'apache2'
end

script "Run a script" do
  interpreter "bash"
  code <<-EOH
    i=$(curl http://169.254.169.254/latest/meta-data/instance-id)
    sed -i 's|/srv/www/my_site|/var/www/html|' /etc/apache2/sites-available/my_site.conf
    sed -i 's|RewriteEngine On|RewriteEngine off|' /etc/apache2/sites-available/my_site.conf    
    sed -i "s|Apache2 Ubuntu Default Page|$i|" /var/www/html/index.html
  EOH
end

service "Restart apache2" do
  action :restart
  service_name "apache2"
end

