# TODO: Make default .tar with optional bup
function tar_create_backup() {
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
