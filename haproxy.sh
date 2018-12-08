#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   System Required:  CentOS                                      #
#   Description: Install haproxy for Shadowsocks server           #
#   Author: RoFatNya	                                          #
#   Intro:  https://www.github.com/RoFatNya/haproxy/README        #
#=================================================================#

clear
echo ""
echo "#############################################################"
echo "# Install haproxy for Shadowsocks server                    #"
echo "#                                                           #"
echo "# Author: RoFatNya                                           #"
echo "#############################################################"
echo ""

rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error:This script must be run as root!" 1>&2
       exit 1
    fi
}

checkos(){
    if [[ -f /etc/redhat-release ]];then
        OS=CentOS
    elif cat /etc/issue | grep -q -E -i "debian";then
        OS=Debian
    elif cat /etc/issue | grep -q -E -i "ubuntu";then
        OS=Ubuntu
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat";then
        OS=CentOS
    elif cat /proc/version | grep -q -E -i "debian";then
        OS=Debian
    elif cat /proc/version | grep -q -E -i "ubuntu";then
        OS=Ubuntu
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat";then
        OS=CentOS
    else
        echo "Not supported OS, Please reinstall OS and try again."
        exit 1
    fi
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

valid_ip(){
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return ${stat}
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\." | head -n 1 )
    if [ -z ${IP} ]; then
        IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    fi
    echo ${IP}
}

# Pre-installation settings
function pre_install(){
    # Set haproxy config start port
    while :
    do
    echo -e "Please input start port for haproxy & shadowsocks [1-65535]"
    read -p "(Default start port: 50001):" startport
	[ -z "${startport}" ] && startport="50001"
    expr ${startport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${startport} -ge 1 ] && [ ${startport} -le 65535 ]; then
            echo ""
            echo "---------------------------"
            echo "start port = ${startport}"
            echo "---------------------------"
            echo ""
            break
        else
            echo "Input error! Please input correct numbers."
        fi
    else
        echo "Input error! Please input correct numbers."
    fi
    done

    # Set haproxy config end port
    while :
    do
    echo -e "Please input end port for haproxy & shadowsocks [1-65535]"
    read -p "(Default end port: 60000):" endport
	[ -z "${endport}" ] && endport="60000"
    expr ${endport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${endport} -ge 1 ] && [ ${endport} -le 65535 ]; then
            echo ""
            echo "---------------------------"
            echo "end port = ${endport}"
            echo "---------------------------"
            echo ""
            break
        else
            echo "Input error! Please input correct numbers."
        fi
    else
        echo "Input error! Please input correct numbers."
    fi
    done
	
    # Set haproxy config IPv4 address
    while :
    do
    echo -e "Please input your shadowsocks IPv4 address for haproxy"
    read -p "(IPv4 is):" haproxyip
    valid_ip ${haproxyip}
    if [ $? -eq 0 ]; then
        echo ""
        echo "---------------------------"
        echo "IP = ${haproxyip}"
        echo "---------------------------"
        echo ""
        break
    else
        echo "Input error! Please input correct IPv4 address."
    fi
    done

    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo ""
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`

}

# Config haproxy
config_haproxy(){
    # Config DNS nameserver
    if ! grep -q "8.8.8.8" /etc/resolv.conf;then
        cp -p /etc/resolv.conf /etc/resolv.conf.bak
        echo "nameserver 223.5.5.5" > /etc/resolv.conf
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    fi

    if [ -f /etc/haproxy/haproxy.cfg ];then
        cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
    fi

    cat > /etc/haproxy/haproxy.cfg<<-EOF
global
    ulimit-n  51200
    maxconn 256
	log /home/logs/haproxy/ local0
	daemon
    
defaults
    mode tcp
    log global
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

listen status
    bind 0.0.0.0:1080
    mode http
    log global
    stats refresh 30s

frontend ss-in
    bind *:${startport}-${endport}
    default_backend ssout
	
backend ss-out
    server server1 ${haproxyip} maxconn 204800
EOF
}

download(){
    TEMP_PATH=/tmp
    HAPROXY_NAME=haproxy-1.8.5.tar.gz
    HAPROXY_VERSION='1.8.5'
    wget -O ${TEMP_PATH}/${HAPROXY_NAME} https://github.com/RoFatNya/haproxy/raw/master/haproxy-1.8.5.tar.gz
	
}

install(){
    # Install haproxy
    if [ "${OS}" == 'CentOS' ];then
        #yum install -y haproxy

        TEMP_WORK_PATH=${TEMP_PATH}/haproxy-1.8.5
        cd ${TEMP_PATH}
        tar -xzvf ${HAPROXY_NAME} 
        cd ${TEMP_WORK_PATH}
        make TARGET=linux2628 USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1
        make install
        make clean
	
    else
        apt-get -y update
        apt-get install -y haproxy
    fi

    if [ -d /etc/haproxy ]; then
        echo "haproxy install successed."

        echo "Config haproxy start..."
        config_haproxy
        echo "Config haproxy completed..."

        if [ "${OS}" == 'CentOS' ]; then
            chkconfig --add haproxy
            chkconfig haproxy on
        else
            update-rc.d haproxy defaults
        fi

        # Start haproxy
        /etc/init.d/haproxy start
        if [ $? -eq 0 ]; then
            echo "haproxy start success..."
        else
            echo "haproxy start failure..."
        fi
    else
        echo ""
        echo "haproxy install failed."
        exit 1
    fi

    sleep 3
    # restart haproxy
    /etc/init.d/haproxy restart
    # Active Internet connections confirm
    netstat -nxtlp
    echo
    echo "Congratulations, haproxy install completed."
    echo -e "Your haproxy Server start port: \033[41;37m ${startport} \033[0m"
    echo -e "Your haproxy Server end port: \033[41;37m ${endport} \033[0m"
    echo -e "Your Input Shadowsocks IP: \033[41;37m ${haproxyip} \033[0m"
    echo ""
    echo "Welcome to visit:https://www.gaomingsong.com/480.html"
    echo "Enjoy it."
    echo ""
    exit 0
}


# Install haproxy
install_haproxy(){
    checkos
    rootness
    disable_selinux
    pre_install
	download
    install
}

# Initialization step
install_haproxy 2>&1 | tee -a /root/haproxy_for_shadowsocks.log
