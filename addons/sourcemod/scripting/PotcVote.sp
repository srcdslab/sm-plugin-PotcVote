#include <cstrike>
#include <multicolors>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name        = "PotcVoteSystem",
	author	    = "Neon, maxime1907, .Rushaway",
	description = "Vote system for Potc",
	version     = "1.3",
	url         = "https://steamcommunity.com/id/n3ontm"
}

#define NUMBEROFSTAGES 3

bool g_bVoteFinished = true;
bool g_bIsRevote = false;
bool bStartVoteNextRound = false;

ConVar g_cDelay;

static char g_sStageName[NUMBEROFSTAGES][512] = {"Classic", "Extreme", "Race Mode"};
int g_Winnerstage;

Handle g_VoteMenu = INVALID_HANDLE;
ArrayList g_StageList = null;
Handle g_CountdownTimer = null;

public void OnPluginStart()
{
	g_cDelay = CreateConVar("sm_potcvote_delay", "3.0", "Time in seconds before firing the vote", FCVAR_NOTIFY, true, 1.0, true, 10.0);

	RegServerCmd("sm_potcvote", Command_StartVote);
	RegServerCmd("sm_cancelcvote", Command_CancelVote);

	RegAdminCmd("sm_potcvote", Command_AdminStartVote, ADMFLAG_CONVARS, "sm_potcvote");

	HookEvent("round_start",  OnRoundStart);
	HookEvent("round_end", OnRoundEnd);

	AutoExecConfig(true);
}

public void OnMapStart()
{
	VerifyMap();

	PrecacheSound("#nide/Hoist The Colours - Potc.mp3", true);
	AddFileToDownloadsTable("sound/nide/Hoist The Colours - Potc.mp3");

	bStartVoteNextRound = false;
}

public void OnMapEnd()
{
	g_CountdownTimer = null;
	delete g_StageList;
}

void VerifyMap()
{
	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if (StrEqual(currentMap, "ze_potc_v4s_4fix"))
		return;
		
	char sFilename[256];
	GetPluginFilename(INVALID_HANDLE, sFilename, sizeof(sFilename));
	ServerCommand("sm plugins unload %s", sFilename);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	SDKHook(iEntity, SDKHook_SpawnPost, MyOnEntitySpawned);
}

public void MyOnEntitySpawned(int iEntity)
{
	if (g_bVoteFinished || !IsValidEntity(iEntity) || !IsValidEdict(iEntity))
		return;

	char sTargetname[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	char sClassname[128];
	GetEdictClassname(iEntity, sClassname, sizeof(sClassname));

	if ((strcmp(sTargetname, "ext_bombsound2") != 0) && (strcmp(sTargetname, "ext_nukesound") != 0) && (strcmp(sClassname, "ambient_generic") == 0))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("winner") == CS_TEAM_CT)
	{
		int iCurrentStage = GetCurrentStage();

		if (iCurrentStage > -1)
			Cmd_StartVote();
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (bStartVoteNextRound)
	{
		delete g_CountdownTimer;
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		bStartVoteNextRound = false;
	}

	if (!(g_bVoteFinished))
	{
		int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Difficulty_Counter", "math_counter");
		if (iCounter != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iCounter, "Kill");

		int iGameText = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Level_Text", "game_text");
		if (iGameText != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iGameText, "Kill");

		int iNewGameText;
		iNewGameText = CreateEntityByName("game_text");
		DispatchKeyValue(iNewGameText, "targetname", "intermission_game_text");
		DispatchKeyValue(iNewGameText, "channel", "4");
		DispatchKeyValue(iNewGameText, "spawnflags", "1");
		DispatchKeyValue(iNewGameText, "color", "225 179 102");
		DispatchKeyValue(iNewGameText, "color2", "255 255 0");
		DispatchKeyValue(iNewGameText, "fadein", "1");
		DispatchKeyValue(iNewGameText, "fadeout", "1");
		DispatchKeyValue(iNewGameText, "holdtime", "30");
		DispatchKeyValue(iNewGameText, "message", "“If you were waiting for the opportune moment, that was it.” -Jack Sparrow");
		DispatchKeyValue(iNewGameText, "x", "-1");
		DispatchKeyValue(iNewGameText, "y", ".01");
		DispatchKeyValue(iNewGameText, "OnUser1", "!self,Display,,0,-1");
		DispatchKeyValue(iNewGameText, "OnUser1", "!self,FireUser1,,5,-1");
		DispatchSpawn(iNewGameText);
		SetVariantString("!activator");
		AcceptEntityInput(iNewGameText, "FireUser1");

		int iMusic = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ext_nukesound", "ambient_generic");
		if (iMusic != INVALID_ENT_REFERENCE)
		{
			SetVariantString("message #nide/Hoist The Colours - Potc.mp3");
			AcceptEntityInput(iMusic, "AddOutput");
			AcceptEntityInput(iMusic, "PlaySound");
		}
	}
}

public void GenerateArray()
{
	int iBlockSize = ByteCountToCells(PLATFORM_MAX_PATH);

	delete g_StageList;
	g_StageList = new ArrayList(iBlockSize);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
		g_StageList.PushString(g_sStageName[i]);

	int iArraySize = GetArraySize(g_StageList);

	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		int iRandom = GetRandomInt(0, iArraySize - 1);
		char sTemp1[128];
		g_StageList.GetString(iRandom, sTemp1, sizeof(sTemp1));

		char sTemp2[128];
		g_StageList.GetString(i, sTemp2, sizeof(sTemp2));

		g_StageList.SetString(i, sTemp1);
		g_StageList.SetString(iRandom, sTemp2);
	}
}

public Action Command_AdminStartVote(int client, int argc)
{
	char name[64];

	if (client == 0)
		name = "The server";
	else if(!GetClientName(client, name, sizeof(name))) 
		Format(name, sizeof(name), "Disconnected (uid:%d)", client);

	if (client != 0)
	{
		CPrintToChatAll("{green}[SM] {cyan}%s {white}has initiated a potc vote round (In %d seconds)", name, g_cDelay.IntValue);
		TerminateRound();
	}
	else
		CPrintToChatAll("{green}[SM] {cyan}%s {white}has initiated a potc vote round (Next round)", name);

	Cmd_StartVote();

	return Plugin_Handled;
}

public Action Command_StartVote(int args)
{
	Cmd_StartVote();
	return Plugin_Handled;
}

public Action Command_CancelVote(int args)
{
	Cmd_CancelVote();
	return Plugin_Handled;
}

public void Cmd_StartVote()
{
	g_bVoteFinished = false;
	GenerateArray();
	bStartVoteNextRound = true;
}

public void Cmd_CancelVote()
{
	bStartVoteNextRound = false;
	CPrintToChatAll("{green}[PotcVote] {cyan}Zombies detected, aborting vote!");
}

public Action StartVote(Handle timer)
{
	static int iCountDown = 3;
	PrintCenterTextAll("[PotcVote] Starting Vote in %ds", iCountDown);

	if (iCountDown-- <= 0)
	{
		iCountDown = 3;
		g_CountdownTimer = null;
		InitiateVote();
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void InitiateVote()
{
	if(IsVoteInProgress())
	{
		CPrintToChatAll("{green}[PotcVote] {white}Another vote is currently in progress, retrying again in 5s.");
		delete g_CountdownTimer;
		g_CountdownTimer = CreateTimer(5.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	Handle menuStyle = GetMenuStyleHandle(view_as<MenuStyle>(0));

	g_VoteMenu = CreateMenuEx(menuStyle, Handler_PotcVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

	int iArraySize = g_StageList.Length;
	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		char sBuffer[128];
		g_StageList.GetString(i, sBuffer, sizeof(sBuffer));

		for (int j = 0; j <= (NUMBEROFSTAGES - 1); j++)
		{
			if (strcmp(sBuffer, g_sStageName[j]) == 0)
			{
				AddMenuItem(g_VoteMenu, sBuffer, sBuffer);
			}
		}
	}

	SetMenuOptionFlags(g_VoteMenu, MENUFLAG_BUTTON_NOVOTE);
	SetMenuTitle(g_VoteMenu, "What stage to play next?");
	SetVoteResultCallback(g_VoteMenu, Handler_SettingsVoteFinished);
	VoteMenuToAll(g_VoteMenu, 12);
}

public int Handler_PotcVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			if (param1 != -1)
			{
				g_bVoteFinished = true;
				TerminateRound();
			}
		}
	}
	return 0;
}

public int MenuHandler_NotifyPanel(Menu hMenu, MenuAction iAction, int iParam1, int iParam2)
{
	switch (iAction)
	{
		case MenuAction_Select, MenuAction_Cancel:
			delete hMenu;
	}

	return 0;
}

public void Handler_SettingsVoteFinished(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	int required_percent = 60;
	int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);

	if ((highest_votes < required_votes) && (!g_bIsRevote))
	{
		CPrintToChatAll("{green}[PotcVote] {white}A revote is needed!");
		char sFirst[128];
		char sSecond[128];
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sFirst, sizeof(sFirst));
		GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], sSecond, sizeof(sSecond));
		g_StageList.Clear();
		g_StageList.PushString(sFirst);
		g_StageList.PushString(sSecond);
		g_bIsRevote = true;

		delete g_CountdownTimer;
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		return;
	}

	// No revote needed, continue as normal.
	g_bIsRevote = false;
	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public void Handler_VoteFinishedGeneric(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	g_bVoteFinished = true;
	char sWinner[128];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sWinner, sizeof(sWinner));
	float fPercentage = float(item_info[0][VOTEINFO_ITEM_VOTES] * 100) / float(num_votes);

	CPrintToChatAll("{green}[PotcVote] {white}Vote Finished! Winner: {red}%s{white} with %d%% of %d votes!", sWinner, RoundToFloor(fPercentage), num_votes);CPrintToChatAll("{green}[PotcVote] {white}Mooving to {red}%s{white}.", sWinner);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
	{
		if (strcmp(sWinner, g_sStageName[i]) == 0)
			g_Winnerstage = i;
	}

	ServerCommand("sm_stage %d", (g_Winnerstage + 1));
	TerminateRound();

	delete menu;
}

public int GetCurrentStage()
{
	int iLevelCounterEnt = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Difficulty_Counter", "math_counter");

	int offset = FindDataMapInfo(iLevelCounterEnt, "m_OutValue");
	int iCounterVal = RoundFloat(GetEntDataFloat(iLevelCounterEnt, offset));

	int iCurrentStage;
	if (iCounterVal == 2)
		iCurrentStage = 1;
	else if (iCounterVal == 3)
		iCurrentStage = 2;
	else if (iCounterVal == 4)
		iCurrentStage = 3;
	else
		iCurrentStage = -1;

	return iCurrentStage;
}

public int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname)
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}
	return INVALID_ENT_REFERENCE;
}

void TerminateRound()
{
	CS_TerminateRound(g_cDelay.FloatValue, CSRoundEnd_Draw, false);

	// Fix the score - Round Draw give 1 point to CT Team
	int score = GetTeamScore(CS_TEAM_CT);
	if (score > 0) SetTeamScore(CS_TEAM_CT, (score - 1));
}
