#!/bin/bash

# Linux 系统盘清理脚本
# 功能：清理系统垃圾文件、旧内核、缓存等以释放磁盘空间
# 注意：运行前请确保有管理员权限，部分操作可能需要root权限

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
#NC='\033[0m'# No Color

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}警告: 建议使用root权限运行此脚本以执行所有清理操作${NC}"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 显示当前磁盘使用情况
echo -e "\n${GREEN}=== 当前磁盘使用情况 ===${NC}"
df -h /

# 清理APT缓存
echo -e "\n${GREEN}=== 清理APT缓存 ===${NC}"
sudo apt-get clean
sudo apt-get autoclean

# 移除不再需要的依赖包
echo -e "\n${GREEN}=== 移除不再需要的依赖包 ===${NC}"
sudo apt-get autoremove --purge

# 清理旧内核 (保留当前和上一个版本)
echo -e "\n${GREEN}=== 清理旧内核 ===${NC}"
current_kernel=$(uname -r)
echo"当前内核版本: $current_kernel"
# 更安全的旧内核清理方式
sudo apt-get purge $(dpkg -l linux-{image,headers}-* | awk '/^ii/{print $2}' | grep -vE "$current_kernel|$(echo $current_kernel | sed 's/-generic//')" | sort -u)

# 清理日志文件 (保留最近7天)
echo -e "\n${GREEN}=== 清理日志文件 ===${NC}"
find /var/log -type f -name "*.log" -mtime +7 -exec rm -f {} \;
journalctl --vacuum-time=7d

# 清理临时文件
echo -e "\n${GREEN}=== 清理临时文件 ===${NC}"
# 更安全的临时文件清理方式，不删除正在使用的文件
sudo find /tmp -type f -atime +7 -delete
sudo find /var/tmp -type f -atime +14 -delete

# 清理缩略图缓存
echo -e "\n${GREEN}=== 清理缩略图缓存 ===${NC}"
[ -d "$HOME/.cache/thumbnails" ] && rm -rf "$HOME/.cache/thumbnails"/*

# 清理浏览器缓存 (Chrome/Firefox)
#echo -e "\n${GREEN}=== 清理浏览器缓存 ===${NC}"
#for user in /home/*; do
#    [ -d "$user" ] || continue
#    echo"清理用户: $(basename "$user")"
#    [ -d "$user/.cache/google-chrome/Default/Cache" ] && rm -rf "$user/.cache/google-chrome/Default/Cache"
#    [ -d "$user/.cache/google-chrome/Default/Code Cache" ] && rm -rf "$user/.cache/google-chrome/Default/Code Cache"
#    [ -d "$user/.cache/mozilla/firefox" ] && find "$user/.cache/mozilla/firefox" -name "cache2" -exec rm -rf {} +
#done

# 清理旧的snap版本
echo -e "\n${GREEN}=== 清理旧的snap版本 ===${NC}"
if command -v snap &> /dev/null; then
    LANG=C snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision; do
        sudo snap remove "$snapname" --revision="$revision"
    done
fi

# 清理Docker无用数据
#echo -e "\n${GREEN}=== 清理Docker无用数据 ===${NC}"
#if command -v docker &> /dev/null; then
#    read -p "确定要清理所有未使用的Docker数据吗? (y/n) " -n 1 -r
#    echo
#    if [[ $REPLY =~ ^[Yy]$ ]]; then
#        docker system prune -af
#    fi
#fi

# 查找大文件 (大于100MB)
echo -e "\n${GREEN}=== 查找大文件(大于100MB) ===${NC}"
find / -xdev -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -n 20

# 显示清理后的磁盘使用情况
echo -e "\n${GREEN}=== 清理后磁盘使用情况 ===${NC}"
df -h /

echo -e "\n${GREEN}清理完成!${NC}"
