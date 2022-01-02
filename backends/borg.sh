function borg_init() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        # borg will check if repo exists
        borg init --encryption=repokey-blake2 "$BACKUP_DIR"
    done
}

function borg_create_backup() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    RETCODE=255
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        export BORG_REPO="$BACKUP_DIR"

        trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

        echo "borg: starting backup to \"$BACKUP_DIR\""

        borg create                         \
            "${BACKUP_DIR}::${BACKUP_NAME}_{hostname}_{now}" \
            "$WORLD_NAME"               \
            --filter AME                    \
            --compression lz4               \
            --exclude-caches                \

            backup_exit=$?

        echo "borg: pruning repository at \"$BACKUP_DIR\""

        borg prune                          \
            --prefix '{hostname}-'          \
            --keep-minutely 2               \
            --keep-hourly   24              \
            --keep-daily    7               \
            --keep-weekly   4               \
            --keep-monthly  6               \
            "$BACKUP_DIR"

        prune_exit=$?

        # use highest exit code as global exit code
        global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
        RETCODE=$(( global_exit > RETCODE ? global_exit : RETCODE ))

        if [ ${global_exit} -eq 0 ]; then
            echo "borg: backup and prune finished successfully"
        elif [ ${global_exit} -eq 1 ]; then
            echo "borg: backup and/or prune finished with warnings"
        else
            echo "borg: backup and/or prune finished with errors"
        fi
        #exit ${global_exit}
    done
    return $RETCODE
}

function borg_ls() {
    export BORG_PASSCOMMAND="$BACKUP_PASSCOMMAND"
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        echo "borg: backups in \"$BACKUP_DIR\":"
        borg list "$BACKUP_DIR"
    done
}
