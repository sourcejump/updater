/* API - Natives & Forwards */

static PrivateForward fwd_OnPluginChecking;
static PrivateForward fwd_OnPluginDownloading;
static PrivateForward fwd_OnPluginUpdating;
static PrivateForward fwd_OnPluginUpdated;

void API_Init()
{
	CreateNative("Updater_AddPlugin", Native_AddPlugin);
	CreateNative("Updater_RemovePlugin", Native_RemovePlugin);
	CreateNative("Updater_ForceUpdate", Native_ForceUpdate);

	fwd_OnPluginChecking = new PrivateForward(ET_Event);
	fwd_OnPluginDownloading = new PrivateForward(ET_Event);
	fwd_OnPluginUpdating = new PrivateForward(ET_Ignore);
	fwd_OnPluginUpdated = new PrivateForward(ET_Ignore);
}

public any Native_AddPlugin(Handle plugin, int numParams)
{
	char url[MAX_URL_LENGTH];
	GetNativeString(1, url, sizeof(url));

	Updater_AddPlugin(plugin, url);
}

public any Native_RemovePlugin(Handle plugin, int numParams)
{
	int index = PluginToIndex(plugin);

	if (index != -1)
	{
		Updater_QueueRemovePlugin(plugin);
	}
}

public any Native_ForceUpdate(Handle plugin, int numParams)
{
	int index = PluginToIndex(plugin);

	if (index == -1)
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Plugin not found in updater.");
	}
	else if (Updater_GetStatus(index) == Status_Idle)
	{
		Updater_Check(index);
		return true;
	}

	return false;
}

Action Fwd_OnPluginChecking(Handle plugin)
{
	Action result = Plugin_Continue;
	Function func = GetFunctionByName(plugin, "Updater_OnPluginChecking");

	if (func != INVALID_FUNCTION && AddToForward(fwd_OnPluginChecking, plugin, func))
	{
		Call_StartForward(fwd_OnPluginChecking);
		Call_Finish(result);

		RemoveAllFromForward(fwd_OnPluginChecking, plugin);
	}

	return result;
}

Action Fwd_OnPluginDownloading(Handle plugin)
{
	Action result = Plugin_Continue;
	Function func = GetFunctionByName(plugin, "Updater_OnPluginDownloading");

	if (func != INVALID_FUNCTION && AddToForward(fwd_OnPluginDownloading, plugin, func))
	{
		Call_StartForward(fwd_OnPluginDownloading);
		Call_Finish(result);

		RemoveAllFromForward(fwd_OnPluginDownloading, plugin);
	}

	return result;
}

void Fwd_OnPluginUpdating(Handle plugin)
{
	Function func = GetFunctionByName(plugin, "Updater_OnPluginUpdating");

	if (func != INVALID_FUNCTION && AddToForward(fwd_OnPluginUpdating, plugin, func))
	{
		Call_StartForward(fwd_OnPluginUpdating);
		Call_Finish();

		RemoveAllFromForward(fwd_OnPluginUpdating, plugin);
	}
}

void Fwd_OnPluginUpdated(Handle plugin)
{
	Function func = GetFunctionByName(plugin, "Updater_OnPluginUpdated");

	if (func != INVALID_FUNCTION && AddToForward(fwd_OnPluginUpdated, plugin, func))
	{
		Call_StartForward(fwd_OnPluginUpdated);
		Call_Finish();

		RemoveAllFromForward(fwd_OnPluginUpdated, plugin);
	}
}
