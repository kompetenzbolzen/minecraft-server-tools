function tar_init() {
    # nothing to do for tar?
    :
}

# TODO: Make default .tar with optional bup
function tar_create_backup() {
    echo "tar: backing up..."

	local status

    # save world to a temporary archive
    local archname="/tmp/${BACKUP_NAME}_`date +%FT%H%M%S%z`.tar.gz"
    tar -czf "$archname" "./$WORLD_NAME"
	status=$?
    if [ $status -ne 0 ]; then
        echo "tar: failed to save the world"
        rm "$archname" #remove (probably faulty) archive
        return 1
    fi
    echo "tar: world saved to $archname, pushing it to backup directories..."

	# 0 if could save to at least one backup dir
	# TODO: make more strict?
    local retcode=1
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        echo "tar: pushing to \"$backup_dir\""
        # scp acts as cp for local destination directories
        scp "$archname" "$backup_dir/"
		status=$?
        if [ $status -ne 0 ]; then
            echo "tar: failed pushing to \"$backup_dir\", moving on"
        else
            retcode=0
        fi
     done

    rm "$archname"

    echo "tar: backup finished"

    return $retcode
}

# server_restore relies on output format of this function
function tar_ls_dir() {
    local backup_dir="$1"

    if [[ "$backup_dir" == *:* ]]; then
        local remote="$(echo "$backup_dir" | cut -d: -f1)"
        local remote_dir="$(echo "$backup_dir" | cut -d: -f2)"
        ssh "$remote" "ls -1 $remote_dir" | grep "tar.gz" | sort -r
    else
        ls -1 "$backup_dir" | grep "tar.gz" | sort -r
    fi
}

function tar_ls_all() {
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        echo "tar: backups in ${backup_dir}:"
        tar_ls_remote "$backup_dir"
    done
}

function tar_restore() {
    local remote="$1"
    local snapshot="$2"
	local status

    scp "$remote/$snapshot" "/tmp/"
	status=$?
    if [ $status -ne 0 ]; then
        echo "tar: failed to get archive from \"$remote/$snapshot\""
        return 1
    fi

    tar -xzf "/tmp/$snapshot"
}
