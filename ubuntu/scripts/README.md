# ubuntu 脚本

## auto_port_forward_ssh
开机自启端口转发脚本
```sh
tar -xzvf auto_port_forward_ssh.tar.gz
cd auto_port_forward_ssh

# 修改要转发的端口和远程服务器相关信息
vim auto_port_forward_ssh.sh

chmod +x auto_port_forward_ssh.sh
sudo cp auto_port_forward_ssh.sh /home/<username>/scripts
sudo cp auto_port_forward_ssh.service /etc/systemd/system/

# 修改 Service 下的 User 为用户名<username>
# 修改 Service 下的 ExecStart 为 /home/<username>/scripts/auto_port_forward_ssh.sh
# 一定要配置好 <username> 用户与 远程服务器的 ssh 互信
sudo vim /etc/systemd/system/auto_port_forward_ssh.service

sudo systemctl daemon-reload
sudo systemctl enable auto_port_forward_ssh.service
sudo systemctl start auto_port_forward_ssh.service
