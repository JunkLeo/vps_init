#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root用户身份运行" 1>&2
   exit 1
fi

# 检测系统是否为Debian
if ! grep -qi 'debian' /etc/os-release; then
    echo "此脚本仅适用于Debian系统"
    exit 1
fi

# 获取Debian版本
DEBIAN_VERSION=$(grep 'VERSION_CODENAME' /etc/os-release | cut -d'=' -f2)

# 0. 对于Debian 11(bullseye)，更新源中的bullseye/updates为bullseye-security
if [ "$DEBIAN_VERSION" = "bullseye" ]; then
    echo "检测到Debian 11(bullseye)，正在调整安全更新源..."
   cat > /etc/apt/sources.list << EOF
   deb https://deb.debian.org/debian/ bullseye main contrib non-free
   deb-src https://deb.debian.org/debian/ bullseye main contrib non-free
   deb https://deb.debian.org/debian/ bullseye-updates main contrib non-free
   deb-src https://deb.debian.org/debian/ bullseye-updates main contrib non-free
   deb https://deb.debian.org/debian/ bullseye-backports main contrib non-free
   deb-src https://deb.debian.org/debian/ bullseye-backports main contrib non-free
   deb https://deb.debian.org/debian-security/ bullseye-security main contrib non-free
   deb-src https://deb.debian.org/debian-security/ bullseye-security main contrib non-free
   EOF
fi

# 1. 系统更新
echo "正在执行系统更新..."
apt update && apt upgrade -y && apt autoclean -y

# 2. 安装基础软件包
echo "正在安装基础软件包..."
apt install -y curl wget htop unzip tmux vim git rsync

# 3. 配置SSHD
echo "正在配置SSH服务..."
sed -i -e 's/^#*\(PermitRootLogin\s*\).*$/\1yes/' \
       -e 's/^#*\(PubkeyAuthentication\s*\).*$/\1yes/' \
       /etc/ssh/sshd_config

# 4. 配置SSH公钥
echo "正在配置SSH公钥..."
mkdir -p /root/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCtomYPaSsMNHVPHp0gEBi73U803BFI2xBYuzmJtDnJg69fFZ/l4Y3FXqMGtNsr4qXBQib7bNl05rsDgktTqoogzYECDgnvceO2zgFkYGw4fo5yFg7F1RThgb11n5kpfbiDvEf/v34jYKjnibkM21gS3KIeHio+j2hsCRqD3119uqN+mNtCEgou4g/r2OPG8RDJ0VN6TP+v5jhFAW4/t3GAzLS3gFqHoxzt7EzVSuzLcoX9oObz181dr402ArWhiT8SW6VCqVUF9TpLtp2Zc41LktZdZSrfYh2GqXR15E1wo5tQcaj//x3Ua1GcGj7vw2YEgysYvZvPxePs2UsL+5j/UyWZGHOplWR32dseCTTzBrJBboGEULc/1I9pCr8sMmWO2DwNg40YOgE5lTvGmuhQ8hTC1hq76JG/zzAT/mXCWnxTx3LJuQrvg56G0TTG8HPfQuJ2OLrKYIGWrfyeXqRKgQ03ORppoJtwzn5Utkgzrdh82d8qwnIdFTcNOstmsts= zxw1062225323@gmail.com' > /root/.ssh/authorized_keys

# 确保正确的权限设置
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# 重启SSH服务（确保使用systemctl）
systemctl restart sshd  # Debian 12使用sshd而非ssh

# 5. 启用BBR
echo "正在启用BBR拥塞控制..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 6. 安装配置Zsh
echo "正在安装Zsh及其组件..."
apt install -y zsh
chsh -s $(which zsh) root

# 安装oh-my-zsh
export ZSH=/root/.oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 安装插件
git clone https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 7. 设置时区
echo "正在设置时区..."
timedatectl set-timezone Asia/Shanghai

# 8. 下载zsh主题
echo "正在下载zsh主题..."
mkdir -p /root/.oh-my-zsh/custom/themes/
wget -q https://raw.githubusercontent.com/JunkLeo/vps_init/refs/heads/master/leo.zsh-theme \
    -O /root/.oh-my-zsh/custom/themes/leo.zsh-theme

# 9. 替换.zshrc
echo "正在配置.zshrc..."
rm -f /root/.zshrc
wget -q https://raw.githubusercontent.com/JunkLeo/vps_init/refs/heads/master/.zshrc \
    -O /root/.zshrc

# 10. 设置主机名
while true; do
    read -p "请输入新的主机名: " hostname
    if [ -n "$hostname" ]; then
        echo -e "\n您输入的主机名是: \033[1;32m$hostname\033[0m"
        read -p "是否确认？[Y/n] " confirm
        case $confirm in
            [yY]|"" )
                hostnamectl set-hostname $hostname
                echo "主机名已成功修改"
                break
                ;;
            * )
                echo "请重新输入"
                ;;
        esac
    else
        echo "主机名不能为空！"
    fi
done

echo -e "\n\033[1;32m初始化完成！\033[0m"
echo "建议执行以下操作："
echo "1. 重新连接SSH会话以体验zsh"
echo "2. 检查所有服务状态"
