#!/bin/bash

# Update and upgrade packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install required dependencies
sudo apt-get install wget unzip -y
sudo apt-get install openjdk-17-jdk -y
sudo apt-get install openjdk-17-jre -y

# Add PostgreSQL repository and key
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

# Install PostgreSQL
sudo apt-get update -y
sudo apt-get -y install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Set PostgreSQL password and create user and database
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
sudo -u postgres createuser sonar
sudo -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Download and extract SonarQube
cd /tmp
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
sudo unzip sonarqube-9.9.0.65466.zip -d /opt
sudo mv /opt/sonarqube-9.9.0.65466 /opt/sonarqube

# Set up SonarQube user and permissions
sudo groupadd sonar
sudo useradd -c "user to run SonarQube" -d /opt/sonarqube -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube -R

# Configure SonarQube
sudo bash -c 'cat <<EOL >> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
EOL'

sudo bash -c 'cat <<EOL >> /opt/sonarqube/bin/linux-x86-64/sonar.sh
RUN_AS_USER=sonar
EOL'


# Create SonarQube systemd service
sudo bash -c 'cat <<EOL >> /etc/systemd/system/sonar.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOL'

# Start and enable SonarQube service
sudo systemctl daemon-reload
sudo systemctl start sonar
sudo systemctl enable sonar

# Check SonarQube status
sudo systemctl status sonar

# Test SonarQube setup
curl http://localhost:9000
