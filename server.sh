#!/bin/bash

if [ -e "serverconf.sh" ]
then
	source "serverconf.sh"
else
	echo No configuration found in PWD. Exiting.
	exit 1
fi

function backup_hook_example {
	bup -d $CUR_BACK_DIR ls -l $BACKUP_NAME/latest/var/minecraft
}

function send_cmd () {
	tmux -S $TMUX_SOCKET send -t $TMUX_WINDOW "$1" enter
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

	tmux -S $TMUX_SOCKET new-session -s $TMUX_WINDOW -d \
		$JRE_JAVA $JVM_ARGS -jar $JAR $JAR_ARGS
	pid=`tmux -S $TMUX_SOCKET list-panes -t $TMUX_WINDOW -F "#{pane_pid}"`
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
	tmux -S $TMUX_SOCKET attach -t $TMUX_WINDOW
	exit
}

function server_running() {
	if [ -f $PIDFILE ] && [ "$(cat $PIDFILE)" != "" ]; then
		ps -p $(cat $PIDFILE) > /dev/null
		return
	fi
	
	false
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

function players_online() {
	send_cmd "list"
	sleep 1
	while [ $(tail -n 3 "$LOGFILE" | grep -c "There are") -lt 1 ]
	do
		sleep 1
	done

	[ `tail -n 3 "$LOGFILE" | grep -c "There are 0"` -lt 1 ]
}


function server_backup_safe() {
	force=$1
	echo "Detected running server. Checking if players online..."
	if [ "$force" != "true" ] && ! players_online; then
		echo "Players are not online. Not backing up."
		return
	fi

	echo "Disabling autosave"
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

	if [ $USE_BUP = "YES" ]; then
		create_bup_backup
	else
		create_backup_archive
	fi
	
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

	if [ $USE_BUP = "YES" ]; then
		create_bup_backup
	else
		create_backup_archive
	fi

	if [ $? -eq 0 ]
	then
		echo Running backup hook
		$BACKUP_HOOK
	fi
}

function create_bup_backup() {
	BACKUP_DIR="mc-backups"
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

# TODO: Make default .tar with optional bup
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

function backup_running() {
	systemctl is-active --quiet mc-backup.service
}

function fbackup_running() {
	systemctl is-active --quiet mc-fbackup.service
}

function server_backup() {
	force=$1

	if [ "$force" = "true" ]; then
        if backup_running; then
            echo "A backup is running. Aborting..."
            return
        fi
    else
        if fbackup_running; then
            echo "A force backup is running. Aborting..."
            return
        fi
	fi

	if server_running; then 
		server_backup_safe "$force"
	else 
		server_backup_unsafe
	fi

	exit
}

function ls_bup() {
	bup -d "mc-backups/${CUR_YEAR}" ls "mc-sad-squad/$1"
}

#cd $(dirname $0)

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
	"fbackup")
		server_backup "true"
		;;
	"ls")
		ls_bup $2
		;;
	*)
		echo "Usage: $0 start|stop|attach|status|backup"
		;;
esac
