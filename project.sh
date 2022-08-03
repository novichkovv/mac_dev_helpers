#!/bin/zsh
if [ "$EUID" -eq 0 ]; then
    echo "Please do not use sudo to run the script"
    exit 1
fi
project_name="$1"
domain="$2"
a=("$@")
params=("${a[@]:2}")
subdomains=""
for subdomain in ${params[*]}; do
    subdomains="${subdomains} $subdomain.$domain"
done
vhost_conf_name="/Users/admin/vhosts/$domain.conf"
project_path="/Users/admin/projects/$project_name/public"

if [ -f "$vhost_conf_name" ]; then
    echo "Error: Vhost with this domain has already been created"
    exit 1
fi
if [ ! -d "$project_path" ]; then
    echo "Error: $project_path must be a folder"
    exit 1
fi

touch "$vhost_conf_name"
echo "Generating Vhosts config file"
printf "<VirtualHost %s:80>\n" "$domain" > "$vhost_conf_name"
printf "    DocumentRoot \"%s\"\n" "$project_path" >> "$vhost_conf_name"
printf "    ServerName %s\n" "$domain" >> "$vhost_conf_name"

if [ ! ${#subdomains[@]} -eq 0 ]; then
    printf "    ServerAlias %s\n" "$subdomains" >> "$vhost_conf_name"
fi
{
    printf "    <Directory \"%s\">\n" "$project_path"
    printf "        Options Indexes FollowSymLinks Includes ExecCGI\n"
    printf "        AllowOverride All\n"
    printf "        Require all granted\n"
    printf "    </Directory>\n"
    printf "</VirtualHost>\n"
    printf "<VirtualHost %s:443>\n" "$domain"
    printf "    DocumentRoot \"%s\"\n" "$project_path"
    printf "    ServerName %s\n" "$domain"
} >> "$vhost_conf_name"
if [ ! ${#subdomains[@]} -eq 0 ]; then
    printf "    ServerAlias %s\n" "$subdomains" >> "$vhost_conf_name"
fi
{
    printf "    SSLEngine on\n"
    printf "    SSLCertificateFile /Users/admin/vhosts/certs/%s.pem\n" "$domain"
    printf "    SSLCertificateKeyFile /Users/admin/vhosts/certs/%s-key.pem\n" "$domain"
    printf "    <Directory \"%s\">\n" "$project_path"
    printf "        Options Indexes FollowSymLinks Includes ExecCGI\n"
    printf "        AllowOverride All\n"
    printf "        Require all granted\n"
    printf "    </Directory>\n"
    printf "</VirtualHost>\n"
} >> "$vhost_conf_name"

echo "Generating SSL certificates"
cd "/Users/admin/vhosts/certs" || exit
mkcert "$domain"

echo "Restarting apache"
brew services restart httpd

echo "Project $project_name is successfully created, check at https://$domain"

echo "Please, add corresponding record to /etc/hosts if domain is not in .loc zone"
