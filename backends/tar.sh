function tar_init() {
    # nothing to do for tar?
    :
}

# TODO: Make default .tar with optional bup
function tar_create_backup() {
    echo "tar: backing up..."

    # save world to a temporary archive
    ARCHNAME="/tmp/${BACKUP_NAME}_`date +%d-%m-%y-%T`.tar.gz"
    tar -czf "$ARCHNAME" "./$WORLD_NAME"

    if [ ! $? -eq 0 ]
    then
        echo "tar: failed to save the world"
        rm "$ARCHNAME" #remove (probably faulty) archive
        return 1
    else
        echo "tar: world saved to $ARCHNAME, pushing it to backup directories..."
    fi

    RETCODE=2
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        echo "tar: pushing to \"$BACKUP_DIR\""
        # scp acts as cp for local destination directories
        scp "$ARCHNAME" "$BACKUP_DIR/"
        if [ ! $? -eq 0 ]; then
            echo "tar: failed pushing to \"$BACKUP_DIR\", moving on"
        else
            RETCODE=0
        fi
     done

    rm "$ARCHNAME"

    echo "tar: backup finished"

    return $RETCODE
}

function tar_ls() {
    for BACKUP_DIR in ${BACKUP_DIRS[*]}
    do
        echo "Backups in $BACKUP_DIR:"
        if [[ $BACKUP_DIR == *:* ]]; then
            REMOTE="$(echo "$BACKUP_DIR" | cut -d: -f1)"
            REMOTE_DIR="$(echo "$BACKUP_DIR" | cut -d: -f2)"
            ssh "$REMOTE" "ls -1sh $REMOTE_DIR" | grep "tar.gz"
        else
            ls -1sh "$BACKUP_DIR" | grep "tar.gz"
        fi
    done
}
