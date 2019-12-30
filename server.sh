#!/bin/bash

#CONFIG
JRE_JAVA="java"
JVM_ARGS="-Xms9G -Xmx9G" 
JAR="fabric-server-launch.jar"
JAR_ARGS="-nogui"
SCREEN_WINDOW="minecraftserverscreen"
WORLD_NAME="world"
LOGFILE="mcserver.log"

#HOOKS
BACKUP_HOOK="echo HOOK"

function send_cmd () {
	screen -S $SCREEN_WINDOW -p 0 -X stuff "$1^M"
}

function server_start() {
	screen -L -Logfile "$LOGFILE" -S $SCREEN_WINDOW -p 0 -d -m $JRE_JAVA $JVM_ARGS -jar $JAR $JAR_ARGS
	exit
}

function server_stop() {
	send_cmd "stop"
	exit
}

function server_attach() {
	screen -r -p 0 $SCREEN_WINDOW
	exit
}

function server_status() {
	screen -list $SCREEN_WINDOW
	exit
}

function server_backup() {
	send_cmd "save-off"
	send_cmd "save-all flush"
	echo "Waiting for save... If froze, run /save-on to re-enable autosave!!"
	
	sleep 1
	while [ $(tail -n 3 "$LOGFILE" | grep -c "Saved the game") -lt 1 ]
	do
		sleep 1
	done
	echo "Done! starting backup..."

	local ARCHNAME="backup/$WORLD_NAME-backup_`date +%d-%m-%y-%T`.tar.gz"
	tar -czvf "$ARCHNAME" "./$WORLD_NAME"
	
	echo "Done! Saved in $ARCHNAME"
	echo "Re-enabling auto-save"
	send_cmd "save-on"

	echo "Running Backup-Hook"
	$BACKUP_HOOK
}

case $1 in
	"start")
		server_start
		;;
	"stop")
		server_stop
		;;
	"attach")
		server_attach
		;;
	"backup")
		server_backup
		;;
	"status")
		server_status
		;;
	*)
		echo "Usage: $0 start|stop|attach|status|backup"
		;;
esac	
