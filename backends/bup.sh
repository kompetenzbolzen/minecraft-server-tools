# use first not-remote backup directory as bup's local repository
# defaults to ".bup"
function bup_local() {
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        if [[ $BACKUP_DIR != *:* ]]; then
            echo "$BACKUP_DIR"
            return
        fi
    done
    echo ".bup"
}

function bup_init() {
    bup -d "$(bup_local)" index "$WORLD_NAME"
    status=$?
    if [ $status -ne 0 ]; then
        echo "bup: no local repo found, creating..."
        bup -d "$(bup_local)" init -r "$(bup_local)"
        echo "bup: created local repo at $(bup_local)"
    fi
}

function bup_create_backup() {
    echo "bup: backup started"

    bup -d "$(bup_local)" index "$WORLD_NAME"

    # 0 if saved to at least one non-local repository
    RETCODE=1
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        echo "bup: backing up to \"$BACKUP_DIR\""
        # try to save to remote
        bup -d "$(bup_local)" save -r "$BACKUP_DIR" -n "$BACKUP_NAME" "$WORLD_NAME"
        # if failed - reinit remote and try again
        if [ ! $? -eq 0 ]; then
            echo "bup: failed backing up to \"$BACKUP_DIR\", reinitializing remote..."
            bup -d "$(bup_local)" init -r "$BACKUP_DIR"
            if [ ! $? -eq 0 ]; then
                echo "bup: created remote at \"$BACKUP_DIR\""
                bup -d "$(bup_local)" save -r "$BACKUP_DIR" -n "$BACKUP_NAME" "$WORLD_NAME"
            else
                echo "bup: failed to make remote at \"$BACKUP_DIR\", moving on"
            fi
        else
            if [ "$BACKUP_DIR" = "$(bup_local)" ]; then
                RETCODE=0
            fi
        fi
    done

    echo "bup: backup finished"
    return $RETCODE
}

function bup_ls_remote() {
    bup -d "$(bup_local)" ls -r "$BACKUP_DIR" "$BACKUP_NAME"
}

function bup_ls() {
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        echo "bup: backups in \"$BACKUP_DIR\":"
        bup -d "$(bup_local)" ls -r "$BACKUP_DIR" --human-readable -l "$BACKUP_NAME"
    done
}

function bup_restore() {
    REMOTE="$1"
    SNAPSHOT="$2"

    bup -d "$(bup_local)" restore -r "$REMOTE" "$BACKUP_NAME/$SNAPSHOT/$PWD/."
}
