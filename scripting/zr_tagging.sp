#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>

#define PLUGIN_AUTHOR "Agent Wesker"
#define PLUGIN_VERSION "1.0"

//#define DEBUG

//Bit Macros
#define SetBit(%1,%2)      (%1[%2>>5] |= (1<<(%2 & 31)))
#define ClearBit(%1,%2)    (%1[%2>>5] &= ~(1<<(%2 & 31)))
#define CheckBit(%1,%2)    (%1[%2>>5] & (1<<(%2 & 31)))

//Global Variables
ConVar g_ConVar_BurnCost;
ConVar g_ConVar_TagPenalty;
ConVar g_ConVar_TagDelay;
float g_fBurnCost;
float g_fTagPenalty;
float g_fTagDelay;
float g_fTagTime[MAXPLAYERS+1];
int g_iStamOffset = -1;
int g_iTagged[(64 >> 5) + 1];
int g_iJumping[(64 >> 5) + 1];
int g_iBurning[(64 >> 5) + 1];

public Plugin myinfo = 
{
	name = "ZR Tagging",
	author = PLUGIN_AUTHOR,
	description = "Replacement tagging to fix issues with built in system",
	version = PLUGIN_VERSION,
	url = "https://steam-gamers.net/"
};

public void OnPluginStart()
{

	g_iStamOffset = FindSendPropInfo("CCSPlayer", "m_flStamina");
	if (g_iStamOffset == -1)
	{	
		LogError("\"CCSPlayer::m_flStamina\" could not be found.");
		SetFailState("\"CCSPlayer::m_flStamina\" could not be found.");
	}
	
	g_ConVar_BurnCost = CreateConVar("sm_stamina_burncost", "40.0", "Stamina penalty applied when burned", 0, true, 0.0, true, 100.0);
	g_fBurnCost = GetConVarFloat(g_ConVar_BurnCost);
	HookConVarChange(g_ConVar_BurnCost, OnConVarChanged);
	
	g_ConVar_TagPenalty = CreateConVar("sm_tagging_penalty", "25.0", "Stamina penalty applied when shot", 0, true, 0.0, true, 100.0);
	g_fTagPenalty = GetConVarFloat(g_ConVar_TagPenalty);
	HookConVarChange(g_ConVar_TagPenalty, OnConVarChanged);
	
	g_ConVar_TagDelay = CreateConVar("sm_tagging_time", "1.5", "How long tagging lasts from being shot", 0, true, 0.0, true, 100.0);
	g_fTagDelay = GetConVarFloat(g_ConVar_TagDelay);
	HookConVarChange(g_ConVar_TagDelay, OnConVarChanged);
	
	HookEvent("player_spawned", OnPlayerSpawned);
	
	// Late load
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if (convar == g_ConVar_BurnCost) {
		g_fBurnCost = StringToFloat(newVal);
	} else if (convar == g_ConVar_TagPenalty) {
		g_fTagPenalty = StringToFloat(newVal);
	} else if (convar == g_ConVar_TagDelay) {
		g_fTagDelay = StringToFloat(newVal);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnPlayerSpawned(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_fTagTime[client] = 0.0;
	ClearBit(g_iTagged, client);
	ClearBit(g_iJumping, client);
	ClearBit(g_iBurning, client);
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, 
		const float damageForce[3], const float damagePosition[3], int damagecustom)
{

	//Fire penalty has priority over tagging
	if (damagetype & DMG_BURN)
	{
		char sWeapon[64];
		GetEntityClassname(inflictor, sWeapon, sizeof(sWeapon));
		
		//Ignited players only slow themselves
		if (StrEqual(sWeapon, "entityflame", false)) {
			int entOwner = GetEntPropEnt(attacker, Prop_Send, "m_hEntAttached");
			if (entOwner != victim)
				return;
		} else if (StrEqual(sWeapon, "inferno", false)) {
			//Burn damage should slow, but not molotovs
			if (!ZR_IsClientZombie(victim))
			{
				return;
			}
		}
		SetBit(g_iBurning, victim);
		SetEntDataFloat(victim, g_iStamOffset, g_fBurnCost, true);
		return;
	}
	
	//Tagging, but only for zombies
	if ((damagetype & DMG_BULLET) && ZR_IsClientZombie(victim) && !ZR_IsClientZombie(attacker))
	{
		SetBit(g_iTagged, victim);
		g_fTagTime[victim] = GetGameTime() + g_fTagDelay;
		//Don't overwrite burn slow
		if (!CheckBit(g_iBurning, victim))
		{
			SetEntDataFloat(victim, g_iStamOffset, g_fTagPenalty, true);
		}
		return;
	}
	
	return;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	//Client is not tagged
	if (!CheckBit(g_iTagged, client) && !CheckBit(g_iBurning, client))
	{
		return Plugin_Continue;
	}

	//Client is not valid
	if (!IsValidClient(client))
	{
		ClearBit(g_iTagged, client);
		ClearBit(g_iBurning, client);
		return Plugin_Continue;
	}
	
	if (CheckBit(g_iBurning, client))
	{
		if (GetEntPropEnt(client, Prop_Data, "m_hEffectEntity") == -1)
		{
			ClearBit(g_iBurning, client);
			if (!CheckBit(g_iTagged, client))
			{
				return Plugin_Continue;
			}
		}
	}
	
	//Don't call this more than once
	bool onGround = IsClientOnObject(client);
	
	//Not holding jump & on the ground
	if (!(buttons & IN_JUMP) && onGround)
	{
		ClearBit(g_iJumping, client);
		
	} else if (!CheckBit(g_iJumping, client) && (buttons & IN_JUMP) && onGround)
	{
		//No jump state, holding +jump, on the ground
		SetBit(g_iJumping, client);
		SetEntDataFloat(client, g_iStamOffset, 0.0, true);
		return Plugin_Continue;
	}
	
	//Still tagged
	if (g_fTagTime[client] > GetGameTime())
	{
		//Not burning
		if (!CheckBit(g_iBurning, client))
		{
			SetEntDataFloat(client, g_iStamOffset, g_fTagPenalty, true);
		}
		return Plugin_Continue;
	}
	
	//Tagging is over, clear the bit
	ClearBit(g_iTagged, client);
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	if ((client <= 0) || (client > MaxClients)) {
		return false;
	}
	if (!IsClientInGame(client)) {
		return false;
	}
	if (!IsPlayerAlive(client)) {
		return false;
	}
	return true;
}  

stock bool IsClientOnObject(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1 ? true : false;
}