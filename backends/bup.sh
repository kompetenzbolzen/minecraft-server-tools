# use first not-remote backup directory as bup's local repository
# defaults to ".bup"
function bup_local() {
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        if [[ $backup_dir != *:* ]]; then
            echo "$backup_dir"
            return
        fi
    done
	echo ".bup"
}

function bup_init() {
    bup -d "$(bup_local)" index "$WORLD_NAME"
    local status=$?
    if [ $status -ne 0 ]; then
        echo_debug "bup: no local repo found, creating..."
        bup -d "$(bup_local)" init -r "$(bup_local)"
        echo_debug "bup: created local repo at $(bup_local)"
    fi
}

function bup_create_backup() {
    echo_debug "bup: backup started"

    bup -d "$(bup_local)" index "$WORLD_NAME"

    # 0 if saved to at least one non-local repository
	# TODO make more strict?
    local retcode=1
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        echo_debug "bup: backing up to \"$backup_dir\""
        # try to save to remote
        bup -d "$(bup_local)" save -r "$backup_dir" -n "$BACKUP_NAME" "$WORLD_NAME"
		local status=$?
        # if failed - reinit remote and try again
        if [ $status -ne 0 ]; then
            echo_debug "bup: failed backing up to \"$backup_dir\", reinitializing remote..."
            bup -d "$(bup_local)" init -r "$backup_dir"
			status=$?
            if [ $status -ne 0 ]; then
                echo_debug "bup: created remote at \"$backup_dir\""
                bup -d "$(bup_local)" save -r "$backup_dir" -n "$BACKUP_NAME" "$WORLD_NAME"
            else
                echo "bup: failed to make remote at \"$backup_dir\", moving on"
            fi
        else
            if [ ! "$backup_dir" = "$(bup_local)" ]; then
                retcode=0
            fi
        fi
    done

    echo "bup: backup finished"
    return $retcode
}

# server_restore relies on output format of this function
function bup_ls_dir() {
	local backup_dir="$1"
    bup -d "$(bup_local)" ls -r "$backup_dir" "$BACKUP_NAME" | sort -r
}

function bup_ls_all() {
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        echo "bup: backups in \"$BACKUP_DIR\":"
        bup -d "$(bup_local)" ls -r "$backup_dir" --human-readable -l "$BACKUP_NAME"
    done
}

function bup_restore() {
    local remote="$1"
    local snapshot="$2"
	local dest="$3"
    bup -d "$(bup_local)" restore -r "$remote" --outdir "$dest" "$BACKUP_NAME/$snapshot/$PWD/."
}
