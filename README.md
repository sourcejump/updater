# Updater

Allows developers to automatically update their plugins and files. Updates will be checked on server startup and then once every 24 hours. All updates will be logged to Updater.log in your SourceMod log directory.

## Installation:

Your server must be running at least one of the following extensions:
- [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556)

Extract updater.zip to your SourceMod directory.

## Cvars:

```
sm_updater <1|2|3> - Determines update functionality.
    1 = Only notify in the log file when an update is available.
    2 = Automatically download and install available updates. *Default
    3 = Include the source code with updates.
```

## Commands:

```
sm_updater_check - Forces Updater to check all plugins for updates. Can only be run once per hour.
sm_updater_status - View the status of Updater.
```
