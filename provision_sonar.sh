#!/bin/bash


########################
# Install Java
########################
echo "Installing Java"
yum -y install git net-tools vim unzip
cd /opt/
wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.tar.gz"
tar xzf jdk-8u151-linux-x64.tar.gz
rm -f jdk-8u151-linux-x64.tar.gz
cd /opt/jdk1.8.0_151/
alternatives --install /usr/bin/java java /opt/jdk1.8.0_151/bin/java 2
alternatives --config java <<< "2"
alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_151/bin/jar 2
alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_151/bin/javac 2
alternatives --set jar /opt/jdk1.8.0_151/bin/jar
alternatives --set javac /opt/jdk1.8.0_151/bin/javac

echo "Check java version"
java -version

echo "Setup Java Environment Variables"
cat <<EOT >> /etc/profile.d/java.sh
#!/bin/bash
export JAVA_HOME=/opt/jdk1.8.0_151
export JRE_HOME=/opt/jdk1.8.0_151/jre
export PATH=$PATH:/opt/jdk1.8.0_151/bin:/opt/jdk1.8.0_151/jre/bin
EOT

chmod +x /etc/profile.d/java.sh
source /etc/profile.d/java.sh

echo "Check JAVA_HOME"
echo $JAVA_HOME

cat <<EOT >> ~/.bash_profile
export JAVA_HOME=/opt/jdk1.8.0_151
export JRE_HOME=/opt/jdk1.8.0_151/jre
export PATH=$PATH:/opt/jdk1.8.0_151/bin:/opt/jdk1.8.0_151/jre/bin
EOT


########################
# Install PostgreSQL
########################
rpm -Uvh https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-1.noarch.rpm
yum install -y postgresql10-server postgresql10


########################
# Configuring PostgreSQL
########################
/usr/pgsql-10/bin/postgresql-10-setup initdb
sed -ri 's/peer/trust/g;s/ident/md5/g' /var/lib/pgsql/10/data/pg_hba.conf

systemctl start postgresql-10
systemctl enable postgresql-10
systemctl status postgresql-10
netstat -antup | grep 5432

echo "postgres:P@ssw0rd" | chpasswd
su - postgres <<EOSU
createuser sonar
psql -c "ALTER USER sonar WITH ENCRYPTED password 'P@ssw0rd';"
psql -c "CREATE DATABASE sonar OWNER sonar;"
psql -c "\q"
EOSU

systemctl restart postgresql-10


########################
# Installing SonarQube
########################
mkdir -p /usr/local/sonarqube
wget https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-6.7.zip -O /usr/local/sonarqube/sonarqube-6.7.zip
unzip /usr/local/sonarqube/sonarqube-6.7.zip -d /usr/local/sonarqube/
ln -s /usr/local/sonarqube/sonarqube-6.7 /usr/local/sonarqube/sonar
rm -f /usr/local/sonarqube/sonarqube-6.7.zip


########################
# Configuring SonarQube
########################
sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=sonar/g' /usr/local/sonarqube/sonar/conf/sonar.properties
sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=P@ssw0rd/g' /usr/local/sonarqube/sonar/conf/sonar.properties
sed -i '/^#sonar.jdbc.url=jdbc:postgresql:\/\/localhost\/sonar/s/^#//' /usr/local/sonarqube/sonar/conf/sonar.properties

/usr/local/sonarqube/sonar/bin/linux-x86-64/sonar.sh start

useradd sonar

cat <<EOF > /etc/systemd/system/sonar.service
[Unit]
Description=SonarQube
After=network.target network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/local/sonarqube/sonar/bin/linux-x86-64/sonar.sh start
ExecStop=/usr/local/sonarqube/sonar/bin/linux-x86-64/sonar.sh stop
ExecReload=/usr/local/sonarqube/sonar/bin/linux-x86-64/sonar.sh restart
Type=forking
User=sonar
[Install]
WantedBy=multi-user.target
EOF


########################
# Install SonarScanner
########################
mkdir -p /usr/local/sonarscanner
wget https://sonarsource.bintray.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.0.3.778-linux.zip -O /usr/local/sonarscanner/sonar-scanner-cli-3.0.3.778-linux.zip
unzip /usr/local/sonarscanner/sonar-scanner-cli-3.0.3.778-linux.zip -d /usr/local/sonarscanner/
ln -s /usr/local/sonarscanner/sonar-scanner-3.0.3.778-linux /usr/local/sonarscanner/scanner
rm -f /usr/local/sonarscanner/sonar-scanner-cli-3.0.3.778-linux.zip


########################
# Install Nginx
########################
echo "Installing nginx"
yum -y install nginx > /dev/null 2>&1


########################
# Configuring nginx
########################
echo "Configuring nginx"
sed -e 's/80/8081/' -i /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/sonar.conf <<\EOF
upstream app_server {
    server 127.0.0.1:9000 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80 default ipv6only=on;
    server_name sonar;

    location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;

        if (!-f $request_filename) {
            proxy_pass http://app_server;
            break;
        }
    }
}
EOF

systemctl start  nginx && systemctl enable nginx
systemctl start sonar && systemctl enable sonar

chown -R sonar:sonar /usr/local/sonarqube/
sudo reboot

echo "Success! Rebooting.."
exit 0
