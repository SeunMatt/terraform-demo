resource "digitalocean_droplet" "demo-server" {
  image = "ubuntu-20-04-x64"
  name = "demo-server"
  region = "fra1"
  size = "s-1vcpu-1gb"
  monitoring = true
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]

  #terraform will use this to SSH into the server
  #for script execution	
  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = file(var.pvt_key)
    timeout = "2m"
  }

  #install Nginx
  provisioner "remote-exec" {
    inline = [
      "echo Installing Nginx",
      "export PATH=$PATH:/usr/bin",
      "sudo apt update",
      "sudo apt install -y nginx",
      "reboot"
    ]
  }

  #install Java JRE
  provisioner "remote-exec" {
    inline = [
      "echo Installing Java JRE",
      "apt-get update",
      "apt-get install -y openjdk-11-jre",
      "java -version"
    ]
  }

 #create system user javajar 
 #and dedicated directories and configure ownership 
 provisioner "remote-exec" {
    inline = [
      "echo Creating app user and directory",
      "mkdir -p /opt/java/webapps",
      "mkdir -p /opt/java/webapps/conf",
      "useradd -s /bin/false -r -U javajar",
      "chown -R javajar:javajar /opt/java/webapps/",
      "mkdir -p /var/log/java-webapps",
      "chown -R javajar:javajar /var/log/java-webapps/"
    ]
  }

  #copy nginx config from our local machine
  #to replace the one on the server
  #the local config contains reverse-proxy
  provisioner "file" {
    source = "nginx-default-site.conf"
    destination = "/etc/nginx/sites-available/nginx-default-site.conf"
  }

  #copy the systemd file to run our spring boot app 
  #from local machine to the server
  provisioner "file" {
	source = "java-systemd-service.conf"
    destination = "/etc/systemd/system/gitlab-ci-demo.service"
  }

  #copy our sample jar file
  provisioner "file" {
    source      = "gitlab-ci-demo.jar"
    destination = "/opt/java/webapps/gitlab-ci-demo.jar"
  }

  
  #make the nginx config we copied to be the default
  provisioner "remote-exec" {
    inline = [
      "echo Configuring Nginx Sites-available file",
      "mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default-old",
      "mv /etc/nginx/sites-available/nginx-default-site.conf /etc/nginx/sites-available/default",
      "systemctl restart nginx"
    ]
  }

  #start the java service
  provisioner "remote-exec" {
    inline = [
      "echo Configuring Java systemd service",
      "systemctl enable gitlab-ci-demo.service",
      "systemctl daemon-reload",
      "systemctl start gitlab-ci-demo.service"
    ]
  }

  #configure ububtu firewall and 
  #reset the root user password
  provisioner "remote-exec" {
    inline = [
      "echo 'root:changemepassword' | chpasswd",
      "sudo ufw allow \"Nginx Full\"",
      "sudo ufw allow OpenSSH",
      "echo 'y' | ufw enable"
    ]
  }

}