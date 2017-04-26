#!/bin/sh
# Ubuntu VPS Auto Install Version 1.0
# by leenchan
VPS_OS=$(cat /etc/issue)

echo "$VPS_OS"|grep -Ei 'Ubuntu' &>/dev/null || {
	echo "It is not Ubuntu!!! -_-..."
	exit 0
}

TITLE="UBUNTU VPS"

SWAP_FILE_SIZE_DEFAULT='0'
USER_NAME_DEFAULT='root'
USER_PWD_DEFAULT='_123456_'

# Genernal Options
TIMEZONE="Asia/Shanghai"

# PHP Options
PHP_MEMORY_LIMIT='512M'
PHP_UPLOAD_MAX_FILESIZE='50M'
PHP_MAX_FILE_UPLOADS='200'
PHP_MAX_EXECUTION_TIME='600'
PHP_POST_MAX_SIZE='100M'

# MySQL
MYSQL_PWD_DEFAULT='root'

# VNC Options
VNC_DISPLAY_DEPTH="16"
VNC_PORT='5901'
VNC_HTTP_PORT='6081'

# RClone
RCLONE='1'

ask_init() {
	clear
	[ -z "$ERR" ] || echo "$ERR"
	ERR=''
	echo "===================================================="
	echo "                   $TITLE"
	echo "===================================================="
	echo "$VPS_OS"
	# [ -z "$USER_NAME" ] || echo "User Name:  $USER_NAME"
	[ -z "$USER_PWD" ] || echo "Root Password:  $USER_PWD"
	[ -z "$SSH_PORT" ] || echo "SSH Port:  $SSH_PORT"
	[ -z "$SWAP_FILE_SIZE" ] || echo "Swap File Size:  ${SWAP_FILE_SIZE}MB"
	[ -z "$LNMP" ] || echo "* LNMP:  $LNMP  "$([ -z "$MYSQL_PWD" ] || echo "  /  MySQL Password:  $MYSQL_PWD )")
	[ -z "$VNC" ] || echo "* VNC:  $VNC"
	[ -z "$NODEJS" ] || echo "* NodeJS + Redis:  $NODEJS"
	echo "----------------------------------------------------"
}

ask_user_name() {
	USER_NAME='vnc'
	return 0
	ask_init
	echo "User Name"
	echo "- 3 characters min and 32 characters max"
	echo "- click \"Enter\" to use default user name \"$USER_NAME_DEFAULT\":"
	read USER_NAME
	[ -z "$USER_NAME" ] && USER_NAME="$USER_NAME_DEFAULT"
	echo "$USER_NAME"|grep -Ew '[0-9A-Za-z_]{3,32}' || {
		ERR="[ERROR]: Not a valid user name!"
		ask_name
	}
}

ask_user_pwd() {
	ask_init
	echo "Root Password"
	echo "- 6 characters min and 16 characters max"
	echo "- click \"Enter\" to use default password \"$USER_PWD_DEFAULT\":"
	read USER_PWD
	[ -z "$USER_PWD" ] && USER_PWD="$USER_PWD_DEFAULT"
	echo "$USER_PWD"|grep -Ew '[0-9a-zA-Z!@#$%^&*|<>_+=~.,:;]{6,16}' || {
		ERR="[ERROR]: Not a valid password!"
		ask_user_pwd
	}
}

ask_mysql_pwd() {
	[ "$LNMP" = '1' ] || return 1
	ask_init
	echo "MySQL Password"
	echo "- 4 characters min and 16 characters max"
	echo "- click \"Enter\" to use user password \"$USER_PWD\":"
	read MYSQL_PWD
	[ -z "$MYSQL_PWD" ] && MYSQL_PWD="$USER_PWD"
	echo "$MYSQL_PWD"|grep -Ew '[0-9a-zA-Z!@#$%^&*|<>_+=~.,:;]{4,16}' || {
		ERR="[ERROR]: Not a valid password!"
		ask_mysql_pwd
	}
}

ask_ssh_port() {
	SSH_PORT_DEFAULT=$(cat /etc/ssh/sshd_config|grep -Ei '^#?port'|grep -Eo '[0-9]+')
	[ -z "$SSH_PORT_DEFAULT" ] && return 1
	ask_init
	echo "SSH Port"
	echo "- chage SSH Port"
	echo "- click \"Enter\" to skip"
	echo "[1-65535]:"
	read SSH_PORT
	[ -z "$SSH_PORT" ] && SSH_PORT="$SSH_PORT_DEFAULT"
	echo "$SSH_PORT"|grep -Ew '[0-9]+' || {
		ERR="[ERROR]: Not a valid port!"
		ask_ssh_port
	}
	[ "$SSH_PORT" -lt 1 -o "$SSH_PORT" -gt 65535 ] && {
		ERR="[ERROR]: Not a valid port!"
		ask_ssh_port
	}
}

ask_vnc_pwd() {
	[ "$VNC" = '1' ] || return 1
	ask_init
	echo "VNC Password"
	echo "4 characters min and 16 characters max"
	echo "click \"Enter\" to use user password \"$USER_PWD\":"
	read VNC_PWD
	[ -z "$VNC_PWD" ] && VNC_PWD="$USER_PWD"
	echo "$VNC_PWD"|grep -Ew '[0-9a-zA-Z!@#$%^&*|<>_+=~.,:;]{4,16}' || {
		ERR="[ERROR]: Not a valid password!"
		ask_vnc_pwd
	}
}

ask_vnc_display() {
	[ "$VNC" = '1' ] || return 1
	ask_init
	echo "VNC Displayr Rsolution"
	echo "[1] 640x480"
	echo "[2] 800x640"
	echo "[3] 1024x768"
	echo "[4] 1280x720"
	echo "[5] 1366x768"
	echo "[6] 1440x900"
	echo "[7] 1920x1080"
	echo "or A Custom Rsolution eg. 800x800"
	echo "click \"Enter\" to choose default rsolution \"[3] 1024x768\""
	echo "[1-7,0]:"
	read VNC_DISPLAY
	[ -z "$VNC_DISPLAY" ] && VNC_DISPLAY='3'
	case $VNC_DISPLAY in
		'1')
			VNC_DISPLAY='640x480'
			;;
		'2')
			VNC_DISPLAY='800x640'
			;;
		'3')
			VNC_DISPLAY='1024x768'
			;;
		'4')
			VNC_DISPLAY='1280x720'
			;;
		'5')
			VNC_DISPLAY='1366x768'
			;;
		'6')
			VNC_DISPLAY='1440x900'
			;;
		'7')
			VNC_DISPLAY='1920x1080'
			;;
		*)
			echo "$VNC_DISPLAY"|grep -Ew '[1-9][0-9]{2,3}x[1-9][0-9]{2,3}' &>/dev/null || {
				ERROR="[ERROR]: not a valid rsolution."
				ask_vnc_display
			}
			;;
	esac
}

ask_swap() {
	ask_init
	echo "Swap File"
	echo "- 0 for disable"
	echo "- 1~ for enabled, eg. 1024 "
	echo "click \"Enter\" to Skip" \
	"(MB):"
	read SWAP_FILE_SIZE
	[ -z "$SWAP_FILE_SIZE" ] && SWAP_FILE_SIZE="$SWAP_FILE_SIZE_DEFAULT" && return
	echo "$SWAP_FILE_SIZE"|grep -Ew '[1-9][0-9]*' || ask_swap
}

ask_yes_or_no() {
	ask_init
	YES_OR_NO_SELECTED=''
	YES_OR_NO_DEFAULT=${3:-n}
	# $1 Var  /  $2 Show String  /  $3 default 0=no 1=yes
	echo "$2"
	echo "Yes or No, click \"Enter\" to select \"$YES_OR_NO_DEFAULT\""
	echo "[y/n]:"
	read YES_OR_NO
	[ -z "$YES_OR_NO" ] && YES_OR_NO="$YES_OR_NO_DEFAULT"
	[ "$YES_OR_NO" = 'y' -o "$YES_OR_NO" = 'Y' ] && YES_OR_NO_SELECTED='1'
	[ "$YES_OR_NO" = 'n' -o "$YES_OR_NO" = 'N' ] && YES_OR_NO_SELECTED='0'
	if [ -z "$YES_OR_NO_SELECTED" ]; then
		ask_yes_or_no "$1" "$2" "$3"
	else
		eval "$1=$YES_OR_NO_SELECTED"
	fi
}

install_base() {
	apt-get update \
	&& apt-get install -y --force-yes --no-install-recommends \
	software-properties-common build-essential bc curl axel git unzip unrar supervisor htop openssh-server pwgen sudo vim-tiny net-tools rsync
}

php_phpmyadmin() {
	DL=$(curl -sSL https://www.phpmyadmin.net/downloads/ 2>/dev/null|grep -Eo 'http[^"]+phpMyAdmin-[0-9.]+-english.tar.(gz|bz2)'|sort -ru|head -n1)
	[ -z "$DL" ] && return 1
	FILE_NAME=$(echo "$DL"|sed -E 's|.*/||')
	curl "$DL" >$FILE_NAME
	[ -f "$FILE_NAME" ] && {
		tar -xf $FILE_NAME && mv $(ls -al|grep -Ei '^d.*phpmyadmin'|head -n1|awk '{print $9}') /www
		rm -f $FILE_NAME
	}
}

php_opcache() {
	find /usr|grep opcache.so &>/dev/null || return 1
	echo "zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.fast_shutdown=1
opcache.memory_consumption=${OPCACHE_MEM_SIZE:-128}
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=5413
opcache.revalidate_freq=60">/etc/php/7.0/fpm/conf.d/10-opcache.ini
}

php_apcu() {
	find /usr|grep apcu.so &>/dev/null || return 1
	echo "extension=apcu.so
apc.enabled=1
apc.shm_size=${APC_SHM_SIZE:-128M}
apc.ttl=7200">/etc/php/7.0/fpm/conf.d/20-apcu.ini
}

install_lnmp() {
	[ "$LNMP" = '1' ] || return 1

	# MySQL Auto Set Password
	echo "mysql-server mysql-server/root_password password $MYSQL_PWD"|debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password $MYSQL_PWD"|debconf-set-selections

	apt-get install -y --force-yes --no-install-recommends \
	nginx nginx-extras \
	spawn-fcgi fcgiwrap \
	php-fpm \
	php-mysql php-pgsql php-sqlite3 php-redis php-gd php-odbc \
	php-curl php-common php-zip php-bz2 php-mcrypt php-mbstring php-intl php-sybase php-pspell php-cli php-bcmath php-interbase php-recode php-readline php-gmp php-pear php-xdebug php-all-dev \
	php-xml php-xmlrpc php-json php-cgi \
	php-imap php-soap php-ldap php-fxsl \
	php-opcache php-apcu \
	mysql-server mysql-client

	curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

	sed -Ei -e "s/;?cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" \
	-e "s|;?date\.timezone.*|date.timezone=$TIMEZONE|" \
	-e "s/.*memory_limit.*/memory_limit=$PHP_MEMORY_LIMIT/" \
	-e "s/.*upload_max_filesize.*/upload_max_filesize=$PHP_UPLOAD_MAX_FILESIZE/" \
	-e "s/.*max_file_uploads.*/max_file_uploads=$PHP_MAX_FILE_UPLOADS/" \
	-e "s/.*post_max_size.*/post_max_size=$PHP_POST_MAX_SIZE/" \
	-e "s/.*error_reporting\s*=.*/error_reporting=E_ALL/" \
	-e "s/.*display_errors\s*=.*/display_errors=On/" \
	-e "s/^;?error_log\s*=.*/error_log=\/var\/logs\/php_errors.log/" \
	/etc/php/7.0/fpm/php.ini

	sed -Ei -e "s|;?date\.timezone.*|date.timezone=$TIMEZONE|" \
	/etc/php/7.0/cli/php.ini

	sed -Ei -e "s/;?daemonize\s*=.*/daemonize=yes/" \
	/etc/php/7.0/fpm/php-fpm.conf

	php_opcache
	php_apcu

	PHP_INIT=$(ls /etc/init.d|grep -Eo 'php.*fpm.*')

	/etc/init.d/$PHP_INIT restart
	# echo "binlog-format = MIXED">mysql

	php_phpmyadmin &
}

install_nodejs() {
	[ "$NODEJS" = '1' ] || return 1
	apt-get install -y --force-yes --no-install-recommends \
	nodejs nodejs-legacy npm redis-server mongodb-server imagemagick

	# curl "http://downloads.mongodb.org/linux/mongodb-linux-x86_64-ubuntu1604-latest.tgz" >/tmp/mongodb.tgz && {
	# 	tar -xf /tmp/mongodb.tgz -C /tmp
	# 	MONGODB_DIR=$(ls -al /tmp|grep -Eo '^d.*mongodb.*'|awk '{print $9}')
	# 	[ -d "$MONGODB_DIR" ] && {
	# 		ls "/tmp/$MONGODB_DIR/bin"|while read BIN
	# 		do
	# 			cp -f "/tmp/$MONGODB_DIR/bin/$BIN" /usr/sbin && chmod +x /usr/sbin/$BIN
	# 		done
	# 		mkdir -p /data/db
	# 	}
	# }
}

nginx_default() {
	[ "$LNMP" = '1' -o "$VNC" = '1' ] && NGINX=1
	[ "$NGINX" = '1' ] || return 1
	mkdir -p /www
	mkdir -p /www/html
	cp /usr/share/nginx/html/index.html /www/html
	[ "$LNMP" = '1' ] && echo "<?php phpinfo(); ?>" >/www/html/index.php
	NGINX_CONF=''
	[ "$VNC" = '1' ] && NGINX_CONF_VNC="
	location = /vnc.html {
		return 301 \$scheme://\$host:$VNC_HTTP_PORT/vnc_auto.html;
	}

	location = /vnc_auto.html {
		return 301 \$scheme://\$host:$VNC_HTTP_PORT/vnc_auto.html;
	}

	location = /websockify {
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \"upgrade\";
		proxy_pass http://127.0.0.1:$VNC_HTTP_PORT;
	}"
	[ "$LNMP" = '1' ] && NGINX_CONF_LNMP="
	location /phpmyadmin {
		alias /www/phpmyadmin;
	}

	location ~ \.php\$ {
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
		fastcgi_index index.php;
		include /etc/nginx/fastcgi_params;
		set \$fastcgi_script_root \$document_root;
		if (\$fastcgi_script_name ~ /phpmyadmin/(.+\\.php.*)\$) {
				set \$fastcgi_script_root /www;
		}
		fastcgi_param SCRIPT_FILENAME \$fastcgi_script_root\$fastcgi_script_name;
	}"
	[ "$RCLONE" = '1' ] && NGINX_CONF_RCLONE="
	location /rclone {
		proxy_pass http://127.0.0.1:53682/auth;
	}
	"
	echo "server {
	listen 80 default_server;
	server_name localhost;
	root /www/html;
	index index.html index.htm index.php;

	location / {
		if (-f \$request_filename) {
		 break;
		}
		if (\$request_filename ~* \"\\.(js|ico|gif|jpe?g|bmp|png|css)$\") {
				break;
		}
		if (!-e \$request_filename) {
				rewrite . /index.php last;
		}
	}

	error_page 404 /404.html;
	location = /404.html {
		root /usr/share/nginx/html;
	}

	error_page 500 502 503 504 /50x.html;
	location = /50x.html {
		root /usr/share/nginx/html;
	}
	$NGINX_CONF_VNC
	$NGINX_CONF_LNMP
	$NGINX_CONF_RCLONE
}">/etc/nginx/sites-enabled/default

	chown -R www-data:www-data /www

	if pidof nginx &>/dev/null; then
		nginx -s reload
	else
		/etc/init.d/nginx restart
	fi
}

ssh_chage_port() {
	[ -z "$SSH_PORT" -o "$SSH_PORT" = "$SSH_PORT_DEFAULT" ] && return 1
	sed -Ei "s|^#?Port.*|Port $SSH_PORT|g" /etc/ssh/sshd_config && /etc/init.d/ssh restart
}

vnc_supervisor() {
	cat <<-EOF >/etc/supervisor/conf.d/vnc.conf
[program:xvfb]
priority=10
directory=/
command=/usr/bin/Xvfb :1 -screen 0 ${VNC_DISPLAY}x${VNC_DISPLAY_DEPTH}
user=$USER_NAME
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=/var/log/xvfb.log
redirect_stderr=true

[program:lxsession]
priority=15
directory=$HOME_PATH
command=/usr/bin/lxsession
user=$USER_NAME
autostart=true
autorestart=true
stopsignal=QUIT
environment=DISPLAY=":1",HOME="$HOME_PATH"
stdout_logfile=/var/log/lxsession.log
redirect_stderr=true

[program:x11vnc]
priority=20
directory=/
command=x11vnc -display :1 -xkb -forever -shared -rfbauth $HOME_PATH/.x11vnc/x11vnc.pass -rfbport $VNC_PORT
user=$USER_NAME
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=/var/log/x11vnc.log
redirect_stderr=true

[program:novnc]
priority=25
directory=/usr/share/noVNC/
command=/usr/share/noVNC/utils/launch.sh --vnc localhost:$VNC_PORT --listen $VNC_HTTP_PORT
user=$USER_NAME
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=/var/log/novnc.log
redirect_stderr=true
stopasgroup=true
	EOF
}

vnc_lxde() {
	mkdir -p $HOME_PATH/.config

	wget -O /usr/share/lxde/images/ubuntu.png https://www.davidtan.org/wp-content/uploads/2010/01/ubuntu-logo-icon.png
	mkdir -p $HOME_PATH/.config/lxpanel/LXDE/panels
	cat <<-EOF >$HOME_PATH/.config/lxpanel/LXDE/panels/panel
	# lxpanel <profile> config file. Manually editing is not recommended.
	# Use preference dialog in lxpanel to adjust config when you can.

	Global {
	  edge=top
	  allign=left
	  margin=0
	  widthtype=percent
	  width=100
	  height=24
	  transparent=1
	  tintcolor=#000000
	  alpha=255
	  setdocktype=1
	  setpartialstrut=1
	  usefontcolor=1
	  fontcolor=#ffffff
	  background=0
	  backgroundfile=/usr/share/lxpanel/images/background.png
	  align=left
	  iconsize=24
	  autohide=0
	  usefontsize=1
	  fontsize=9
	}
	Plugin {
	  type=space
	  Config {
	    Size=10
	  }
	}
	Plugin {
	  type=menu
	  Config {
	    image=/usr/share/lxde/images/ubuntu.png
	    system {
	    }
	    separator {
	    }
	    item {
	      command=run
	    }
	    separator {
	    }
	    item {
	      image=gnome-logout
	      command=logout
	    }
	  }
	}
	Plugin {
	  type=space
	  Config {
	    Size=10
	  }
	}
	Plugin {
	  type=launchbar
	  Config {
	    Button {
	      id=menu://applications/System/xfce4-terminal.desktop
	    }
	    Button {
	      id=pcmanfm.desktop
	    }
	    Button {
	      id=lxde-x-www-browser.desktop
	    }
	  }
	}
	Plugin {
	  type=space
	  Config {
	    Size=10
	  }
	}
	Plugin {
	  type=wincmd
	  Config {
	    Button1=iconify
	    Button2=shade
	  }
	}
	Plugin {
	  type=space
	  Config {
	    Size=10
	  }
	}
	Plugin {
	  type=pager
	  Config {
	  }
	}
	Plugin {
	  type=space
	  Config {
	    Size=4
	  }
	}
	Plugin {
	  type=taskbar
	  expand=1
	  Config {
	    tooltips=1
	    IconsOnly=0
	    AcceptSkipPager=1
	    ShowIconified=1
	    ShowMapped=1
	    ShowAllDesks=0
	    UseMouseWheel=1
	    UseUrgencyHint=1
	    FlatButton=1
	    MaxTaskWidth=150
	    spacing=1
	    SameMonitorOnly=0
	    GroupedTasks=1
	    DisableUpscale=0
	  }
	}
	Plugin {
	  type=cpu
	  Config {
	  }
	}
	Plugin {
	  type=tray
	  Config {
	  }
	}
	Plugin {
	  type=dclock
	  Config {
	    ClockFmt=%l:%M %p
	    TooltipFmt=%A %x
	    BoldFont=1
	    IconOnly=0
	    CenterText=0
	  }
	}
	Plugin {
	  type=launchbar
	  Config {
	    Button {
	      id=lxde-screenlock.desktop
	    }
	    Button {
	      id=lxde-logout.desktop
	    }
	  }
	}
	EOF

	mkdir -p $HOME_PATH/.config/gtk-3.0
	cat <<-EOF >$HOME_PATH/.config/gtk-3.0/settings.ini
	[Settings]
	gtk-theme-name=Natura
	gtk-icon-theme-name=gnome
	gtk-font-name=Sans 10
	gtk-cursor-theme-size=18
	gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
	gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
	gtk-button-images=1
	gtk-menu-images=1
	gtk-enable-event-sounds=1
	gtk-enable-input-feedback-sounds=1
	gtk-xft-antialias=1
	gtk-xft-hinting=1
	gtk-xft-hintstyle=hintslight
	gtk-xft-rgba=rgb
	EOF

	mkdir -p $HOME_PATH/.config/lxsession/LXDE
	cat <<-EOF >$HOME_PATH/.config/lxsession/LXDE/desktop.conf
	[Session]
	window_manager=openbox-lxde
	windows_manager/command=openbox
	windows_manager/session=LXDE
	disable_autostart=no
	polkit/command=lxpolkit
	clipboard/command=lxclipboard
	xsettings_manager/command=build-in
	proxy_manager/command=build-in
	keyring/command=ssh-agent
	quit_manager/command=lxsession-logout
	quit_manager/image=/usr/share/lxde/images/logout-banner.png
	quit_manager/layout=top
	lock_manager/command=lxlock
	terminal_manager/command=lxterminal
	launcher_manager/command=lxpanelctl

	[GTK]
	sNet/ThemeName=Natura
	sNet/IconThemeName=gnome
	sGtk/FontName=Sans 10
	iGtk/ToolbarStyle=3
	iGtk/ButtonImages=1
	iGtk/MenuImages=1
	iGtk/CursorThemeSize=18
	iXft/Antialias=1
	iXft/Hinting=1
	sXft/HintStyle=hintslight
	sXft/RGBA=rgb
	iNet/EnableEventSounds=1
	iNet/EnableInputFeedbackSounds=1
	sGtk/ColorScheme=
	iGtk/ToolbarIconSize=3
	sGtk/CursorThemeName=DMZ-White

	[Mouse]
	AccFactor=20
	AccThreshold=10
	LeftHanded=0

	[Keyboard]
	Delay=500
	Interval=30
	Beep=1

	[State]
	guess_default=true

	[Dbus]
	lxde=true

	[Environment]
	menu_prefix=lxde-
	EOF

	mkdir -p $HOME_PATH/.config/openbox
	cat <<-EOF >$HOME_PATH/.config/openbox/lxde-rc.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<!-- Do not edit this file, it will be overwritten on install.
	        Copy the file to $HOME/.config/openbox/ instead. -->
	<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
	  <resistance>
	    <strength>10</strength>
	    <screen_edge_strength>20</screen_edge_strength>
	  </resistance>
	  <theme>
	    <name>Natura</name>
	    <titleLayout>NLIMC</titleLayout>
	    <keepBorder>yes</keepBorder>
	    <animateIconify>yes</animateIconify>
	    <font place="ActiveWindow">
	      <name>sans</name>
	      <size>10</size>
	      <!-- font size in points -->
	      <weight>bold</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	    <font place="InactiveWindow">
	      <name>sans</name>
	      <size>10</size>
	      <!-- font size in points -->
	      <weight>bold</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	    <font place="MenuHeader">
	      <name>sans</name>
	      <size>9</size>
	      <!-- font size in points -->
	      <weight>normal</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	    <font place="MenuItem">
	      <name>sans</name>
	      <size>9</size>
	      <!-- font size in points -->
	      <weight>normal</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	    <font place="ActiveOnScreenDisplay">
	      <name>sans</name>
	      <size>9</size>
	      <!-- font size in points -->
	      <weight>bold</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	    <font place="InactiveOnScreenDisplay">
	      <name>sans</name>
	      <size>9</size>
	      <!-- font size in points -->
	      <weight>bold</weight>
	      <!-- 'bold' or 'normal' -->
	      <slant>normal</slant>
	      <!-- 'italic' or 'normal' -->
	    </font>
	  </theme>
	  <desktops>
	    <!-- this stuff is only used at startup, pagers allow you to change them
	       during a session

	       these are default values to use when other ones are not already set
	       by other applications, or saved in your session

	       use obconf if you want to change these without having to log out
	       and back in -->
	    <number>4</number>
	    <firstdesk>1</firstdesk>
	    <names>
	      <!-- set names up here if you want to, like this:
	    <name>desktop 1</name>
	    <name>desktop 2</name>
	    -->
	    </names>
	    <popupTime>875</popupTime>
	    <!-- The number of milliseconds to show the popup for when switching
	       desktops.  Set this to 0 to disable the popup. -->
	  </desktops>
	  <resize>
	    <drawContents>yes</drawContents>
	    <popupShow>Nonpixel</popupShow>
	    <!-- 'Always', 'Never', or 'Nonpixel' (xterms and such) -->
	    <popupPosition>Center</popupPosition>
	    <!-- 'Center', 'Top', or 'Fixed' -->
	    <popupFixedPosition>
	      <!-- these are used if popupPosition is set to 'Fixed' -->
	      <x>10</x>
	      <!-- positive number for distance from left edge, negative number for
	         distance from right edge, or 'Center' -->
	      <y>10</y>
	      <!-- positive number for distance from top edge, negative number for
	         distance from bottom edge, or 'Center' -->
	    </popupFixedPosition>
	  </resize>
	</openbox_config>
	EOF

	# pcmanfm
	mkdir -p $HOME_PATH/.config/pcmanfm/LXDE
	cat <<-EOF >$HOME_PATH/.config/pcmanfm/LXDE/desktop-items-0.conf
	[*]
	wallpaper_mode=stretch
	wallpaper_common=0
	wallpapers_configured=4
	wallpaper0=/usr/share/wallpapers/bg1.jpg
	desktop_bg=#000000
	desktop_fg=#ffffff
	desktop_shadow=#000000
	desktop_font=Sans 10
	show_wm_menu=0
	sort=mtime;ascending;mingle;
	show_documents=0
	show_trash=1
	show_mounts=1
	EOF

	# xfce terminal
	mkdir -p $HOME_PATH/.config/xfce4/terminal
	cat <<-EOF >$HOME_PATH/.config/xfce4/terminal/terminalrc
	[Configuration]
	FontName=Monospace 10
	MiscAlwaysShowTabs=FALSE
	MiscBell=FALSE
	MiscBordersDefault=TRUE
	MiscCursorBlinks=FALSE
	MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
	MiscDefaultGeometry=80x24
	MiscInheritGeometry=FALSE
	MiscMenubarDefault=TRUE
	MiscMouseAutohide=FALSE
	MiscToolbarDefault=FALSE
	MiscConfirmClose=TRUE
	MiscCycleTabs=TRUE
	MiscTabCloseButtons=TRUE
	MiscTabCloseMiddleClick=TRUE
	MiscTabPosition=GTK_POS_TOP
	MiscHighlightUrls=TRUE
	MiscScrollAlternateScreen=TRUE
	ColorPalette=#000000;#cc0000;#4e9a06;#c4a000;#3465a4;#75507b;#06989a;#d3d7cf;#555753;#ef2929;#8ae234;#fce94f;#739fcf;#ad7fa8;#34e2e2;#eeeeec
	EOF

	# wget -O ./hedera.deb https://github.com/sixsixfive/Hedera/raw/master/pkgs/hedera-current_testing.deb && {
	# 	dpkg -i hedera.deb || apt-get install -y --force-yes -f
	# 	cat /usr/share/themes/Hedera/gtk-2.0/settings.ini >/home/$USER_NAME/.gtkrc-2.0
	# 	rm -f ./hedera.deb
	# }

	# WallPaper
	mkdir -p /usr/share/wallpapers
	wget -O /usr/share/wallpapers/bg1.jpg "https://images.pexels.com/photos/1240/road-street-blur-blurred.jpg?dl&fit=crop&w=1920&h=1280"
}

install_rclone() {
	[ "$RCLONE" = '1' ] || return 1
	RCLONE_DL=$(curl -sSL https://rclone.org/downloads/|grep -Eo 'https?://[^"]+v[0-9.]+-linux-amd64\.zip'|head -n1)
	[ -z "$RCLONE_DL" ] && return 1
	curl $RCLONE_DL >/tmp/rclone.zip && unzip /tmp/rclone.zip -d /tmp && {
		mv $(ls -d /tmp/rclone-*)/rclone /usr/sbin/rclone && chmod +x /usr/sbin/rclone
		rm -rf /tmp/rclone*
	}
}

install_frp(){
	DL=$(curl -sSL https://github.com/fatedier/frp/releases|grep -Eo '/[^"]+amd64.tar.gz'|head -n1)
	[ -z "$DL" ] && return 1
	FILE_NAME=$(echo "$DL"|sed -E 's|.*/||')
	curl https://github.com$DL >$FILE_NAME
	[ -f "$FILE_NAME" ] && {
		tar -xf $FILE_NAME && mv $(ls -al|grep -Ei '^d.*frp'|head -n1|awk '{print $9}') /usr/local/frp
		rm -f $FILE_NAME
		curl https://raw.githubusercontent.com/fatedier/frp/master/README.md >/usr/local/frp/README.md
		curl https://raw.githubusercontent.com/fatedier/frp/master/README_zh.md >/usr/local/frp/README_zh.md
		ln -s /usr/local/frp/frpc /usr/sbin/frpc
		ln -s /usr/local/frp/frps /usr/sbin/frps
	}
}

install_lets_encrypt() {
	curl https://get.acme.sh|sh
	# ~/.acme.sh/acme.sh. -d example.com -d www.example.com -w /www/example.com
}

install_vnc() {
	[ "$VNC" = '1' ] || return 1
	mkdir -p /www
    apt-get install -y --force-yes --no-install-recommends \
        lxde x11vnc xvfb \
        gtk2-engines-murrine ttf-ubuntu-font-family fonts-wqy-microhei \
        firefox \
        python-pip python-dev \
        mesa-utils libgl1-mesa-dri \
        gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine pinta xfce4-terminal

    # Sublime Text
    SUBLIME_TEXT_URL=$(curl -sSL https://www.sublimetext.com/3|grep -Eo 'https?://[^"]+amd64\.deb')
    curl -sSL $SUBLIME_TEXT_URL >sublime_text.deb && dpkg -i sublime_text.deb && rm -f sublime_text.deb

	mkdir -p $HOME_PATH/.x11vnc
	x11vnc -storepasswd $VNC_PWD $HOME_PATH/.x11vnc/x11vnc.pass

	vnc_supervisor
	vnc_lxde
	rm -f /usr/share/applications/lxterminal.desktop

	# noVNC
	git clone https://github.com/novnc/noVNC.git /usr/share/noVNC
	git clone https://github.com/novnc/websockify.git /usr/share/noVNC/utils/websockify

	chown -R ${USER_NAME}:${USER_NAME} $HOME_PATH

	if pidof supervisord; then
		/usr/bin/supervisorctl reload
	else
		/etc/init.d/supervisor restart
	fi
}

clean_all() {
	apt-get autoclean
	apt-get autoremove
	rm -rf /var/lib/apt/lists/*
}

install_timezone() {
	apt-get install -y --force-yes --no-install-recommends \
	tzdata
	ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
	echo $TIMEZONE > /etc/timezone
}

swap_file() {
	[ $SWAP_FILE_SIZE -gt 0 ] || return 1
	[ -f /swapfile ] && {
		swapoff /swapfile && rm -f /swapfile
	}
	fallocate -l ${SWAP_FILE_SIZE}M /swapfile
	# dd if=/dev/zero of=/swapfile bs=1M count=512
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	cat /etc/fstab|grep '\/swapfile\s' || echo '/swapfile none swap defaults 0 0' >>/etc/fstab
}

add_user() {
	HOME_PATH='/root'
	[ "$USER_NAME" = 'root' ] || {
		useradd  -m -U -s /bin/bash $USER_NAME
		HOME_PATH="/home/$USER_NAME"
		echo "${USER_NAME}    ALL=(ALL) ALL" >> /etc/sudoers
		echo "${USER_NAME}:${USER_PWD}"|chpasswd
	}
	echo "root:${USER_PWD}"|chpasswd
}

vps_init() {
	[ -f '/.vps_init' ] && {
		echo "Seem that it is not the first time, please remove /.vps_install first."
		exit
	}
	ask_user_name
	ask_user_pwd
	ask_ssh_port
	# ask_yes_or_no "AS_ROOT_PWD" "Use this user password as root password" "y"
	ask_swap
	ask_yes_or_no "LNMP" "Install LNMP" "y"
	ask_mysql_pwd
	ask_yes_or_no "VNC" "Install VNC" "y"
	ask_vnc_pwd
	ask_vnc_display
	ask_yes_or_no "NODEJS" "Install NodeJS & Redis-Server" "n"

	add_user
	swap_file
	install_base
	install_timezone
	install_lnmp
	install_nodejs
	install_rclone
	install_vnc
	install_frp
	install_lets_encrypt
	nginx_default
	date >/.vps_init
	ssh_chage_port
	# clean_all

	clear
	echo "Done."
	echo "===================================================="
	echo "                   $TITLE"
	echo "===================================================="
	echo "Global"
	echo "- Root Passowrd:   $USER_PWD"
	echo "- SSH Port:        &SSH_PORT"
	echo ""
	[ "$LNMP" = '1' ] && {
	echo "LNMP"
	echo "- MySQL Password:  $MYSQL_PWD"
	echo ""
	}
	[ "$VNC" = '1' ] && {
	echo "VNC"
	echo "- Password:        $VNC_PWD"
	echo "- Port:            $VNC_PORT"
	echo "- Http Port:       $VNC_HTTP_PORT"
	echo "  ( http://host:$VNC_HTTP_PORT/vnc.html http://host/vnc.html )"
	echo ""
	}
	exit 0
}

vps_bbr() {
	LAST_KERNEL_REALSE=$(curl -sSL http://kernel.ubuntu.com/~kernel-ppa/mainline/|grep -Eo 'v[4-9]\.[0-9.]+(-rc[0-9]+)?'|tail -n1)
	[ -z "$LAST_KERNEL_REALSE" ] && echo "Could not found last kernel realse." && exit
	LAST_KERNEL_DEB_NAME=$(curl -sSL http://kernel.ubuntu.com/~kernel-ppa/mainline/${LAST_KERNEL_REALSE}/|grep -Eo 'linux-image-[^"]+generic[^"]+amd64.deb'|sort -u|head -n1)
	[ -z "$LAST_KERNEL_REALSE" ] && echo "Could not found last kernel realse." && exit
	curl http://kernel.ubuntu.com/~kernel-ppa/mainline/${LAST_KERNEL_REALSE}/$LAST_KERNEL_DEB_NAME >/tmp/$LAST_KERNEL_DEB_NAME && {
		dpkg -i /tmp/$LAST_KERNEL_DEB_NAME
		rm -f /tmp/$LAST_KERNEL_DEB_NAME
		/usr/sbin/update-grub
		sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
		echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
		echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
		sysctl -p >/dev/null 2>&1
		read -p "Info: The system needs to be restart. Do you want to reboot? [y/n]" is_reboot
		[ "$is_reboot" = "y" -o "$is_reboot" = "Y" ] && reboot
		exit
	}
}

redis_dump() {
	REDIS_CONF=$(find /etc|grep redis.conf|head -n1)
	[ -z "$REDIS_CONF" ] && err_exit "Could not find redis.conf"
	REDIS_DB_PATH=$(cat "$REDIS_CONF"|grep -Eoi '^dir\s+.*'|sed -E 's/^dir\s+//')
	[ -z "$REDIS_DB_PATH" ] && err_exit "Not set redis db path"
	REDIS_DB_NAME=$(cat "$REDIS_CONF"|grep -Eoi '^dbfilename\s+.*'|sed -E 's/^dbfilename\s+//')
	[ -z "REDIS_DB_NAME" ] && REDIS_DB_NAME='dump.rdb'
	REDIS_DB_PATH="$REDIS_DB_PATH/$REDIS_DB_NAME"
	which redis-cli &>/dev/null || err_exit "Not found command redis-cli."
	REDIS_CONNECT="redis-cli $REDIS_CLI"
	echo "BGSAVE" | $REDIS_CONNECT
	echo "Backup Redis Database" && sleep 10
	try=6
	while [ $try -gt 0 ] ; do
	bg=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_bgsave_in_progress/{sub(/\r/, "", $0); print $2}')
	ok=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_last_bgsave_status/{sub(/\r/, "", $0); print $2}')
	if [ "$bg" = "0" -a "$ok" = "ok" ] ; then
		[ -f "$REDIS_DB_PATH" ] || return 1
      REDIS_VER=$(echo 'info Server' | $REDIS_CONNECT | awk -F: '/redis_version/{sub(/\r/, "", $0); print $2}')
      REDIS_OK=1 && try=0 && echo "- Dump redis ... OK"
    else
      sleep 10
    fi
    try=$((try - 1))
  done
  [ "$REDIS_OK" = "1" ] && return 0
  echo "- Dump redis ... Failed"
  return 1
}

vps_backup_mysql(){
	[ -z "$BACKUP_TIME" ] && BACKUP_TIME=$(date +%Y%m%d%H%M)
	which mysqldump &>/dev/null && {
		mysqldump --all-databases > dump-${BACKUP_TIME}.sql
		# mysqldump  --add-drop-table -uusername -ppassword -database databasename > backupfile.sql
		# mysqldump --databases data1 data2 data3 > dump.sql
		# Recovery
		#mysql -hhostname -uusername -ppassword databasename < backupfile.sql
	}
}

vps_backup_mongodb(){
	[ -z "$BACKUP_TIME" ] && BACKUP_TIME=$(date +%Y%m%d%H%M)
	which mongodump &>/dev/null && {
		mkdir -p mongodb-${BACKUP_TIME}
		# mongodump --host mongodb1.example.net --port 3017 --username user --password pass --out /opt/backup/mongodump-2013-10-24
		mongodump -h 127.0.0.1 -o dbdirectory -o ./mongodb && tar -zcf mongodb-${BACKUP_TIME}.tar.gz -C ./mongodb . && rm -rf ./mongodb
	}
}

vps_backup_redis(){
	[ -z "$BACKUP_TIME" ] && BACKUP_TIME=$(date +%Y%m%d%H%M)
	REDIS_CONF=$(find /etc|grep redis.conf|head -n1)
	[ -z "$REDIS_CONF" ] && err_exit "Could not find redis.conf"
	REDIS_DB_PATH=$(cat "$REDIS_CONF"|grep -Eoi '^dir\s+.*'|sed -E 's/^dir\s+//')
	[ -z "$REDIS_DB_PATH" ] && err_exit "Not set redis db path"
	REDIS_DB_NAME=$(cat "$REDIS_CONF"|grep -Eoi '^dbfilename\s+.*'|sed -E 's/^dbfilename\s+//')
	[ -z "REDIS_DB_NAME" ] && REDIS_DB_NAME='dump.rdb'
	REDIS_DB_PATH="$REDIS_DB_PATH/$REDIS_DB_NAME"
	which redis-cli &>/dev/null || err_exit "Not found command redis-cli."
	read -p "Input your redis-server password, or click \"Enter\" to leave it blank:" REDIS_CLI
	REDIS_CONNECT="redis-cli $REDIS_CLI"
	echo "BGSAVE" | $REDIS_CONNECT
	echo "Backup Redis Database" && sleep 10
	try=6
	while [ $try -gt 0 ] ;
	do
		bg=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_bgsave_in_progress/{sub(/\r/, "", $0); print $2}')
		ok=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_last_bgsave_status/{sub(/\r/, "", $0); print $2}')
		if [ "$bg" = "0" -a "$ok" = "ok" ] ; then
			[ -f "$REDIS_DB_PATH" ] || return 1
			REDIS_VER=$(echo 'info Server' | $REDIS_CONNECT | awk -F: '/redis_version/{sub(/\r/, "", $0); print $2}')
			REDIS_OK=1 && try=0 && echo "- Dump redis ... OK"
		else
			sleep 10
		fi
		try=$((try - 1))
	done
	[ "$REDIS_OK" = "1" ] && cp -f "$REDIS_DB_PATH" ./"redis-$REDIS_VER-$BACKUP_TIME.rdb" && return 0
	echo "- Dump redis ... Failed"
	return 1
}

vps_backup_files() {
	[ -z "$BACKUP_TIME" ] && BACKUP_TIME=$(date +%Y%m%d%H%M)
	tar -zcf backup-files-${BACKUP_TIME}.tar.gz \
	/www \
	/etc/nginx \
	/var/lib/redis \
	/root/* \
	/root/.acme.sh \
	/etc/supervisor/conf.d \
	/etc/hosts
}

vps_backup() {
	BACKUP_TIME=$(date +%Y%m%d%H%M)
	vps_backup_mysql
	vps_backup_mongodb
	vps_backup_redis
	vps_backup_files
}

vps_help() {
	cat <<-EOF
command [option]
option
init      install lnmp, vnc, nodejs, redis, mongodb
bbr       install google bbr
backup    Backup Data to tar.gz file
	EOF
}

case $1 in
	'init')
		vps_init
		;;
	'bbr')
		vps_bbr
		;;
	'backup')
		vps_backup
		;;
	*)
		vps_help
		;;
esac
