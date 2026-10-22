#!/bin/bash
# Ubuntu 22.04 Desktop 离线安装脚本
#
# 用途：在 live 桌面里，把 ISO 自带的系统离线安装到磁盘（不需要联网）。
#       分区: /boot/efi 1G(fat32) + /boot 1G(ext4) + LVM(vg_sys, 全部 ext4)
#         SEPARATE_HOME=0: lv_swap 2G + lv_root 剩余全部
#         SEPARATE_HOME=1: lv_swap 2G + lv_root ROOT_SIZE + lv_home (HOME_SIZE，留空则占剩余全部)
#
# 用法：
#   1. 修改下面"配置"区域里的值（主机名、用户名、密码、目标盘等）
#   2. 在 live 桌面的终端里运行:  sudo bash install.sh
#   建议第一次先把 CHECK_ONLY 设为 1 跑一遍预检，确认没问题再改回 0 正式安装。
#
# 配置项说明：
#   NEW_HOSTNAME  主机名（字母、数字、连字符）
#   NEW_USER      用户名（小写字母开头，不能是 root）；该用户有 sudo 权限，root 账户锁定
#   NEW_PASS      用户明文密码；含特殊字符时请保持在单引号里
#   TZ_NAME       时区
#   DISK          目标盘，如 sda / nvme1n1；留空则自动选: nvme0n1 > sda > 其他非 USB 磁盘
#   AUTO_YES      1 = 跳过"输入 yes 确认"，直接清盘（慎用）；0 = 清盘前要求手动输入 yes
#   SEPARATE_HOME 0 = 不单独挂载 /home（lv_root 占剩余全部）
#                 1 = /home 单独一个 LVM 逻辑卷 lv_home（ext4）
#   ROOT_SIZE     仅 SEPARATE_HOME=1 时生效：lv_root 的大小，如 30G（至少 10G）
#   HOME_SIZE     仅 SEPARATE_HOME=1 时生效：lv_home 的大小，如 100G（至少 1G）
#                 留空 '' = 占 root 之外的剩余全部；写了大小则卷组里多余的空间保持未分配，
#                 以后可用 lvextend 扩容（root/swap/home 加起来不能超过 LVM 可用空间）
#   CHECK_ONLY    1 = 只做预检并显示将要使用的配置和磁盘，不改动任何磁盘；0 = 正式安装
set -euo pipefail

# ================= 配置（每次使用前按需修改） =================
NEW_HOSTNAME='diya'
NEW_USER='diya'
NEW_PASS='Ev@s123#ai'
TZ_NAME='Asia/Shanghai'
DISK=''
SEPARATE_HOME=0
ROOT_SIZE='12G'
HOME_SIZE='3G'
AUTO_YES=1
CHECK_ONLY=0
# ==============================================================

NTP_SERVERS="ntp.aliyun.com cn.pool.ntp.org"
VG=vg_sys
EFI_MIB=1024      # /boot/efi  fat32
BOOT_MIB=1024     # /boot      ext4
SWAP_SIZE=2G      # lv_swap

log() { echo -e "\n\033[1;32m==> $*\033[0m"; }
warn() { echo -e "\033[1;33mWARN: $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m" >&2; exit 1; }

cleanup() {
  umount -R /target 2>/dev/null || true
  umount /mnt/sq 2>/dev/null || true
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || die "请用 sudo 运行"
[ -d /sys/firmware/efi ] || die "当前不是 UEFI 启动，本脚本只支持 UEFI"

[[ "$NEW_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] \
  || die "主机名不合法: $NEW_HOSTNAME （只允许字母、数字、连字符，不能以连字符开头或结尾）"
[[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "用户名不合法: $NEW_USER （小写字母或下划线开头，只含小写字母、数字、下划线、连字符）"
[ "$NEW_USER" != "root" ] || die "用户名不能是 root"
[ -n "$NEW_PASS" ] || die "密码不能为空（NEW_PASS）"
case "$SEPARATE_HOME" in 0|1) ;; *) die "SEPARATE_HOME 只能是 0 或 1" ;; esac
if [ "$SEPARATE_HOME" = "1" ]; then
  [[ "$ROOT_SIZE" =~ ^[0-9]+[MGT]$ ]] || die "ROOT_SIZE 格式不对: $ROOT_SIZE （例如 30G）"
  if [ -n "$HOME_SIZE" ]; then
    [[ "$HOME_SIZE" =~ ^[0-9]+[MGT]$ ]] || die "HOME_SIZE 格式不对: $HOME_SIZE （例如 100G，或留空）"
  fi
fi

# ---------------- 预检（不改动磁盘） ----------------
log "预检"

for c in parted partprobe wipefs blkid pvcreate vgcreate lvcreate mkswap mkfs.ext4 chroot; do
  command -v "$c" >/dev/null 2>&1 || die "live 环境缺少命令: $c"
done
MKFS_VFAT=$(command -v mkfs.vfat || command -v mkfs.fat || true)
[ -n "$MKFS_VFAT" ] || die "live 环境缺少 mkfs.vfat/mkfs.fat"

# 找 squashfs
SQ=""
for c in /cdrom/casper/filesystem.squashfs /run/live/medium/casper/filesystem.squashfs; do
  if [ -f "$c" ]; then SQ=$c; break; fi
done
if [ -z "$SQ" ]; then
  SQ=$(find / -maxdepth 5 -name filesystem.squashfs -not -path '/proc/*' -not -path '/target/*' 2>/dev/null | head -n1 || true)
fi
if [ -z "$SQ" ]; then
  echo "没有找到 filesystem.squashfs。请执行 ls -lh /cdrom/casper/ 并把输出发给我。"
  die "找不到系统镜像"
fi
SQDIR=$(dirname "$SQ")
echo "系统镜像: $SQ"
ls -lh "$SQDIR" || true

# live 系统本身就是 squashfs 的内容，直接检查所需软件包
MISSING=""
for p in lvm2 grub-efi-amd64-signed shim-signed grub-efi-amd64-bin initramfs-tools network-manager; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING="$MISSING $p"
done
if [ -n "$MISSING" ]; then
  die "镜像里缺少软件包:$MISSING （离线无法补装，请把这行发给我）"
fi
echo "所需软件包齐全"

# 选盘
is_ok() {
  local d=$1
  [ -b "/dev/$d" ] || return 1
  [ "$(cat /sys/block/"$d"/size 2>/dev/null || echo 0)" -gt 0 ] || return 1
  [ "$(cat /sys/block/"$d"/removable 2>/dev/null || echo 0)" = "1" ] && return 1
  readlink -f "/sys/block/$d" | grep -q '/usb' && return 1
  return 0
}

if [ -n "$DISK" ]; then
  DISK=${DISK#/dev/}
  [ -b "/dev/$DISK" ] || die "指定的磁盘不存在: /dev/$DISK"
else
  DISK=""
  for d in nvme0n1 sda; do
    if is_ok "$d"; then DISK=$d; break; fi
  done
  if [ -z "$DISK" ]; then
    for p in /sys/block/*; do
      d=$(basename "$p")
      case "$d" in loop*|sr*|ram*|dm-*|md*|zram*|fd*) continue ;; esac
      if is_ok "$d"; then DISK=$d; break; fi
    done
  fi
fi
[ -n "$DISK" ] || die "没有找到合适的目标磁盘"

part() {
  case "$DISK" in
    nvme*|mmcblk*) echo "/dev/${DISK}p$1" ;;
    *) echo "/dev/${DISK}$1" ;;
  esac
}

echo
echo "目标磁盘: /dev/$DISK"
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE "/dev/$DISK" || true
echo
echo "主机名: $NEW_HOSTNAME"
echo "用户名: $NEW_USER   密码: 已设置（长度 ${#NEW_PASS}）"
echo "时区:   $TZ_NAME"

to_mib() {
  local n=${1%[MGTmgt]} u=${1: -1}
  case "$u" in
    M|m) echo "$n" ;;
    G|g) echo $((n * 1024)) ;;
    T|t) echo $((n * 1024 * 1024)) ;;
  esac
}
DISK_MIB=$(( $(blockdev --getsize64 "/dev/$DISK") / 1048576 ))
LVM_MIB=$((DISK_MIB - 1 - EFI_MIB - BOOT_MIB - 4))
SWAP_MIB=$(to_mib "$SWAP_SIZE")
if [ "$SEPARATE_HOME" = "1" ]; then
  ROOT_MIB=$(to_mib "$ROOT_SIZE")
  [ "$ROOT_MIB" -ge 10240 ] || die "ROOT_SIZE 太小（至少 10G，桌面系统本身约 7GB）"
  if [ -n "$HOME_SIZE" ]; then
    HOME_MIB=$(to_mib "$HOME_SIZE")
    [ "$HOME_MIB" -ge 1024 ] || die "HOME_SIZE 太小（至少 1G）"
    USED_MIB=$((SWAP_MIB + ROOT_MIB + HOME_MIB))
    [ "$USED_MIB" -le $((LVM_MIB - 8)) ] || die "磁盘空间不够: LVM 约 ${LVM_MIB}M，而 swap ${SWAP_MIB}M + root ${ROOT_MIB}M + home ${HOME_MIB}M = ${USED_MIB}M，请减小 ROOT_SIZE 或 HOME_SIZE"
    FREE_MIB=$((LVM_MIB - USED_MIB))
    echo "分区预估: /boot/efi ${EFI_MIB}M, /boot ${BOOT_MIB}M, lv_swap ${SWAP_MIB}M, lv_root ${ROOT_MIB}M, lv_home ${HOME_MIB}M, 卷组内未分配约 ${FREE_MIB}M"
  else
    HOME_MIB=$((LVM_MIB - SWAP_MIB - ROOT_MIB))
    [ "$HOME_MIB" -ge 1024 ] || die "磁盘空间不够: LVM 约 ${LVM_MIB}M，swap ${SWAP_MIB}M + root ${ROOT_MIB}M 之后剩余不足 1G，请减小 ROOT_SIZE"
    echo "分区预估: /boot/efi ${EFI_MIB}M, /boot ${BOOT_MIB}M, lv_swap ${SWAP_MIB}M, lv_root ${ROOT_MIB}M, lv_home 约 ${HOME_MIB}M（占剩余全部）"
  fi
else
  ROOT_MIB=$((LVM_MIB - SWAP_MIB))
  [ "$ROOT_MIB" -ge 10240 ] || die "磁盘太小: 除去 swap 后 root 不足 10G"
  echo "分区预估: /boot/efi ${EFI_MIB}M, /boot ${BOOT_MIB}M, lv_swap ${SWAP_MIB}M, lv_root 约 ${ROOT_MIB}M（无单独 /home）"
fi

if [ "$CHECK_ONLY" = "1" ]; then
  log "预检通过（CHECK_ONLY=1，不继续安装）"
  exit 0
fi

if [ "$AUTO_YES" != "1" ]; then
  echo
  echo "!!! 将清空 /dev/$DISK 上的全部数据 !!!"
  read -r -p "输入 yes 继续: " ans </dev/tty
  [ "$ans" = "yes" ] || die "已取消"
fi

# ---------------- 清理旧数据 ----------------
log "清理 /dev/$DISK 上的旧分区和 LVM"
umount -R /target 2>/dev/null || true
swapoff -a 2>/dev/null || true

for vg in $(pvs --noheadings -o vg_name,pv_name 2>/dev/null | awk -v d="/dev/$DISK" 'index($2,d)==1{print $1}' | sort -u); do
  vgchange -an "$vg" || true
  vgremove -ff -y "$vg" || true
done
for pv in $(pvs --noheadings -o pv_name 2>/dev/null | awk -v d="/dev/$DISK" 'index($1,d)==1{print $1}'); do
  pvremove -ff -y "$pv" || true
done
if vgs "$VG" >/dev/null 2>&1; then
  die "卷组 $VG 已存在于其他磁盘上，会冲突。请先处理该卷组或修改脚本里的 VG 名"
fi

for n in $(lsblk -ln -o NAME "/dev/$DISK" | tail -n +2); do
  wipefs -af "/dev/$n" 2>/dev/null || true
done
wipefs -af "/dev/$DISK" 2>/dev/null || true

# ---------------- 分区 ----------------
log "分区: EFI ${EFI_MIB}M / boot ${BOOT_MIB}M / LVM"
EFI_END=$((1 + EFI_MIB))
BOOT_END=$((EFI_END + BOOT_MIB))
parted -s "/dev/$DISK" mklabel gpt
parted -s "/dev/$DISK" mkpart ESP fat32 1MiB "${EFI_END}MiB"
parted -s "/dev/$DISK" set 1 esp on
parted -s "/dev/$DISK" mkpart boot ext4 "${EFI_END}MiB" "${BOOT_END}MiB"
parted -s "/dev/$DISK" mkpart lvm "${BOOT_END}MiB" 100%
parted -s "/dev/$DISK" set 3 lvm on
partprobe "/dev/$DISK" || true
udevadm settle || true
sleep 2

P1=$(part 1); P2=$(part 2); P3=$(part 3)
for p in "$P1" "$P2" "$P3"; do [ -b "$p" ] || die "分区设备没有出现: $p"; done

log "格式化"
"$MKFS_VFAT" -F32 -n EFI "$P1"
mkfs.ext4 -F -L boot "$P2"
pvcreate -ff -y "$P3"
vgcreate "$VG" "$P3"
lvcreate -y -L "$SWAP_SIZE" -n lv_swap "$VG"
if [ "$SEPARATE_HOME" = "1" ]; then
  lvcreate -y -L "$ROOT_SIZE" -n lv_root "$VG"
  if [ -n "$HOME_SIZE" ]; then
    lvcreate -y -L "$HOME_SIZE" -n lv_home "$VG"
  else
    lvcreate -y -l 100%FREE -n lv_home "$VG"
  fi
else
  lvcreate -y -l 100%FREE -n lv_root "$VG"
fi
mkswap -L swap "/dev/$VG/lv_swap"
mkfs.ext4 -F -L root "/dev/$VG/lv_root"
if [ "$SEPARATE_HOME" = "1" ]; then
  mkfs.ext4 -F -L home "/dev/$VG/lv_home"
fi

# ---------------- 挂载并复制系统 ----------------
log "挂载目标盘"
mkdir -p /target
mount "/dev/$VG/lv_root" /target
mkdir -p /target/boot
mount "$P2" /target/boot
mkdir -p /target/boot/efi
mount "$P1" /target/boot/efi
if [ "$SEPARATE_HOME" = "1" ]; then
  mkdir -p /target/home
  mount "/dev/$VG/lv_home" /target/home
fi

log "复制系统（需要几分钟）"
mkdir -p /mnt/sq
mount -t squashfs -o loop,ro "$SQ" /mnt/sq
if command -v rsync >/dev/null 2>&1; then
  rsync -aHAX --numeric-ids --info=progress2 /mnt/sq/ /target/
else
  warn "没有 rsync，改用 cp -a（无进度显示）"
  cp -a /mnt/sq/. /target/
fi
umount /mnt/sq

# squashfs 里通常不带 /boot/vmlinuz-*，内核单独放在 ISO 的 casper/vmlinuz。
# 当前 live 系统正在运行的就是这个内核，它的模块已经随 squashfs 复制进了目标系统。
KVER=$(uname -r)
if ! ls /target/boot/vmlinuz-* >/dev/null 2>&1; then
  warn "目标系统 /boot 里没有内核，尝试从 ISO 的 casper 目录补上 (内核版本 $KVER)"
  [ -f "$SQDIR/vmlinuz" ] || die "找不到 $SQDIR/vmlinuz，无法补内核（请把 ls -lh $SQDIR 的输出发给我）"
  [ -d "/target/lib/modules/$KVER" ] || die "目标系统缺少内核模块目录 /lib/modules/$KVER，内核版本对不上，无法补内核"
  cp "$SQDIR/vmlinuz" "/target/boot/vmlinuz-$KVER"
  echo "已补入内核: /boot/vmlinuz-$KVER"
fi
ls /target/boot/vmlinuz-* >/dev/null 2>&1 || die "目标系统 /boot 里仍然没有内核"

# ---------------- 系统配置 ----------------
log "写入 fstab / 主机名 / 网络"
EFI_UUID=$(blkid -s UUID -o value "$P1")
BOOT_UUID=$(blkid -s UUID -o value "$P2")

cat > /target/etc/fstab <<EOF
# <file system> <mount point> <type> <options> <dump> <pass>
/dev/mapper/${VG}-lv_root / ext4 errors=remount-ro 0 1
UUID=${BOOT_UUID} /boot ext4 defaults 0 2
UUID=${EFI_UUID} /boot/efi vfat umask=0077 0 1
/dev/mapper/${VG}-lv_swap none swap sw 0 0
EOF
if [ "$SEPARATE_HOME" = "1" ]; then
  echo "/dev/mapper/${VG}-lv_home /home ext4 defaults 0 2" >> /target/etc/fstab
fi

echo "$NEW_HOSTNAME" > /target/etc/hostname
cat > /target/etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 ${NEW_HOSTNAME}

::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

: > /target/etc/machine-id
rm -f /target/var/lib/dbus/machine-id

mkdir -p /target/etc/netplan
if ! ls /target/etc/netplan/*.yaml >/dev/null 2>&1; then
  printf 'network:\n  version: 2\n  renderer: NetworkManager\n' > /target/etc/netplan/01-network-manager-all.yaml
  chmod 600 /target/etc/netplan/01-network-manager-all.yaml
fi

mkdir -p /target/etc/systemd/timesyncd.conf.d
printf '[Time]\nNTP=%s\n' "$NTP_SERVERS" > /target/etc/systemd/timesyncd.conf.d/ntp.conf

# 要从目标系统里清除的 live 专用软件包（来自 ISO 自带清单）
if [ -f "$SQDIR/filesystem.manifest-remove" ]; then
  cp "$SQDIR/filesystem.manifest-remove" /target/tmp/remove.list
else
  : > /target/tmp/remove.list
fi

log "进入 chroot 配置用户、时区、引导"
for d in dev dev/pts proc run; do mount --bind "/$d" "/target/$d"; done
mount --rbind /sys /target/sys
mount --make-rslave /target/sys

chroot /target env \
  NEW_USER="$NEW_USER" NEW_PASS="$NEW_PASS" TZ_NAME="$TZ_NAME" \
  DEBIAN_FRONTEND=noninteractive /bin/bash -s <<'EOS'
set -e

# 用户
id "$NEW_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash -c "$NEW_USER" "$NEW_USER"
for g in adm cdrom sudo dip plugdev lpadmin sambashare; do
  if getent group "$g" >/dev/null; then usermod -aG "$g" "$NEW_USER"; fi
done
echo "$NEW_USER:$NEW_PASS" | chpasswd
passwd -l root >/dev/null 2>&1 || true
mkdir -p "/home/$NEW_USER/.config"
touch "/home/$NEW_USER/.config/gnome-initial-setup-done"
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.config"

# 时区
ln -sf "/usr/share/zoneinfo/$TZ_NAME" /etc/localtime
echo "$TZ_NAME" > /etc/timezone

# 防火墙
systemctl disable ufw >/dev/null 2>&1 || true

# 清除 live 专用软件包
PK=""
for p in $(cut -f1 /tmp/remove.list); do
  if dpkg -s "$p" >/dev/null 2>&1; then PK="$PK $p"; fi
done
if [ -n "$PK" ]; then
  apt-get -y purge $PK || echo "WARN: 清除 live 软件包失败，已忽略"
fi
rm -f /tmp/remove.list

# 兜底：清掉 live 安装器 ubiquity / casper 的残留，并去掉 dock 上的"Install Ubuntu"启动器
apt-get -y purge 'ubiquity*' casper lupin-casper >/dev/null 2>&1 || true
rm -f /usr/share/applications/ubiquity*.desktop
for f in $(grep -rIl 'ubiquity' /usr/share/glib-2.0/schemas /etc/dconf 2>/dev/null || true); do
  sed -i -e "s/, *'ubiquity[^']*\.desktop'//g" -e "s/'ubiquity[^']*\.desktop', *//g" "$f"
done
glib-compile-schemas /usr/share/glib-2.0/schemas >/dev/null 2>&1 || true
dconf update >/dev/null 2>&1 || true

# initramfs + 引导
update-initramfs -c -k all
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck \
  || grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
update-grub
EOS

[ -f /target/boot/efi/EFI/ubuntu/grubx64.efi ] || [ -f /target/boot/efi/EFI/BOOT/BOOTX64.EFI ] \
  || die "EFI 引导文件没有生成，请检查上面的 grub-install 输出"

sync
log "完成。检查结果:"
lsblk -f "/dev/$DISK"
echo
echo "确认无误后执行 reboot。注意：虚拟机/BIOS 的启动顺序如果是网络优先，"
echo "重启会再次进入 PXE 菜单，需要选择本地硬盘启动或调整启动顺序。"
