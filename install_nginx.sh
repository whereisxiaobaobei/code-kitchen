#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请以root用户运行此脚本"
    exit 1
fi

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "无法检测操作系统类型，脚本退出。"
    exit 1
fi

install_nginx_debian_ubuntu() {
    # 更新包列表
    apt update

    # 安装必要的包
    apt install -y curl gnupg2 ca-certificates lsb-release

    # 导入官方nginx签名密钥
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

    # 设置apt仓库
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/$OS `lsb_release -cs` nginx" \
        | tee /etc/apt/sources.list.d/nginx.list

    # 设置仓库固定
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
        | tee /etc/apt/preferences.d/99nginx

    # 更新apt包列表
    apt update

    # 安装nginx
    apt install -y nginx
}

install_nginx_centos() {
    # 安装EPEL仓库
    yum install epel-release -y

    # 创建nginx.repo文件
    cat > /etc/yum.repos.d/nginx.repo << EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

    # 安装nginx
    yum install nginx -y
}

# 根据操作系统类型安装nginx
case $OS in
    debian|ubuntu)
        install_nginx_debian_ubuntu
        ;;
    centos)
        install_nginx_centos
        ;;
    *)
        echo "不支持的操作系统: $OS"
        exit 1
        ;;
esac

# 启动nginx服务
systemctl start nginx

# 设置nginx开机自启
systemctl enable nginx

# 检查nginx状态
systemctl status nginx

# 打印nginx版本
nginx -v

echo "nginx安装完成并已启动。"

# 提示防火墙设置
if [ "$OS" == "centos" ]; then
    echo "注意：如果您启用了防火墙，可能需要开放80端口："
    echo "firewall-cmd --permanent --add-service=http"
    echo "firewall-cmd --reload"
else
    echo "注意：如果您启用了UFW防火墙，可能需要开放80端口："
    echo "sudo ufw allow 'Nginx HTTP'"
fi
