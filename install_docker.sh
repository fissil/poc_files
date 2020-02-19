#!/usr/bin/env bash
curl -fsSL https://get.docker.com/ | sh
sudo systemctl start docker
sudo systemctl enable docker
cd /home/centos
git clone https://github.com/oracle/docker-images.git

# Download WebLogic Docker install image
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1GSupO95dOjEDQxrO2zA0EuNEAtMDNdzA' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1GSupO95dOjEDQxrO2zA0EuNEAtMDNdzA" -O fmw_12.2.1.3.0_wls_Disk1_1of1.zip && rm -rf /tmp/cookies.txt

# Download Server JRE
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1tX6FRFw2S6MF_v-kRurex_qbmGjEN7Xx' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1tX6FRFw2S6MF_v-kRurex_qbmGjEN7Xx" -O server-jre-8u241-linux-x64.tar.gz && rm -rf /tmp/cookies.txt

#Download WebLogic Server 12cR2 with MedRec sample domain
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1DAszmWgS8vKs6FyPxzVDo2jL_kfPooOG' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1DAszmWgS8vKs6FyPxzVDo2jL_kfPooOG" -O fmw_12.2.1.3.0_wls_supplemental_quick_Disk1_1of1.zip && rm -rf /tmp/cookies.txt

# Pull oracle image Linux
sudo docker image pull oraclelinux:7-slim

# Build Oracle JDK11
#cd /home/centos/docker-images/OracleJava/java-11
#docker build -t oracle/jdk:11 .

# Build Oracle Server JRE8
#mv fmw_12.2.1.3.0_wls_Disk1_1of1.zip /home/centos/docker-images/OracleJava/java-8
mv server-jre-8u241-linux-x64.tar.gz /home/centos/docker-images/OracleJava/java-8
cd /home/centos/docker-images/OracleJava/java-8
sudo sh build.sh

# Build Weblogic Server base image
cd /home/centos/docker-images/OracleWebLogic/dockerfiles
mv /home/centos/fmw_12.2.1.3.0_wls_Disk1_1of1.zip /home/centos/docker-images/OracleWebLogic/dockerfiles/12.2.1.3/
sh buildDockerImage.sh -v 12.2.1.3 -g

# Build the WebLogic Server 12cR2 with MedRec sample domain
cd /home/centos/docker-images/OracleWebLogic/samples
cp -r 12212-medrec 12213-medrec
mv /home/centos/fmw_12.2.1.3.0_wls_supplemental_quick_Disk1_1of1.zip 12213-medrec/
cd 12213-medrec
sed -i 's/weblogic:12.2.1.2-developer/weblogic:12.2.1.3-generic/g' Dockerfile
sed -i 's/fmw_12.2.1.2.0_wls_supplemental_quick_Disk1_1of1.zip/fmw_12.2.1.3.0_wls_supplemental_quick_Disk1_1of1.zip/g' Dockerfile
sed -i 's/fmw_12.2.1.2.0_wls_supplemental_quick.jar/fmw_12.2.1.3.0_wls_supplemental_quick.jar/g' Dockerfile
# creating SWAP of 2GB to satisfy the requirements
dd if=/dev/zero of=/swapfile bs=1024 count=2048k
mkswap /swapfile
swapon /swapfile

# build medrec application
docker build -t 12213-medrec .


# run the application if needed
#docker run -ti -p 7011:7011 12213-medrec
#http://localhost:7011/medrec
#docker exec -it 5aac0440c9b0 bash
