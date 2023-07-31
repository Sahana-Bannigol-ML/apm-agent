#!/bin/bash

#set -x
set -e

# Default values of arguments
SHOULD_UPGRADE=0
SHOW_HELP=0
INCLUDE_PATHS=""

RELEASEURL="https://api.github.com/repos/snappyflow/apm-agent/releases/latest"
SFTRACE_AGENT_x86_64="https://github.com/snappyflow/apm-agent/releases/download/latest/sftrace-agent.tar.gz"
AGENTDIR="/opt/sfagent"
TDAGENTCONFDIR="/etc/td-agent-bit"
ID=`cat /etc/os-release | grep -w "ID" | cut -d"=" -f2 | tr -d '"'`
SERVICEFILE="/etc/systemd/system/sfagent.service"
DEFAULTPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV_VARS=""
INITFILE="/etc/init.d/sfagent"

SYSTEM_TYPE=`ps --no-headers -o comm 1`
configure_logrotate_flb()
{
    echo "Configure logrotate fluent-bit started"
    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
        apt install -qy logrotate &>/dev/null
    fi

    if [ "$ID" = "centos" ]; then
        yum install -y logrotate &>/dev/null
    fi

    cat > /etc/logrotate.d/td-agent-bit << EOF
/var/log/td-agent-bit.log {
	daily
	dateext
	missingok
	copytruncate
	notifempty
	compress
	rotate 7
}
EOF
  echo "Configure logrotate fluent-bit completed"
}


install_fluent_bit()
{
    echo "                                           "
    echo "Install fluent-bit started "
    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
         apt-get install -y -q wget curl
    fi
    if [ "$ID" = "centos" ]; then
        yum install -y wget curl
    fi
    
    if [ "$SYSTEM_TYPE" = "systemd" ] && [ "$ARCH" != "aarch64" ]; then
        curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep fluentbit \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    elif [ "$SYSTEM_TYPE" = "systemd" ] && [ "$ARCH" = "aarch64" ]; then
        echo "download latest fluent-bit release for $ARCH"
        curl -sL https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep fluent-bit-arm \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
        echo "download latest arm64 fluent-bit release done"
    else
        curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep centos6-td-agent-bit \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    fi
    mkdir -p /opt/td-agent-bit/bin && mkdir -p /etc/td-agent-bit/
    tar -zxvf fluentbit.tar.gz >/dev/null && mv -f fluent-bit /opt/td-agent-bit/bin/td-agent-bit && mv -f GeoLite2-City.mmdb $TDAGENTCONFDIR && mv -f uaparserserver /opt/td-agent-bit/bin/ 
    mv -f td-agent-bit.conf /etc/td-agent-bit/
    configure_logrotate_flb
    echo "Install fluent-bit completed"
    echo "                             "
}

install_sftrace_agent()
{
    echo "                                           "
    echo "Install sftrace java-agent and python-agent started "
    wget $SFTRACE_AGENT_x86_64
    tar -zxvf sftrace-agent.tar.gz >/dev/null && mv -f sftrace /opt/sfagent && mv -f /opt/sfagent/sftrace/sftrace /bin && mv -f /opt/sfagent/sftrace/java/sftrace /opt/sfagent/sftrace
    echo "Install sftrace java-agent and python-agent completed"
    echo "                             "
}

upgrade_fluent_bit()
{
    #td_agent_bit_status=$(systemctl show -p ActiveState td-agent-bit | cut -d'=' -f2)
    #if [ "$td_agent_bit_status" = "active" ];
    #then
    #    systemctl stop td-agent-bit
    #    systemctl disable td-agent-bit
    #fi
    if [ "$SYSTEM_TYPE" = "systemd" ] && [ "$ARCH" != "aarch64" ]; then
        curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep fluentbit \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    elif [ "$SYSTEM_TYPE" = "systemd" ] && [ "$ARCH" = "aarch64" ]; then
        echo "download latest fluent-bit release for $ARCH"
        curl -sL https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep fluent-bit-arm \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
        echo "download latest arm64 fluent-bit release done"
    else
        curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep centos6-td-agent-bit \
        | head -n 1 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    fi
    tar -zxvf fluentbit.tar.gz >/dev/null && mv -f fluent-bit /opt/td-agent-bit/bin/td-agent-bit && mv -f GeoLite2-City.mmdb $TDAGENTCONFDIR && mv -f uaparserserver /opt/td-agent-bit/bin/
    mv -f td-agent-bit.conf /etc/td-agent-bit
    echo "Upgrade fluent-bit binary completed "
}

upgrade_sftrace_agent()
{
    wget $SFTRACE_AGENT_x86_64
    [ -f $AGENTDIR/sftrace/java/elasticapm.properties ] && mv -f /opt/sfagent/sftrace/java/elasticapm.properties .
    rm -rf /opt/sfagent/sftrace
    rm -rf /bin/sftrace
    tar -zxvf sftrace-agent.tar.gz >/dev/null && mv -f sftrace /opt/sfagent && mv -f /opt/sfagent/sftrace/sftrace /bin && mv -f /opt/sfagent/sftrace/java/sftrace /opt/sfagent/sftrace
    [ -f elasticapm.properties ] && mv -f elasticapm.properties /opt/sfagent/sftrace/java/
    echo "Upgrade sftrace java-agent and python-agent completed"

}

upgrade_apm_agent()
{
if [ -d "$AGENTDIR" ]; then
    if [ -f "$SERVICEFILE" ]; then
        echo "Stop sfagent"
        service sfagent stop
    fi
    ARCH=`uname -m`
    echo "Backingup config.yaml"
    cp -f $AGENTDIR/config.yaml _config_backup.yaml
    rm -rf checksum* sfagent* mappings
    
    curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep master \
        | head -n 3 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    ls -l sfagent* checksum* >/dev/null
    if [ $ARCH = "aarch64" ]; then
		tar -zxvf sfagent*linux_arm64.tar.gz >/dev/null
    else
		tar -zxvf sfagent*linux_$ARCH.tar.gz >/dev/null
	fi
    mkdir -p $AGENTDIR/certs
    mkdir -p $AGENTDIR/statsd_rules
    mv -f sfagent $AGENTDIR
    mv -f jolokia.jar $AGENTDIR
    mv -f mappings/* $AGENTDIR/mappings/
    mv -f scripts/* $AGENTDIR/scripts/
    mv -f certs/* $AGENTDIR/certs/
    mv -f statsd/* $AGENTDIR/statsd_rules/
    mv -f config.yaml.sample $AGENTDIR/config.yaml.sample
    echo "Copying back config.yaml"
    cp -f _config_backup.yaml $AGENTDIR/config.yaml
    chown -R root:root /opt/sfagent
    if [ "$SYSTEM_TYPE" = "systemd" ]; then
        create_sfagent_service
    else
        create_sfagent_init_script
    fi
    service sfagent restart
    echo "Upgrading sfagent binaries completed"
else
    echo "directory $AGENTDIR doesn't exists"
    install_apm_agent
fi

}

install_apm_agent()
{
    echo "                         "
    echo "Install sfagent started"
    ARCH=`uname -m`
    rm -rf checksum* sfagent* mappings $AGENTDIR
    curl https://api.github.com/repos/snappyflow/apm-agent/releases?per_page=500 \
        | grep -w "browser_download_url"|grep master \
        | head -n 3 \
        | cut -d":" -f 2,3 \
        | tr -d '"' \
        | xargs wget -q
    ls -l sfagent* checksum* >/dev/null
    if [ $ARCH = "aarch64" ]; then
		tar -zxvf sfagent*linux_arm64.tar.gz >/dev/null
    else
		tar -zxvf sfagent*linux_$ARCH.tar.gz >/dev/null
	fi
    mkdir -p $AGENTDIR
    mkdir -p $AGENTDIR/mappings
    mkdir -p $AGENTDIR/scripts
    mkdir -p $AGENTDIR/certs
    mkdir -p $AGENTDIR/statsd_rules
    mv sfagent $AGENTDIR
    mv jolokia.jar $AGENTDIR
    mv mappings $AGENTDIR/.
    mv scripts $AGENTDIR/.
    mv certs $AGENTDIR/.
    mv statsd/* $AGENTDIR/statsd_rules
    mv config.yaml.sample $AGENTDIR/config.yaml.sample
    cat > $AGENTDIR/config.yaml <<EOF
agent:
metrics:
logging:
tags:
key:
EOF

    chown -R root:root /opt/sfagent
    if [ "$SYSTEM_TYPE" = "systemd" ]; then
        create_sfagent_service
    else
        create_sfagent_init_script
    fi
    service sfagent restart
    echo "Install sfagent completed"
    echo "                               "
}

check_jcmd_installation()
{
echo "                          "
echo "Checking jcmd installation"
if ! [ -x "$(command -v jcmd)" ]; then
  echo "Warning: jcmd is not installed. Java applications will not be detected automatically"
else
  echo "jcmd is installed"
fi
}

create_env_file()
{

echo "Create $AGENTDIR/env.conf file"
touch $AGENTDIR/env.conf

if [ ! -z "$INCLUDE_PATHS" ];
then
    echo "Extra paths to include in PATH - $INCLUDE_PATHS"
    IFS=","
    for v in $INCLUDE_PATHS
    do
        DEFAULTPATH="$DEFAULTPATH:$v"
    done
fi
echo "Environment PATH=$DEFAULTPATH"
echo "PATH=$DEFAULTPATH" > $AGENTDIR/env.conf

if [ ! -z "$ENV_VARS" ]
then
    echo "Append env vars to $AGENTDIR/env.conf"
    IFS=","
    for v in $ENV_VARS
    do
        echo $v >> $AGENTDIR/env.conf
    done
fi

}

create_sfagent_service()
{

# create env file 
create_env_file

echo "create sfagent service file"
cat > "$SERVICEFILE" <<EOF
[Unit]
Description=snappyflow apm agent service
ConditionPathExists=$AGENTDIR/sfagent
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10
WorkingDirectory=$AGENTDIR
EnvironmentFile=-$AGENTDIR/env.conf
ExecStartPre=/bin/mkdir -p /var/log/sfagent
ExecStartPre=/bin/chmod 755 /var/log/sfagent
ExecStartPre=/bin/bash -c -e "/opt/sfagent/sfagent -config-file /opt/sfagent/config.yaml -check-config"
ExecStart=/bin/bash -c -e "/opt/sfagent/sfagent -config-file /opt/sfagent/config.yaml"

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=sfagent

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sfagent

}

create_sfagent_init_script()
{

echo "create sfagent init.d file"
cat > "$INITFILE" <<'EOF'
#!/bin/bash
# sfagent daemon
# chkconfig: - 20 80
# description: EC2 instance SnappyFlow agent
# processname: sfagent

DAEMON_PATH="/opt/sfagent"

NAME=sfagent
DESC="My daemon description"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/sfagent

LOG_PATH=/var/log/sfagent/sfagent.log

DAEMON=/opt/sfagent/sfagent
DAEMONOPTS="-config /opt/sfagent/config.yaml"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 {start|stop|restart}"
    exit 1
else
    COMMAND="$1"
fi

case $COMMAND in
start)
        printf "%-50s" "Starting $NAME..."
        if [[ -f $PIDFILE ]]; then
                PID=`cat $PIDFILE`
                if [[ "`ps axf | grep ${PID} | grep -v grep`" ]]; then
                        echo "sfagent is already running"
                        exit 0
                fi
        fi
        cd $DAEMON_PATH
        CMD="$DAEMON $DAEMONOPTS > /dev/null 2>&1"
        echo $CMD
        $CMD &
        if [ $? -eq 0 ]; then
                printf "%s\n" "Ok"
                echo $! > $PIDFILE
        else
                printf "%s\n" "Fail. Check logs $LOG_PATH"
                exit 1
        fi
        CMD1="update-rc.d sfagent defaults"
        echo $CMD1
        $CMD1 &
        if [ $? -eq 0 ]; then
                printf "\n" "symbolic link added for sfagent"
        else
                printf "%s\n" "Failed while adding symbolic link for sfagent. Check logs $LOG_PATH"
                exit 1
        fi
;;
status)
        printf "%-50s" "Checking $NAME..."
        if [[ -f $PIDFILE ]]; then
                PID=`cat $PIDFILE`
                if [[ -z "`ps axf | grep ${PID} | grep -v grep`" ]]; then
                        printf "%s\n" "Process dead but pidfile exists"
                else
                        echo "Running"
                fi
        else
                printf "%s\n" "Service not running"
        fi
;;
stop)
        printf "%-50s" "Stopping $NAME"
        if [[ -f $PIDFILE ]]; then
                PID=`cat $PIDFILE`
                kill -HUP $PID
                killall -w td-agent-bit
                printf "%s\n" "Ok"
                rm -f $PIDFILE
                exit 0
        else
                printf "%s\n" "already stopped"
                exit 0
        fi
;;

restart)
        $0 stop
        $0 start
;;

*)
        echo "Usage: $0 {status|start|stop|restart}"
        exit 1
esac

EOF

chmod +x "$INITFILE"
echo "sfagent init script created"
}

print_usage()
{
    echo ""
    echo "usage of install.sh"
    echo "  ./install.sh [-h|--help][-u|--upgrade][--paths \"path1,path2\"][--env \"ENV_VAR1=value1,ENV_VAR2=value2\"]"
    echo ""
    echo "  -h|--help    show usage information"
    echo "  -u|--upgrade upgrade installed sfagent"
    echo "  --paths      comma seperated list of paths to include in PATH of sfagent service"
    echo "                 ex: \"/opt/jdk1.8.0_211/bin,/opt/jdk1.8.0_211/jre/bin\""
    echo "  --env        comma seperated list of Environemt variables"
    echo "                 ex: \"HTTP_PROXY=http://proxy.example.com,HTTPS_PROXY=https://proxy.example.com\""
    echo ""
    echo "examples:"
    echo "  ./install.sh"
    echo "  ./install.sh --paths \"/opt/jdk1.8.0_211/bin,/opt/jdk1.8.0_211/jre/bin\""
    echo "  ./install.sh --upgrade"
    echo "  ./install.sh --upgrade --paths \"/opt/jdk1.8.0_211/bin,/opt/jdk1.8.0_211/jre/bin\""
    echo "  ./install.sh --env \"HTTP_PROXY=http://proxy.example.com,HTTPS_PROXY=https://proxy.example.com\""
    echo ""
}

UNKNOWN=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --paths)
    INCLUDE_PATHS="$2"
    shift
    shift
    ;;
    --env)
    ENV_VARS="$2"
    shift
    shift
    ;;
    -h|--help)
    SHOW_HELP=1
    shift
    ;;
    -u|--upgrade)
    SHOULD_UPGRADE=1
    shift
    ;;
    *)
    UNKNOWN+=("$1")
    shift
    ;;
esac
done

if [ ! -z "$UNKNOWN" ]
then 
    echo "ERROR: unknown arguments: $UNKNOWN"
    print_usage
    exit 128
fi

if [ "$SHOW_HELP" -eq 1 ];
then
    print_usage
    exit 0
fi

oldpath=`pwd`
tmp_dir=$(mktemp -d -t installsfagent-XXXXXXXXXX)
cd $tmp_dir

if [ "$EUID" -ne 0 ]; then
    echo "Need to have root previlege to proceed with installation."
    exit 0
fi

if [ "$SHOULD_UPGRADE" -eq 1 ];
then
    echo "Upgrading fluent-bit binary"
    upgrade_fluent_bit
    echo "Upgrading sfagent binaries"
    upgrade_apm_agent
    echo "Upgrading sftrace agent"
    upgrade_sftrace_agent
else
    echo "Check jcmd installed"
    check_jcmd_installation
    echo "Installing fluent-bit binary"
    install_fluent_bit
    echo "Installing APM agent"
    install_apm_agent
    echo "Installing sftrace agent"
    install_sftrace_agent
fi

cd $oldpath
rm -rf $tmp_dir

exit 0
