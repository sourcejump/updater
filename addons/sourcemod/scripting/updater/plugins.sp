/* PluginPack Helpers */

static DataPackPos PluginPack_Plugin;
static DataPackPos PluginPack_Files;
static DataPackPos PluginPack_Status;
static DataPackPos PluginPack_URL;

int GetMaxPlugins()
{
	return g_hPluginPacks.Length;
}

bool IsValidPlugin(Handle plugin)
{
	/* Check if the plugin handle is pointing to a valid plugin. */
	Handle hIterator = GetPluginIterator();
	bool bIsValid = false;

	while (MorePlugins(hIterator))
	{
		if (plugin == ReadPlugin(hIterator))
		{
			bIsValid = true;
			break;
		}
	}

	delete hIterator;
	return bIsValid;
}

int PluginToIndex(Handle plugin)
{
	DataPack hPluginPack = new DataPack();

	for (int i = 0; i < GetMaxPlugins(); i++)
	{
		hPluginPack = g_hPluginPacks.Get(i);
		hPluginPack.Position = PluginPack_Plugin;

		if (plugin == hPluginPack.ReadCell())
		{
			return i;
		}
	}

	return -1;
}

Handle IndexToPlugin(int index)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_Plugin;
	return hPluginPack.ReadCell();
}

void Updater_AddPlugin(Handle plugin, const char[] url)
{
	int index = PluginToIndex(plugin);

	if (index != -1)
	{
		// Remove plugin from removal queue.
		for (int i = 0; i < g_hRemoveQueue.Length; i++)
		{
			if (plugin == g_hRemoveQueue.Get(i))
			{
				g_hRemoveQueue.Erase(i);
				break;
			}
		}

		// Update the url.
		Updater_SetURL(index, url);
	}
	else
	{
		DataPack hPluginPack = new DataPack();
		ArrayList hFiles = new ArrayList(PLATFORM_MAX_PATH);

		PluginPack_Plugin = hPluginPack.Position;
		hPluginPack.WriteCell(plugin);

		PluginPack_Files = hPluginPack.Position;
		hPluginPack.WriteCell(hFiles);

		PluginPack_Status = hPluginPack.Position;
		hPluginPack.WriteCell(Status_Idle);

		PluginPack_URL = hPluginPack.Position;
		hPluginPack.WriteString(url);

		g_hPluginPacks.Push(hPluginPack);
	}
}

void Updater_QueueRemovePlugin(Handle plugin)
{
	/* Flag a plugin for removal. */
	for (int i = 0; i < g_hRemoveQueue.Length; i++)
	{
		// Make sure it wasn't previously flagged.
		if (plugin == g_hRemoveQueue.Get(i))
		{
			return;
		}
	}

	g_hRemoveQueue.Push(plugin);
	Updater_FreeMemory();
}

void Updater_RemovePlugin(int index)
{
	/* Warning: Removing a plugin will shift indexes. */
	CloseHandle(Updater_GetFiles(index)); // hFiles
	CloseHandle(g_hPluginPacks.Get(index)); // hPluginPack
	g_hPluginPacks.Erase(index);
}

ArrayList Updater_GetFiles(int index)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_Files;
	return hPluginPack.ReadCell();
}

UpdateStatus Updater_GetStatus(int index)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_Status;
	return hPluginPack.ReadCell();
}

void Updater_SetStatus(int index, UpdateStatus status)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_Status;
	hPluginPack.WriteCell(status);
}

void Updater_GetURL(int index, char[] buffer, int maxlength)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_URL;
	hPluginPack.ReadString(buffer, maxlength);
}

void Updater_SetURL(int index, const char[] url)
{
	DataPack hPluginPack = g_hPluginPacks.Get(index);
	hPluginPack.Position = PluginPack_URL;
	hPluginPack.WriteString(url);
}
