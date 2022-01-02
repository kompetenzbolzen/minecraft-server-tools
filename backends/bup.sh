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

function ls_bup() {
    bup -d "mc-backups/${CUR_YEAR}" ls "mc-sad-squad/$1"
}
