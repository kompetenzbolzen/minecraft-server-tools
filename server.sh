#!/bin/bash

#CONFIG
JRE_JAVA="java"
JVM_ARGS="-Xms4096M -Xmx6144M" 
JAR="minecraft_server.jar"
JAR_ARGS="-nogui"
SCREEN_WINDOW="minecraft"
WORLD_NAME="world"
BACKUP_NAME="mc-sad-squad"
LOGFILE="logs/latest.log"
PIDFILE="server-screen.pid"
#HOOKS
BACKUP_HOOK='backup_hook_example'

function backup_hook_example {
	bup -d $CUR_BACK_DIR ls $BACKUP_NAME
}

function send_cmd () {
	tmux send -t $SCREEN_WINDOW "$1" enter
}

function assert_running() {
	if server_running; then
		echo "It seems a server is already running. If this is not the case,\
			manually attach to the running screen and close it."
		exit 1
	fi
}

function assert_not_running() {
	if ! server_running; then
		echo "Server not running"
		exit 1
	fi
}

function server_start() {
	assert_running

	if [ ! -f "eula.txt" ]
	then
		echo "eula.txt not found. Creating and accepting EULA."
		echo "eula=true" > "eula.txt"
	fi

	tmux new-session -s $SCREEN_WINDOW -d \
		$JRE_JAVA $JVM_ARGS -jar $JAR $JAR_ARGS
	pid=`tmux list-panes -t $SCREEN_WINDOW -F "#{pane_pid}"`
	echo $pid > $PIDFILE
	echo Started with PID $pid
	exit
}

function server_stop() {
	# Allow success even if server is not running
	#trap "exit 0" EXIT

	assert_not_running
	send_cmd "stop"

	local RET=1
	while [ ! $RET -eq 0 ]
	do
		sleep 1
		ps -p $(cat $PIDFILE) > /dev/null
		RET=$?
	done

	echo "stopped the server"

	rm -f $PIDFILE

	exit
}

function server_attach() {
	assert_not_running
	tmux attach -t $SCREEN_WINDOW
	exit
}

function server_running() {
	[ -f $PIDFILE ] && [ "$(cat $PIDFILE)" != "" ]
	return # Returns the status of above conditional. Failure (1) if false, Success (0) if true.

	ps -p $(cat $PIDFILE) > /dev/null
}

function server_status() {
	if server_running
	then
		echo "Server is running"
	else
		echo "Server is not running"
	fi
	exit
}

function server_backup_safe() {
	echo "Detected running server. Disabling autosave"
	send_cmd "save-off"
	send_cmd "save-all flush"
	echo "Waiting for save... If froze, run /save-on to re-enable autosave!!"
	
	sleep 1
	while [ $(tail -n 3 "$LOGFILE" | grep -c "Saved the game") -lt 1 ]
	do
		sleep 1
	done
	sleep 2
	echo "Done! starting backup..."

	create_bup_backup
	local RET=$?

	echo "Re-enabling auto-save"
	send_cmd "save-on"

	if [ $RET -eq 0 ]
	then
		echo Running backup hook
		$BACKUP_HOOK
	fi
}

function server_backup_unsafe() {
	echo "No running server detected. Running Backup"

	create_bup_backup

	if [ $? -eq 0 ]
	then
		echo Running backup hook
		$BACKUP_HOOK
	fi
}

function create_bup_backup() {
	BACKUP_DIR="mc-backups"
	CUR_YEAR=`date +"%Y"`
	CUR_BACK_DIR="mc-backups/$CUR_YEAR"

	if [ ! -d "$CUR_BACK_DIR" ]; then
	mkdir -p "$CUR_BACK_DIR"
	fi


	bup -d "$CUR_BACK_DIR" index "$WORLD_NAME"
	status=$?
	if [ $status -eq 1 ]; then
	bup -d "$CUR_BACK_DIR" init
	bup -d "$CUR_BACK_DIR" index "$WORLD_NAME"
	fi

	bup -d "$CUR_BACK_DIR" save -n "$BACKUP_NAME" "$WORLD_NAME"

	echo "Backup using bup to $CUR_BACK_DIR is complete"
}

# Deprecated
function create_backup_archive() {
	ARCHNAME="backup/$WORLD_NAME-backup_`date +%d-%m-%y-%T`.tar.gz"
	tar -czf "$ARCHNAME" "./$WORLD_NAME"

	if [ ! $? -eq 0 ]
	then
		echo "TAR failed. No Backup created."
		rm $ARCHNAME #remove (probably faulty) archive
		return 1
	else
		echo $ARCHNAME created.
	fi
}

function server_backup() {
	if server_running; then 
		server_backup_safe
	else 
		server_backup_unsafe
	fi

	exit
}

cd $(dirname $0)

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
	# TODO: Add restore command
	"status")
		server_status
		;;
	*)
		echo "Usage: $0 start|stop|attach|status|backup"
		;;
esac
