#!/bin/bash


apt-mark hold linux-image-6.8.0-40-generic
apt-mark hold linux-headers-6.8.0-40-generic
apt-mark hold linux-modules-6.8.0-40-generic
apt update
apt install -y vim net-tools openssh-server gcc-12 g++-12 make nfs-common
tar -jxvf r8126-10.016.00.tar.bz2
cd r8126-10.016.00/
./autorun.sh
sed -i "s/#Port 22/Port 17022/g" /etc/ssh/sshd_config
systemctl restart sshd
