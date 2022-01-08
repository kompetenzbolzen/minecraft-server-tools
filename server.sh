#!/bin/bash

if [ -e "serverconf.sh" ]
then
	source "serverconf.sh"
else
	log_error "No configuration found in PWD. Exiting."
	exit 1
fi

source "backends/tar.sh"
source "backends/bup.sh"
source "backends/borg.sh"

function log_debug() {
	if [ $VERBOSE -ne 0 ]; then
		printf "[DEBUG] $1\n" >&2
	fi
}
log_info() { printf "[INFO] $1\n" ; }
log_error() { printf "[ERROR] $1\n" >&2 ; }

function backup_hook_example {
	bup -d $CUR_BACK_DIR ls -l "$BACKUP_NAME/latest/var/minecraft"
}

function send_cmd () {
	tmux -S $TMUX_SOCKET send -t $TMUX_WINDOW "$1" enter
}

function assert_not_running() {
	if server_running; then
		log_info "It seems a server is already running. If this is not the case,\
			manually attach to the running screen and close it."
		exit 1
	fi
}

function assert_running() {
	if ! server_running; then
		log_info "Server not running"
		exit 1
	fi
}

function server_start() {
	assert_not_running

	if [ ! -f "eula.txt" ]
	then
		log_info "eula.txt not found. Creating and accepting EULA."
		echo "eula=true" > "eula.txt"
	fi

	tmux -S $TMUX_SOCKET new-session -s $TMUX_WINDOW -d \
		$JRE_JAVA $JVM_ARGS -jar $JAR $JAR_ARGS
	pid=`tmux -S $TMUX_SOCKET list-panes -t $TMUX_WINDOW -F "#{pane_pid}"`
	echo $pid > $PIDFILE
	log_info "Started with PID $pid"
	exit
}

function server_stop() {
	# Allow success even if server is not running
	#trap "exit 0" EXIT

	assert_running
	send_cmd "stop"

	local RET=1
	while [ ! $RET -eq 0 ]
	do
		sleep 1
		ps -p $(cat $PIDFILE) > /dev/null
		RET=$?
	done

	log_info "stopped the server"

	rm -f $PIDFILE

	exit
}

function server_attach() {
	assert_running
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
		log_info "Server is running"
	else
		log_info "Server is not running"
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

function backup_backend_run() {
	local cmd
	# could do ${BACKUP_BACKEND}_$1 though
	if [ $BACKUP_BACKEND = "bup" ]; then
		cmd="bup"
	elif [ $BACKUP_BACKEND = "borg" ]; then
		cmd="borg"
	else
		cmd="tar"
	fi
	cmd="${cmd}_$1"
	log_debug "Backup backend command: \"$cmd\""
	eval "$cmd"
}

function init_backup() {
	# even though bup and borg are smart, they will not create a path for a repo
	for backup_dir in ${BACKUP_DIRS[*]}
	do
		if [[ $backup_dir == *:* ]]; then
			local remote="$(echo "$backup_dir" | cut -d: -f1)"
			local remote_dir="$(echo "$backup_dir" | cut -d: -f2)"
			ssh "$remote" "mkdir -p \"$remote_dir\""
		else
			mkdir -p "$backup_dir"
		fi
	done

	backup_backend_run "init"
}

function same_world() {
	delta=$(diff -r "$1" "$2")
	if [ $? -ne 0 ]; then
		return 1
	fi
	if [ -z "$delta" ] ; then
		return 0
	fi
	return 1
}

# checking if latest snapshots are the same as the current world
function test_backup_integrity() {
	local retcode=0
	for backup_dir in ${BACKUP_DIRS[*]}
	do
		local tmpdir=$(mktemp -d);

		# restore most recent backup to a temporary dir
		if ! server_restore "$backup_dir" 0 "$tmpdir" ; then
			log_error "Failed to get latest snapshot from \"$backup_dir\""
			retcode=1
		elif ! same_world "$WORLD_NAME" "$tmpdir/$WORLD_NAME" ; then
			log_error "Latest backup from \"$backup_dir\" differs from current world!"
			retcode=1
		else
			log_info "Backup at \"$backup_dir\" is OK"
		fi

		rm -r "$tmpdir"
	done

	if [ $retcode -ne 0 ] ; then
		log_error "Backup integrity check: FAILED"
	else
		log_info "Backup integrity check: OK"
	fi
	return $retcode
}

function create_backup() {
	init_backup
	backup_backend_run "create_backup"
	test_backup_integrity
}

function server_backup_safe() {
	local force=$1
	log_info "Detected running server. Checking if players online..."
	if [ "$force" != "true" ] && ! players_online; then
		log_info "Players are not online. Not backing up."
		return
	fi

	log_info "Disabling autosave"
	send_cmd "save-off"
	send_cmd "save-all flush"
	log_info "Waiting for save... If froze, run /save-on to re-enable autosave!!"

	sleep 1
	while [ $(tail -n 3 "$LOGFILE" | grep -c "Saved the game") -lt 1 ]
	do
		sleep 1
	done
	sleep 2
	log_info "Done! starting backup..."

	create_backup

	local RET=$?

	log_info "Re-enabling auto-save"
	send_cmd "save-on"

	if [ $RET -eq 0 ]; then
		log_info "Running backup hook"
		$BACKUP_HOOK
	fi
}

function server_backup_unsafe() {
	log_info "No running server detected. Running Backup"

	create_backup
	local status=$?

	if [ $status -eq 0 ]; then
		log_info "Running backup hook"
		$BACKUP_HOOK
	fi
}

function backup_running() {
	systemctl is-active --quiet mc-backup.service
}

function fbackup_running() {
	systemctl is-active --quiet mc-fbackup.service
}

function server_backup() {
	local force=$1

	if [ "$force" = "true" ]; then
		if backup_running; then
			log_info "A backup is running. Aborting..."
			return
		fi
	else
		if fbackup_running; then
			log_info "A force backup is running. Aborting..."
			return
		fi
	fi

	if server_running; then
		server_backup_safe "$force"
	else
		server_backup_unsafe
	fi
}

function server_ls_backups() {
	for backup_dir in ${BACKUP_DIRS[*]}
	do
		log_info "backups in ${backup_dir}:"
		backup_backend_run "ls \"$backup_dir\""
	done
}

# creates a selection dialog
function choose_from() {
	local items=("$@")
	select item in "${items[@]}"; do
		echo "$item"
		return
	done
}

# checks if an item is in the array
function is_in() {
	local item="$1"
	shift
	local array=("$@")

	# these :space: things allow checking that *exactly* this item is in array
	if [[ ${array[*]} =~ (^|[[:space:]])"$item"($|[[:space:]]) ]]; then
		return
	fi
	false
}

function server_restore() {
	local backup_dir
	local snapshot_index
	local dest="$PWD"

	# parameters are only used for testing backups, so thorough checks are not needed
	if [ $# -ge 2 ]; then
		backup_dir="$1"
		snapshot_index=$2
	fi
	if [ $# -eq 3 ]; then
		dest="$3"
	fi

	if [ "$dest" = "$PWD" ]; then
		assert_not_running
	fi

	if [ ${#BACKUP_DIRS[@]} -eq 0 ]; then
		log_error "No backup directories found, abort"
		return 1
	fi


	if [ -z $backup_dir ]; then
		log_info "From where get the snapshot?"
		backup_dir="$(choose_from "${BACKUP_DIRS[@]}")"
	fi
	if ! is_in "$backup_dir" "${BACKUP_DIRS[@]}" ; then
		log_error "No valid backup directory selected, abort"
		return 1
	fi


	local snapshots="$( backup_backend_run "ls \"$backup_dir\"" )"
	log_debug "Snapshots found:"
	log_debug "$snapshots"
	if [ -z "$snapshots" ]; then
		log_error "No snapshots found, abort"
		return 1
	fi
	# convert multiline string to bash array
	snapshots=($(echo "$snapshots"))


	local snapshot
	if [ -z $snapshot_index ]; then
		log_info "Select which snapshot to restore"
		snapshot=$(choose_from "${snapshots[@]}")
	else
		snapshot="${snapshots[snapshot_index]}"
	fi
	if ! is_in "$snapshot" "${snapshots[@]}" ; then
		log_error "No valid snapshot selected, abort"
		return 1
	fi


	log_debug "Restoring snapshot \"$snapshot\" from \"$backup_dir\""

	# if we restore to PWD, we will overwrite the current world, which might be harmful
	local oldworld_name
	if [ "$dest" = "$PWD" ] && [[ -d "$WORLD_NAME" ]]; then
		oldworld_name="${WORLD_NAME}.old.$(date +'%F_%H-%M-%S.%N')"
		log_info "Preserving old world: $(mv -n -v "$PWD/$WORLD_NAME" "$PWD/$oldworld_name")"
	fi


	backup_backend_run "restore \"$backup_dir\" \"$snapshot\" \"$dest\""
	local status=$?


	# if we preseved the current world, but failed to restore the snapshot
	if [ ! -z ${oldworld_name+x} ] && [ $status -ne 0 ]; then
		log_error "Failed to restore snapshot, putting old world back where it was:"
		rm -rv "$PWD/$WORLD_NAME"
		mv -v "$PWD/$oldworld_name" "$PWD/$WORLD_NAME"
		return 1
	fi

	log_debug "Snapshot restored"

	return 0
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
	"restore")
		server_restore
		;;
	"status")
		server_status
		;;
	"fbackup")
		server_backup "true"
		;;
	"ls")
		server_ls_backups
		;;
	*)
		echo "Usage: $0 start|stop|attach|status|backup"
		;;
esac
