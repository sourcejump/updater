#include <sourcemod>
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

/* Plugin Info */
#define PLUGIN_NAME "Updater"
#define PLUGIN_VERSION "1.2.2"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony",
	description = "Automatically updates SourceMod plugins and files",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=169095"
};

/* Globals */
//#define DEBUG // This will enable verbose logging. Useful for developers testing their updates.

#define TEMP_FILE_EXT "temp" // All files are downloaded with this extension first.
#define MAX_URL_LENGTH 256

#define UPDATE_URL "http://godtony.mooo.com/updater/updater.txt"

enum UpdateStatus {
	Status_Idle,
	Status_Checking,    // Checking for updates.
	Status_Downloading, // Downloading an update.
	Status_Updated,     // Update is complete.
	Status_Error,       // An error occured while downloading.
};

bool g_bGetDownload;
bool g_bGetSource;

ArrayList g_hPluginPacks;
ArrayList g_hDownloadQueue;
ArrayList g_hRemoveQueue;
bool g_bDownloading;

static Handle _hUpdateTimer;
static float _fLastUpdate = 0.0;
static char _sDataPath[PLATFORM_MAX_PATH];

/* Core Includes */
#include "updater/plugins.sp"
#include "updater/filesys.sp"
#include "updater/download.sp"
#include "updater/api.sp"

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	API_Init();
	RegPluginLibrary("updater");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	// Convars.
	ConVar hCvar;

	hCvar = CreateConVar("sm_updater_version", PLUGIN_VERSION, "Updater version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	hCvar.AddChangeHook(OnVersionChanged);

	hCvar = CreateConVar("sm_updater", "2", "Determines update functionality. (1 = Notify, 2 = Download, 3 = Include source code)", _, true, 1.0, true, 3.0);
	hCvar.AddChangeHook(OnSettingsChanged);

	// Commands.
	RegAdminCmd("sm_updater_check", Command_Check, ADMFLAG_RCON, "Forces Updater to check for updates.");
	RegAdminCmd("sm_updater_status", Command_Status, ADMFLAG_RCON, "View the status of Updater.");

	// Initialize arrays.
	g_hPluginPacks = new ArrayList();
	g_hDownloadQueue = new ArrayList();
	g_hRemoveQueue = new ArrayList();

	// Temp path for checking update files.
	BuildPath(Path_SM, _sDataPath, sizeof(_sDataPath), "data/updater.txt");

#if !defined DEBUG
	// Add this plugin to the autoupdater.
	Updater_AddPlugin(GetMyHandle(), UPDATE_URL);
#endif

	// Check for updates every 24 hours.
	_hUpdateTimer = CreateTimer(86400.0, Timer_CheckUpdates, _, TIMER_REPEAT);
}

public void OnAllPluginsLoaded()
{
	// Check for updates on startup.
	TriggerTimer(_hUpdateTimer, true);
}

public Action Timer_CheckUpdates(Handle timer)
{
	Updater_FreeMemory();

	// Update everything!
	for (int i = 0; i < GetMaxPlugins(); i++)
	{
		if (Updater_GetStatus(i) == Status_Idle)
		{
			Updater_Check(i);
		}
	}

	_fLastUpdate = GetTickedTime();

	return Plugin_Continue;
}

public Action Command_Check(int client, int args)
{
	float fNextUpdate = _fLastUpdate + 3600.0;

	if (fNextUpdate > GetTickedTime())
	{
		ReplyToCommand(client, "[Updater] Updates can only be checked once per hour. %.1f minutes remaining.", (fNextUpdate - GetTickedTime()) / 60.0);
	}
	else
	{
		ReplyToCommand(client, "[Updater] Checking for updates.");
		TriggerTimer(_hUpdateTimer, true);
	}

	return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
	char sFilename[64];
	Handle hPlugin;

	ReplyToCommand(client, "[Updater] -- Status Begin --");
	ReplyToCommand(client, "Plugins being monitored for updates:");

	for (int i = 0; i < GetMaxPlugins(); i++)
	{
		hPlugin = IndexToPlugin(i);

		if (IsValidPlugin(hPlugin))
		{
			GetPluginFilename(hPlugin, sFilename, sizeof(sFilename));
			ReplyToCommand(client, "  [%i]  %s", i, sFilename);
		}
	}

	ReplyToCommand(client, "Last update check was %.1f minutes ago.", (GetTickedTime() - _fLastUpdate) / 60.0);
	ReplyToCommand(client, "[Updater] --- Status End ---");

	return Plugin_Handled;
}

public void OnVersionChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(newValue, PLUGIN_VERSION))
	{
		convar.SetString(PLUGIN_VERSION);
	}
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	switch (convar.IntValue)
	{
		case 1: // Notify only.
		{
			g_bGetDownload = false;
			g_bGetSource = false;
		}

		case 2: // Download updates.
		{
			g_bGetDownload = true;
			g_bGetSource = false;
		}

		case 3: // Download with source code.
		{
			g_bGetDownload = true;
			g_bGetSource = true;
		}
	}
}

#if !defined DEBUG
public void Updater_OnPluginUpdated()
{
	Updater_Log("Reloading Updater plugin... updates will resume automatically.");

	// Reload this plugin.
	char filename[64];
	GetPluginFilename(INVALID_HANDLE, filename, sizeof(filename));
	ServerCommand("sm plugins reload %s", filename);
}
#endif

void Updater_Check(int index)
{
	if (Fwd_OnPluginChecking(IndexToPlugin(index)) == Plugin_Continue)
	{
		char url[MAX_URL_LENGTH];
		Updater_GetURL(index, url, sizeof(url));
		Updater_SetStatus(index, Status_Checking);
		AddToDownloadQueue(index, url, _sDataPath);
	}
}

void Updater_FreeMemory()
{
	// Make sure that no threads are active.
	if (g_bDownloading || g_hDownloadQueue.Length)
	{
		return;
	}

	// Remove all queued plugins.
	int index;
	for (int i = 0; i < g_hRemoveQueue.Length; i++)
	{
		index = PluginToIndex(GetArrayCell(g_hRemoveQueue, i));

		if (index != -1)
		{
			Updater_RemovePlugin(index);
		}
	}

	g_hRemoveQueue.Clear();

	// Remove plugins that have been unloaded.
	for (int i = 0; i < GetMaxPlugins(); i++)
	{
		if (!IsValidPlugin(IndexToPlugin(i)))
		{
			Updater_RemovePlugin(i);
			i--;
		}
	}
}

void Updater_Log(const char[] format, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/updater.log");

	LogToFileEx(path, "%s", buffer);
}

#if defined DEBUG
void Updater_DebugLog(const char[] format, any...)
{
	char buffer[256],
	VFormat(buffer, sizeof(buffer), format, 2);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/updater_debug.log");

	LogToFileEx(path, "%s", buffer);
}
#endif
