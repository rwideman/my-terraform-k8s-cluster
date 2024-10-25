#!/bin/bash
# Source: https://medium.com/@rabbi.cse.sust.bd/kubernetes-cluster-setup-on-ubuntu-24-04-lts-server-c17be85e49d1
# WORKER NODES

export AWS_ACCESS_KEY_ID=${access_key}
export AWS_SECRET_ACCESS_KEY=${private_key}
export AWS_DEFAULT_REGION=${region}

swapoff -a
sed -i '/swap/d' /etc/fstab
mount -a
ufw disable
hostname k8s-msr-1
echo "k8s-msr-1" > /etc/hostname
apt-get update
apt install apt-transport-https ca-certificates curl software-properties-common curl vim gpg -y

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install containerd.io awscli kubeadm kubelet kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Configure persistent loading of modules
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
sysctl --system

modprobe overlay
modprobe br_netfilter


#next line is getting EC2 instance IP, for kubeadm to initiate cluster
#we need to get EC2 internal IP address- default ENI is eth0
export ipaddr=`ip address|grep eth0|grep inet|awk -F ' ' '{print $2}' |awk -F '/' '{print $1}'`
export pubip=`dig +short myip.opendns.com @resolver1.opendns.com`

# the kubeadm init won't work entel remove the containerd config and restart it.
rm /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
echo 1 | tee /proc/sys/net/ipv4/ip_forward
sh -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf"
sysctl -p
sysctl --system

# to insure the join command start when the installion of master node is done.
sleep 1m

aws s3 cp s3://${s3buckit_name}/join_command.sh /tmp/.
chmod +x /tmp/join_command.sh
bash /tmp/join_command.sh
