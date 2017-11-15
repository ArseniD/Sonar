#!/bin/bash


########################
# Install Java
########################
echo "Installing Java"
yum -y install git vim net-tools
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
# Jenkins
########################
echo "Installing Jenkins"
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
rpm --import http://pkg.jenkins-ci.org/redhat-stable/jenkins-ci.org.key
yum -y install deltarpm jenkins unzip

echo "Setup JENKINS_HOME"
cat <<EOT >> /etc/profile.d/jenkins.sh
#!/bin/bash
export JENKINS_HOME=/var/lib/jenkins/
EOT
chmod +x /etc/profile.d/jenkins.sh
source /etc/profile.d/jenkins.sh

systemctl start jenkins && systemctl enable jenkins


########################
# Maven
########################
echo "Installing Maven"
cd /usr/local
wget http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz
tar xzf apache-maven-3.5.2-bin.tar.gz
rm -f /usr/local/apache-maven-3.5.2-bin.tar.gz
ln -s apache-maven-3.5.2  maven
cat > /etc/profile.d/maven.sh <<\EOF
#!/bin/bash
export M2_HOME=/usr/local/maven
export PATH=$M2_HOME/bin:$PATH
EOF
source /etc/profile.d/maven.sh
chmod +x /etc/profile.d/maven.sh
echo "Check Maven version"
mvn -version


########################
# Gradle
########################
gradle_version=4.3.1
mkdir /usr/local/gradle
cd /usr/local
wget -N http://downloads.gradle.org/distributions/gradle-${gradle_version}-all.zip
unzip -oq ./gradle-${gradle_version}-all.zip -d /usr/local/gradle
rm -f /usr/local/gradle-${gradle_version}-all.zip
ln -sfnv gradle-${gradle_version} /usr/local/gradle/latest
#printf "#!/bin/bash\nexport GRADLE_HOME=/usr/local/gradle/latest\nexport PATH=\$PATH:\$GRADLE_HOME/bin" > /etc/profile.d/gradle.sh
cat > /etc/profile.d/gradle.sh <<\EOF
#!/bin/bash
export GRADLE_HOME=/usr/local/gradle/latest
export PATH=$PATH:$GRADLE_HOME/bin
EOF
source /etc/profile.d/gradle.sh
chmod +x /etc/profile.d/gradle.sh
echo "Check Gradle version"
gradle -version


########################
# nginx
########################
echo "Installing nginx"
yum -y install nginx > /dev/null 2>&1


########################
# Configuring nginx
########################
echo "Configuring nginx"
sed -e 's/80/8081/' -i /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/jenkins.conf <<\EOF
upstream app_server {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80 default ipv6only=on;
    server_name jenkins;

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
systemctl restart  nginx && systemctl enable nginx
source /etc/profile.d/maven.sh
source /etc/profile.d/gradle.sh


########################
# Configuring /etc/hosts
########################
echo "10.0.0.11 sonar" >> /etc/hosts
echo "Success"

exit 0
