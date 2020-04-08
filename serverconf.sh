# serverconf.sh
# configuration file for server.sh minecraft server 
# management script

#CONFIG
JRE_JAVA="java"
JVM_ARGS="-Xms4096M -Xmx6144M" 
JAR="fabric-server-launch.jar"
JAR_ARGS="-nogui"

TMUX_WINDOW="minecraft"
TMUX_SOCKET="mc_tmux_socket"

WORLD_NAME="lfja"

BACKUP_NAME="${WORLD_NAME}_backup"
LOGFILE="logs/latest.log"
PIDFILE="server-screen.pid"
USE_BUP="NO"

#Constants
CUR_YEAR=`date +"%Y"`

