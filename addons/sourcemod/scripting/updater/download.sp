/* Download Manager */

#include "download_steamworks.sp"

static DataPackPos QueuePack_URL;

void FinalizeDownload(int index)
{
	/* Strip the temporary file extension from downloaded files. */
	char newpath[PLATFORM_MAX_PATH];
	char oldpath[PLATFORM_MAX_PATH];
	ArrayList hFiles = Updater_GetFiles(index);

	for (int i = 0; i < hFiles.Length; i++)
	{
		hFiles.GetString(i, newpath, sizeof(newpath));
		Format(oldpath, sizeof(oldpath), "%s.%s", newpath, TEMP_FILE_EXT);

		// Rename doesn't overwrite on Windows. Make sure the path is clear.
		if (FileExists(newpath))
		{
			DeleteFile(newpath);
		}

		RenameFile(newpath, oldpath);
	}

	hFiles.Clear();
}

void AbortDownload(int index)
{
	/* Delete all downloaded temporary files. */
	char path[PLATFORM_MAX_PATH];
	ArrayList hFiles = Updater_GetFiles(index);

	for (int i = 0; i < hFiles.Length; i++)
	{
		hFiles.GetString(i, path, sizeof(path));
		Format(path, sizeof(path), "%s.%s", path, TEMP_FILE_EXT);

		if (FileExists(path))
		{
			DeleteFile(path);
		}
	}

	hFiles.Clear();
}

void ProcessDownloadQueue(bool force = false)
{
	if (!force && (g_bDownloading || !g_hDownloadQueue.Length))
	{
		return;
	}

	DataPack hQueuePack = g_hDownloadQueue.Get(0);
	hQueuePack.Position = QueuePack_URL;

	char url[MAX_URL_LENGTH];
	hQueuePack.ReadString(url, sizeof(url));

	char dest[PLATFORM_MAX_PATH];
	hQueuePack.ReadString(dest, sizeof(dest));

	if (!STEAMWORKS_AVAILABLE())
	{
		SetFailState(EXTENSION_ERROR);
	}

#if defined DEBUG
	Updater_DebugLog("Download started:");
	Updater_DebugLog("  [0]  URL: %s", url);
	Updater_DebugLog("  [1]  Destination: %s", dest);
#endif

	g_bDownloading = true;

	if (STEAMWORKS_AVAILABLE())
	{
		if (SteamWorks_IsLoaded())
		{
			Download_SteamWorks(url, dest);
		}
		else
		{
			CreateTimer(10.0, Timer_RetryQueue);
		}
	}
}

public Action Timer_RetryQueue(Handle timer)
{
	ProcessDownloadQueue(true);
	return Plugin_Stop;
}

void AddToDownloadQueue(int index, const char[] url, const char[] dest)
{
	DataPack hQueuePack = new DataPack();
	hQueuePack.WriteCell(index);

	QueuePack_URL = hQueuePack.Position;
	hQueuePack.WriteString(url);
	hQueuePack.WriteString(dest);

	g_hDownloadQueue.Push(hQueuePack);

	ProcessDownloadQueue();
}

void DownloadEnded(bool successful, const char[] error = "")
{
	DataPack hQueuePack = g_hDownloadQueue.Get(0);
	hQueuePack.Reset();

	int index = hQueuePack.ReadCell();

	char url[MAX_URL_LENGTH];
	hQueuePack.ReadString(url, sizeof(url));

	char dest[PLATFORM_MAX_PATH];
	hQueuePack.ReadString(dest, sizeof(dest));

	// Remove from the queue.
	delete hQueuePack;
	g_hDownloadQueue.Erase(0);

#if defined DEBUG
	Updater_DebugLog("  [2]  Successful: %s", successful ? "Yes" : "No");
#endif

	switch (Updater_GetStatus(index))
	{
		case Status_Checking:
		{
			if (!successful || !ParseUpdateFile(index, dest))
			{
				Updater_SetStatus(index, Status_Idle);

#if defined DEBUG
				if (error[0] != '\0')
				{
					Updater_DebugLog("  [2]  %s", error);
				}
#endif
			}
		}

		case Status_Downloading:
		{
			if (successful)
			{
				// Check if this was the last file we needed.
				char lastfile[PLATFORM_MAX_PATH];
				ArrayList hFiles = Updater_GetFiles(index);

				hFiles.GetString(hFiles.Length - 1, lastfile, sizeof(lastfile));
				Format(lastfile, sizeof(lastfile), "%s.%s", lastfile, TEMP_FILE_EXT);

				if (StrEqual(dest, lastfile))
				{
					Handle hPlugin = IndexToPlugin(index);

					Fwd_OnPluginUpdating(hPlugin);
					FinalizeDownload(index);

					char sName[64];
					if (!GetPluginInfo(hPlugin, PlInfo_Name, sName, sizeof(sName)))
					{
						strcopy(sName, sizeof(sName), "Null");
					}

					Updater_Log("Successfully updated and installed \"%s\".", sName);

					Updater_SetStatus(index, Status_Updated);
					Fwd_OnPluginUpdated(hPlugin);
				}
			}
			else
			{
				// Failed during an update.
				AbortDownload(index);
				Updater_SetStatus(index, Status_Error);

				char filename[64];
				GetPluginFilename(IndexToPlugin(index), filename, sizeof(filename));
				Updater_Log("Error downloading update for plugin: %s", filename);
				Updater_Log("  [0]  URL: %s", url);
				Updater_Log("  [1]  Destination: %s", dest);

				if (error[0] != '\0')
				{
					Updater_Log("  [2]  %s", error);
				}
			}
		}

		case Status_Error:
		{
			// Delete any additional files that this plugin had queued.
			if (successful && FileExists(dest))
			{
				DeleteFile(dest);
			}
		}
	}

	g_bDownloading = false;

	ProcessDownloadQueue();
}
