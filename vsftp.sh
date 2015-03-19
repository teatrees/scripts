#!/bin/bash
#---------------------------------------------------------------
# Filename:vsftpd_install.sh
# Revision:1.0
# Date:2014-10-14
# Author: 楚霏
# Description:VsFTPD Virtual User Configuration
# Coding:utf-8 
#---------------------------------------------------------------
#
# 在这一部分定义相关变量
#
#################################################
YUM_INSTALL_LIST="vsftpd db4 db4-tcl db4-utils"
APT_INSTALL_LIST="vsftpd db4.6-util"

# 通常只需要编辑以下两个变量
FTP_USER=virtualftp
FTP_HOME=/var/ftp

VSFTPD_BASE_DIR=/etc/vsftpd


#################################################
#
# 检查系统环境，并安装所需软件包
#
#################################################
# 检查是否以ROOT用户执行本脚本
[ `id -u` -ne '0' ] && echo 'Must be root!' && exit

# 检查发行版是否为本脚本所支持
[ `uname -i` = 'x86_64' ] && PLATFORM='x86_64' || PLATFORM='i386'
if cat /etc/issue|grep '4.' ;then
OS=4
elif cat /etc/issue|grep '5.';then
OS=5
elif cat /etc/issue|grep '6.';then
OS=6
else
echo 'Do not support this system ' && exit
fi

DISTRIBUTION=`cat /etc/issue | awk '{print $1}'`
case "$DISTRIBUTION" in
*CentOS*|*"Red Hat"*|*Fedora*)
yum -y install $YUM_INSTALL_LIST
;;
*Debian*|*Ubuntu*)
apt-get -y install $APT_INSTALL_LIST
;;
*)
echo 'Do not support this distribution !' && exit 0
;;
esac



#################################################
#
# 创建FTP用的系统用户
#
#################################################
# 检查ftp要使用的用户是否存在
EXISTS_USER=`grep -E "^\<$FTP_USER\>" /etc/passwd |awk -F: '{print $1}'`
if [ "$EXISTS_USER" != "$FTP_USER" ]
    then
      useradd -u 78 $FTP_USER -d $FTP_HOME -s /sbin/nologin
    fi
    # 检查ftp用户的家目录是否正确
    if [ "$EXISTS_USER" = "$FTP_USER" ]
      then
        usermod -d $FTP_HOME $FTP_USER
fi



#################################################
#
# 创建FTP的目录和文件
#
#################################################
# 创建安装目录
if [ ! -d $VSFTPD_BASE_DIR ]
    then
      mkdir -p $VSFTPD_BASE_DIR
fi

# 把FTP的系统用户写入
echo "$FTP_USER" >> $VSFTPD_BASE_DIR/vsftpd.chroot_list

# 创建日志文件
touch /var/log/vsftpd.log

# 创建虚拟用户的配置文件路径目录
mkdir -p $VSFTPD_BASE_DIR/user_config

# 创建密码文件, 单行为用户名, 双行为密码
touch $VSFTPD_BASE_DIR/passwd.txt



#################################################
#
# 修改配置文件
#
#################################################
# 写入测试用户和密码
echo ftpuser1 >> $VSFTPD_BASE_DIR/passwd.txt
echo `< /dev/urandom tr -dc A-Za-z0-9 | head -c 20` >> $VSFTPD_BASE_DIR/passwd.txt

# 修改PAM认证文件
#echo "    auth       required     pam_userdb.so db=$VSFTPD_BASE_DIR/user_passwd" > /etc/pam.d/vsftpd
#echo "    account       required     pam_userdb.so db=$VSFTPD_BASE_DIR/user_passwd" >> /etc/pam.d/vsftpd
sed '/#%PAM-1.0/a\auth sufficient pam_userdb.so db=$VSFTPD_BASE_DIR/user_passwd\naccount sufficient pam_userdb.so db=$VSFTPD_BASE_DIR/user_passwd' /etc/pam.d/vsftpd


# 编辑vsftpd的配置文件
> $VSFTPD_BASE_DIR/vsftpd.conf && echo "已删除默认配置"
echo "\
###########全局设置#############
#监听端口
listen=YES
#允许写入权限
write_enable=YES
#同时最大连接数
max_clients=500
#单IP最大连接数
max_per_ip=100
use_localtime=YES
#设定Vsftpd的登陆标语
ftpd_banner=Welcome to Kingsoft FTP servers

###########安全设置#############
#锁定本地用户主目录
chroot_local_user=YES
#锁定chroot_list_file用户主目录
chroot_list_enable=NO
chroot_list_file=/etc/vsftpd/vsftpd.chroot_list
#启用userlist文件
#ftpusers用户禁止访问，userlist文件中用户禁止访问
userlist_enable=YES
userlist_deny=YES


###########本地用户#############
#本地用户可以访问
local_enable=YES
#上传后文件的权限掩码
local_umask=022
#local_root=/home


###########匿名用户#############
#不允许匿名访问
anonymous_enable=NO
#禁止匿名用户上传
anon_upload_enable=NO
#禁止匿名用户建立目录
anon_mkdir_write_enable=NO
#禁止匿名用户浏览
anon_world_readable_only=NO
#匿名用户登录后所在的目录
anon_root=/var/ftp/pub

###########连接配置#############
#pasv模式超时时间(秒)
accept_timeout=60
#port模式超时时间(秒)
connect_timeout=60
#建立ftp数据连接的超时时间
data_connection_timeout=300
#发呆时间
idle_session_timeout=600
#启用pasv模式
pasv_enable=yes
port_enable=NO
pasv_min_port=20000
pasv_max_port=20099
#支持ASCII模式的上传和下载功能
ascii_upload_enable=YES
ascii_download_enable=YES
#支持异步传输功能
async_abor_enable=YES


#############虚拟用户配置###############
#PAM认证文件
pam_service_name=vsftpd
#启用用户映射
guest_enable=YES
guest_username=$FTP_USER
#虚拟用户配置文件目录
user_config_dir=$VSFTPD_BASE_DIR/user_config

#############虚拟用户配置###############
#记录所有的ftp命令
log_ftp_protocol=YES

#开启xferlog日志
xferlog_enable=YES
#xferlog日志保存路径
xferlog_file=/var/log/xferlog

#启用vsftp自己的日志记录方式
dual_log_enable=YES
#vsftpd日志保存路径
vsftpd_log_file=/var/log/vsftpd.log

#标准格式存储日志
#xferlog_std_format=YES
syslog_enable=NO
" >> $VSFTPD_BASE_DIR/vsftpd.conf

# 为虚拟用户创建家目录和配置文件
if [ ! -d $FTP_HOME/wwwroot/ftpuser1 ]
then
mkdir -p $FTP_HOME/wwwroot/ftpuser1
chown -R $FTP_USER $FTP_HOME
fi

echo "\
local_root=$FTP_HOME/wwwroot/ftpuser1
write_enable=YES
anon_umask=022
anon_world_readable_only=NO
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES\
" >> $VSFTPD_BASE_DIR/user_config/ftpuser1




#################################################
#
# 创建虚拟用户密码认证数据库文件，并写成脚本
#
#################################################
case "$DISTRIBUTION" in
*CentOS*|*"Red Hat"*|*Fedora*)
echo "\
if [ -e $VSFTPD_BASE_DIR/user_passwd.db ]
    then
    rm -f $VSFTPD_BASE_DIR/user_passwd.db
fi
db_load -T -t hash -f $VSFTPD_BASE_DIR/passwd.txt $VSFTPD_BASE_DIR/user_passwd.db\
" >> $VSFTPD_BASE_DIR/db_load.sh
;;
*Debian*|*Ubuntu*)
echo "\
if [ -e $VSFTPD_BASE_DIR/user_passwd.db ]
    then
    rm -f $VSFTPD_BASE_DIR/user_passwd.db
fi
db4.6_load -T -t hash -f $VSFTPD_BASE_DIR/passwd.txt $VSFTPD_BASE_DIR/user_passwd.db\
" >> $VSFTPD_BASE_DIR/db_load.sh
;;
*)
echo 'Do not support this distribution !!' && exit
;;
esac

chmod 500 $VSFTPD_BASE_DIR/db_load.sh
$VSFTPD_BASE_DIR/db_load.sh



#################################################
#
# 启动并测试
#
#################################################
/etc/init.d/vsftpd start

# 验证登录
echo "测试用户名是： ftpuser1"
# 显示出匹配行的下一行，也就是密码
echo "测试用户密码是： `sed -n '/ftpuser1/{n;p;}' $VSFTPD_BASE_DIR/passwd.txt`"
echo "测试无误的话别忘了删除测试用户，Good luck ! "
