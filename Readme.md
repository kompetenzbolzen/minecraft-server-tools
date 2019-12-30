# minecraft-server-tools

My minecraft server management script with safe online Backup.

## Usage

`./server.sh start|stop|attach|status`

`attach` attaches to the server console using `screen`. to detach, type: `CTRL+A d`

Configuration is located at at the top of the script. 

The command specified in `$BACKUP_HOOK` is
executed on every backup. `$ARCHNAME` contains the relative path to the backup.

Example:

    scp $ARCHNAME user@server:/home/backups/

## Disclaimer

The scripts are provided as-is at no warranty.
They are not idiot-proof.

Improvements are welcome.
