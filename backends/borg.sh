function borg_init() {
	local encryption
	if [ -z "$BACKUP_PASSCOMMAND" ] ; then
		log_info "borg: no password given, repository is not protected"
		encryption="none"
	else
		encryption="repokey-blake2"
	fi

    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    for backup_dir in ${BACKUP_DIRS[*]}
    do
		log_debug "Initializing repo at $backup_dir "
        # borg will check if repo exists
        borg init --encryption="$encryption" "$backup_dir"
	done
}

function borg_create_backup() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    local retcode=255
    for backup_dir in ${BACKUP_DIRS[*]}
    do
        export BORG_REPO="$backup_dir"

        trap 'echo [WARNING] $( date ) Backup interrupted >&2; exit 2' INT TERM

        log_info "borg: backing up to \"$backup_dir\""

        borg create                         \
            "${backup_dir}::${BACKUP_NAME}_$(date +'%F_%H-%M-%S')" \
            "$WORLD_NAME"               \
            --filter AME                    \
            --compression lz4               \
            --exclude-caches                \

        local backup_exit=$?

        log_debug "borg: pruning repository at \"$backup_dir\""

        borg prune                          \
            --prefix '{hostname}-'          \
            --keep-minutely 2               \
            --keep-hourly   24              \
            --keep-daily    7               \
            --keep-weekly   4               \
            --keep-monthly  6               \
            "$backup_dir"

        local prune_exit=$?

        # use highest exit code as global exit code
        local global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
        retcode=$(( global_exit > retcode ? global_exit : retcode ))

        if [ ${global_exit} -eq 0 ]; then
            log_debug "borg: backup and prune finished successfully"
        elif [ ${global_exit} -eq 1 ]; then
            log_info "borg: backup and/or prune finished with warnings"
        else
            log_error "borg: backup and/or prune finished with errors"
        fi
        #exit ${global_exit}
    done
    return $retcode
}

# server_restore relies on output format of this function
function borg_ls() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    borg list "$1" | cut -d' ' -f1 | sort -r
}

function borg_restore() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    local remote="$1"
    local snapshot="$2"
	local dest="$3"

    export BORG_REPO="$remote"
	cd "$dest"
    borg extract "${remote}::${snapshot}"
	cd - > /dev/null
}
