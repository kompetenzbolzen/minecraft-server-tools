# minecraft-server-tools

My minecraft server management script with safe online backup.

Supports backing up using several backends to multiple local and remote directories.

## Dependencies

- [tmux](https://github.com/tmux/tmux)

Either of backup backends:
- tar
- [bup](https://github.com/bup/bup)
- [borgbackup](https://github.com/borgbackup/borg)

All of them are available on the Debian repository.

## Configuration

Config variables are located at `serverconf.sh`.

## Usage

`./server.sh start|stop|attach|status|backup|fbackup|restore|ls`

### start

Creates a `tmux` session and starts a minecraft server within.
Fails, if a session is already running with the same sessionname.

### stop

Sends `stop` command to running server instance to safely shut down.

### attach

Attaches to tmux session with a server. Detach with `CTRL + A d`.

### status

Shows if the server is running.

### backup

Creates a backup of the current world:

- If a running server is detected,
the world is flushed to disk and autosave is disabled temporarily to prevent chunk corruption.

- Initializes backup directories if needed.

- Backs up the world **if there are players on the server**.
The backup has `$BACKUP_NAME_<current time>` prefix.

- Performs tests: backup is pulled from each backup directory and is compared to the current world.
This behaviour is controlled with `$BACKUP_CHECK_MODE`.

- The command specified in `$BACKUP_HOOK` is
executed on every successful backup. `$ARCHNAME` contains the relative path to the archive.
This can be used to further process the created backup.

This is recommended for automated backups.

**Warning** If all players leave just before a backup, progress is not saved.

### fbackup

Does the same as `backup`, but does not check for presence of players.

This is not recommended for automated use except for deduplicating backup backends (bup and borgbackup).

### restore

Restores a backup from selected directory.
Old world is preserved with a current timestamp.

### ls

Lists backups in all directories.

## Start automatically

Create user and group `minecraft` with home in `/var/minecraft`.
Populate the directory with `server.sh`, `serverconf.sh`, `backends` and a server jar.
Place `minecraft.service` in `/etc/systemd/system/`
and run `systemctl start minecraft` to start once or
`systemctl enable minecraft` to enable autostarting.

To backup automatically, place or symlink `mc-backup.service` and
`mc-backup.timer` in `/etc/systemd/system/`. Run the following:

```
sudo systemctl  enable mc-backup.timer
sudo sytemctl start mc-backup.timer
```

This wil start the enable the timer upon startup and start the timer
to run the backup after every interval specified in mc-backup.timer.

## Disclaimer

The scripts are provided as-is at no warranty.
They are in no way idiot-proof.

Improvements are welcome.

## TODO
- Allow non-forced backup to be run one time with no players on the server.
- Reach similar automated behaviour without depending on systemd?
