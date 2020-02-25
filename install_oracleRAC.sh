#!/usr/bin/env bash
yum install wget -y
yum install curl -y
curl -fsSL https://get.docker.com/ | sh
yum install docker-engine docker-cli
sudo systemctl start docker
sudo systemctl enable docker
cd /home/centos
git clone https://github.com/oracle/docker-images.git

echo "
fs.file-max = 6815744
net.core.rmem_max = 4194304
net.core.rmem_default = 262144
net.core.wmem_max = 1048576
net.core.wmem_default = 262144
net.core.rmem_default = 262144
" >> /etc/sysctl.conf

sysctl -a
sysctl -p

docker network create --driver=bridge --subnet=172.16.1.0/24 rac_pub1_nw
docker network create --driver=bridge --subnet=192.168.17.0/24 rac_priv1_nw

# Download RAC and GRID binaries
cp /home/centos/

# TODO:VM/EC2 needs to have a separate volume for ASM

mkdir /opt/containers
touch /opt/containers/rac_host_file
mkdir /opt/.secrets/
openssl rand -hex 64 -out /opt/.secrets/pwd.key
touch /opt/.secrets/common_os_pwdfile
echo 'cisco1234567890' > /opt/.secrets/common_os_pwdfile
openssl enc -aes-256-cbc -salt -in /opt/.secrets/common_os_pwdfile -out /opt/.secrets/common_os_pwdfile.enc -pass file:/opt/.secrets/pwd.key

# TODO:GET the volume name from fdisk+lsblk
#By default xvdf(used below)

docker create -t -i \
  --hostname racnode1 \
  --volume /boot:/boot:ro \
  --volume /dev/shm \
  --tmpfs /dev/shm:rw,exec,size=4G \
  --volume /opt/containers/rac_host_file:/etc/hosts  \
  --volume /opt/.secrets:/run/secrets \
  --dns-search=example.com \
  --device=/dev/xvdf:/dev/asm_disk1 \
  --privileged=false  \
  --cap-add=SYS_NICE \
  --cap-add=SYS_RESOURCE \
  --cap-add=NET_ADMIN \
  -e NODE_VIP=172.16.1.160 \
  -e VIP_HOSTNAME=racnode1-vip  \
  -e PRIV_IP=192.168.17.150 \
  -e PRIV_HOSTNAME=racnode1-priv \
  -e PUBLIC_IP=172.16.1.150 \
  -e PUBLIC_HOSTNAME=racnode1  \
  -e SCAN_NAME=racnode-scan \
  -e SCAN_IP=172.16.1.70  \
  -e OP_TYPE=INSTALL \
  -e DOMAIN=example.com \
  -e ASM_DEVICE_LIST=/dev/asm_disk1 \
  -e ASM_DISCOVERY_DIR=/dev \
  -e CMAN_HOSTNAME=racnode-cman1 \
  -e CMAN_IP=172.16.1.15 \
  -e COMMON_OS_PWD_FILE=common_os_pwdfile.enc \
  -e PWD_KEY=pwd.key \
  --restart=always --tmpfs=/run -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cpu-rt-runtime=95000 --ulimit rtprio=99  \
  --name racnode1 \
  oracle/database-rac:19.3.0

# Use cgroups driver as cgroups instead of systemd
sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --cpu-rt-runtime=950000 --cpu-rt-period=1000000 --exec-opt=native.cgroupdriver=cgroupfs|' /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl stop docker
systemctl start docker

docker network disconnect bridge racnode1
docker network connect rac_pub1_nw --ip 172.16.1.150 racnode1
docker network connect rac_priv1_nw --ip 192.168.17.150  racnode1

docker start racnode1
# docker logs -f racnode1
# Wait 40 minutes here
# docker run -ti -p 1521:1521 racnode1

# COnnecting to DB
#docker exec -i -t racnode2 /bin/bash
#export ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
#export ORACLE_SID=ORCLCDB1
#sqlplus /as\ sysdba
#select * from v$instance;
#SQL> startup;