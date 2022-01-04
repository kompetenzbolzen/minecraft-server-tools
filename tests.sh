#!/bin/bash

source server.sh

# TODO: testing remote directories
BACKUP_DIRS=(".bak")
mkdir ".bak"

function test_backend() {
	BACKUP_BACKEND="$1"

	# doing tests inside /tmp/
	DIR=$(mktemp -d)
	cd "$DIR"
	local status=$?
	if [ $status -ne 0 ] ; then
		echo "Failed to make a temporary directory"
		return 1
	fi
	function cleanup() {
		rm -r "$DIR"
	}

	# make a "world" with some volatile data
	function make_world() {
		mkdir -p "$DIR/$1/DIM0"
		date > "$1/data0"
		shuf -e {1..100} | tr '\n' ' ' > "$DIR/$1/DIM0/data1"
	}

	# make two versions of a world and back up both
	make_world "$WORLD_NAME"
	local old_world="${WORLD_NAME}.orig0"
	cp -r "$DIR/$WORLD_NAME" "$DIR/$old_world"
	if ! server_backup ; then
		cleanup
		exit
	fi

	# backup time in archive's name is specified up to seconds, so subsequent backups without some delay will have the same name and previous backup be overwritten
	if [ $BACKUP_BACKEND = "tar" ]; then
		sleep 1
	fi

	make_world "$WORLD_NAME"
	local new_world="${WORLD_NAME}.orig1"
	cp -r "$DIR/$WORLD_NAME" "$DIR/$new_world"
	if ! server_backup ; then
		cleanup
		exit
	fi

	function same_world() {
		delta=$(diff -r "$DIR/$1" "$DIR/$2")
		if [ -z "$delta" ] ; then
			return 0
		fi
		return 1
	}

	# corrupting current (new) world
	find "$DIR/$WORLD_NAME" -type f -exec shred {} \;
	if same_world "$WORLD_NAME" "$new_world" ; then
		echo "Failed to corrupt new world"
		cleanup
		exit
	fi


	# restore new backup
	server_restore "${BACKUP_DIRS[0]}" 0
	# must be: new backup == new world
	if ! same_world "$WORLD_NAME" "$new_world" ; then
		echo "${BACKUP_BACKEND}: new backup != new world"
		cleanup
		exit
	fi
	# must be: new backup != old world
	if same_world "$WORLD_NAME" "$old_world" ; then
		echo "${BACKUP_BACKEND}: new backup == old world"
		cleanup
		exit
	fi


	# restore old backup
	if [ $BACKUP_BACKEND = "bup" ]; then
		# bup's 0th option is "latest", which links to 1st option, this is not present in tar and borg
		server_restore "${BACKUP_DIRS[0]}" 2
	else
		server_restore "${BACKUP_DIRS[0]}" 1
	fi
	# must be: old backup == old world
	if ! same_world "$WORLD_NAME" "$old_world" ; then
		echo "${BACKUP_BACKEND}: old backup != old world"
		cleanup
		exit
	fi
	# must be: old backup != new world
	if same_world "$WORLD_NAME" "$new_world" ; then
		echo "${BACKUP_BACKEND}: old backup == new world"
		cleanup
		exit
	fi

	cleanup
}

echo "Testing tar backend"
test_backend "tar"

echo "Testing bup backend"
test_backend "bup"

echo "Testing borg backend"
test_backend "borg"

echo "All tests passed"
