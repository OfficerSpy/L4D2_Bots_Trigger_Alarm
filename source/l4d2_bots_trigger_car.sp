#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1

bool g_bIsHittingCar[MAXPLAYERS + 1];

DynamicHook g_DHookIsBot;

public Plugin myinfo = 
{
	name = "[L4D2] Bots Trigger Car",
	author = "Officer Spy",
	description = "Lets bots trigger car alarms.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	GameData hGamedata = new GameData("l4d2.botscartrigger");
	
	if (hGamedata == null)
		SetFailState("Could not find gamedata file: l4d2.botscartrigger");
	
	int offset = hGamedata.GetOffset("CBasePlayer::IsBot");
	
	if (offset == -1)
		SetFailState("Failed to retrieve offset for CBasePlayer::IsBot!");
	
	delete hGamedata;
	
	g_DHookIsBot = new DynamicHook(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "prop_car_alarm"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, CarProp_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, CarProp_OnTakeDamagePost);
		SDKHook(entity, SDKHook_TouchPost, CarProp_TouchPost);
	}
	else if (StrEqual(classname, "prop_car_glass")) //Follows same logic
	{
		SDKHook(entity, SDKHook_OnTakeDamage, CarProp_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, CarProp_OnTakeDamagePost);
	}
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		DHookEntity(g_DHookIsBot, true, client, _, DHookCallback_IsBot_Post);
}

public Action CarProp_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// if (GetEntProp(victim, Prop_Send, "m_bDisabled") == 1)
		// return Plugin_Continue;
	
	if (IsValidSurvivorBot(attacker))
		g_bIsHittingCar[attacker] = true;
	
	return Plugin_Continue;
}

public void CarProp_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	// if (GetEntProp(victim, Prop_Send, "m_bDisabled") == 1)
		// return;
	
	if (IsValidSurvivorBot(attacker))
		g_bIsHittingCar[attacker] = false;
}

public void CarProp_TouchPost(int entity, int other)
{
	// if (GetEntProp(entity, Prop_Send, "m_bDisabled") == 1)
		// return;
	
	//Detouring around Touch does not work here, so we trigger it manually
	if (IsValidSurvivorBot(other) && GetEntPropEnt(other, Prop_Send, "m_hGroundEntity") == entity)
		TriggerCarAlarm(entity, other);
}

public MRESReturn DHookCallback_IsBot_Post(int pThis, DHookReturn hReturn)
{
	if (g_bIsHittingCar[pThis])
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

bool IsValidSurvivorBot(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	if (GetClientTeam(client) != 2) //Survivor team only
		return false;
	
	return IsFakeClient(client);
}

void TriggerCarAlarm(int car, int client)
{
	g_bIsHittingCar[client] = true;
	AcceptEntityInput(car, "SurvivorStandingOnCar", client, client);
	g_bIsHittingCar[client] = false;
}

/* The relevant functions that trigger alarms are
CCarProp::AlarmTouch
CCarProp::InputSurvivorStandingOnCar
CCarGlassProp::OnTakeDamage
CCarProp::OnTakeDamage */