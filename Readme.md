# minecraft-server-tools

My minecraft server management script with safe online Backup.

## Configuration

Config-variables are located at the top of `server.sh`

## Usage

`./server.sh start|stop|attach|status|backup`

### start

Creates a `screen` session and starts a minecraft server within.
Fails, if a session is already running with the same sessionname.

### stop

Sends `stop` command to running server instance to safely shut down.

### attach

attaches to `screen` session. Exit with `CTRL + A d`

### status

lists active screen sessions with `SCREEN_SESSIONNAME`.

### backup

Backs up the world as a `tar.gz` archive in `./backup/`.
If a running server is detected,
the world is flushed to disk and autosave is disabled temporarily to prevent chunk corruption.

The command specified in `$BACKUP_HOOK` is
executed on every successful backup. `$ARCHNAME` contains the relative path to the archive.
This can be used to further process the created backup.

The following example copies the created archive to a remote server.

    BACKUP_HOOK="scp $ARCHNAME user@server:/home/user/backups/"

## Start automatically

Create user and group `minecraft` with home in `/var/minecraft`.
Populate the directory with server.sh and a server jar.
Place `minecraft.service` in `/etc/systemd/system/`
and run `systemctl start minecraft` to start once or
`systemctl enable minecraft` to enable autostarting.

## Disclaimer

The scripts are provided as-is at no warranty.
They are in no way idiot-proof.

Improvements are welcome.
