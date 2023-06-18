#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>

#define MAGIC_BRUSH_MODEL       "models/props/cs_office/vending_machine.mdl"
#define PROP_MODEL              "models/nide/laser/laser.mdl"
#define PRECACHE_MOVE_SND       "nide/laser.wav"
#define MOVE_SND                "sound/nide/laser.wav"

#define LASER                   "_throwinglaser_maxime1907"
#define LASER_TRACK             "_throwinglaser_maxime1907_track"
#define LASER_TRACK_START       "_throwinglaser_maxime1907_track0"
#define LASER_TRACK_END         "_throwinglaser_maxime1907_track1"
#define LASER_TRAIN             "_throwinglaser_maxime1907_train"

#define LASER_DISTANCE_START    250.0
#define LASER_DISTANCE_END      2000.0

#define LASER_SPEED             1000.0

#define LASER_HEIGHT            30

#define LASER_KILL_TIMER        2.5
#define LASER_REPEAT_TIMER      2.0

#define LASER_ENABLE_DMG        true
#define LASER_DAMAGE            999999.0

#define SF_NOUSERCONTROL        2
#define SF_PASSABLE             8

#pragma semicolon 1
#pragma newdecls required

enum LaserMode
{
    STOP = -1,
    AIM = 0,
    LINEAR = 1,
    LINEAR_RANDOM = 2,
    LINEAR_RANDOM_REPEAT = 3
};

bool repeat = false;
float laserDamage = LASER_DAMAGE;
Handle g_RepeatLaserTimer = null;

public Plugin myinfo =
{
	name        = "Laser",
	author      = "maxime1907, .Rushaway",
	description = "Throws a laser in front of someone",
	version     = "1.2",
	url         = "https://steamcommunity.com/id/maxime1907"
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegAdminCmd("sm_throwlaser", Command_Laser, ADMFLAG_ROOT, "Sends a laser in front of you");
    RegAdminCmd("sm_throwlaser_kill", Command_LaserKill, ADMFLAG_ROOT, "Kills the active laser");
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
}

public void OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    repeat = false;
}

public void OnMapStart()
{
    PrecacheModel(MAGIC_BRUSH_MODEL);
    PrecacheModel(PROP_MODEL);
    PrecacheSound(PRECACHE_MOVE_SND);

    AddFileToDownloadsTable(MOVE_SND);
    AddFileToDownloadsTable(PROP_MODEL);
    AddFileToDownloadsTable("models/nide/laser/laser.phy");
    AddFileToDownloadsTable("models/nide/laser/laser.vvd");
    AddFileToDownloadsTable("models/nide/laser/laser.sw.vtx");
    AddFileToDownloadsTable("models/nide/laser/laser.dx80.vtx");
    AddFileToDownloadsTable("models/nide/laser/laser.dx90.vtx");
    AddFileToDownloadsTable("materials/models/nide/laser/laser1.vmt");
    AddFileToDownloadsTable("materials/models/nide/laser/laser1.vtf");
    AddFileToDownloadsTable("materials/models/nide/laser/laser2.vmt");
    AddFileToDownloadsTable("materials/models/nide/laser/laser2.vtf");
    AddFileToDownloadsTable("materials/models/nide/laser/white.vmt");
    AddFileToDownloadsTable("materials/models/nide/laser/white.vtf");
}

public void OnMapEnd()
{
	g_RepeatLaserTimer = null;
}

public Action Command_LaserKill(int client, int args)
{
    delete g_RepeatLaserTimer;
    KillLaser(LASER, LASER_TRACK_START, LASER_TRACK_END, LASER_TRAIN);
    CPrintToChat(client, "{green}[Laser] {white}Active laser has been killed.");
    return Plugin_Handled;
}

public Action Command_Laser(int client, int args)
{
    if(!IsValidClient(client, false)) return Plugin_Handled;

    // Remove previous laser
    KillLaser(LASER, LASER_TRACK_START, LASER_TRACK_END, LASER_TRAIN);

    LaserMode mode = AIM;
    if (args >= 2)
    {
        char argTarget[255];
        char argMode[255];
        char argDmg[255];
        char sTargetName[MAX_TARGET_LENGTH];
        int iTargets[MAXPLAYERS];
        int iTargetCount;
        bool bIsML;

        GetCmdArg(1, argTarget, sizeof(argTarget));
        GetCmdArg(2, argMode, sizeof(argMode));

        if (args >= 3)
        {
            GetCmdArg(3, argDmg, sizeof(argDmg));
            laserDamage = float(StringToInt(argDmg));
        }

        mode = view_as<LaserMode>(StringToInt(argMode));
        if (mode == STOP)
            repeat = false;
        else
        {
            if((iTargetCount = ProcessTargetString(argTarget, client, iTargets, MAXPLAYERS, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
            {
                ReplyToTargetError(client, iTargetCount);
                return Plugin_Handled;
            }

            for(int i = 0; i < iTargetCount; i++)
            {
                ThrowLaser(iTargets[i], LASER_DISTANCE_START, LASER_DISTANCE_END, LASER_SPEED, mode);
            }
        }
    }
    else
    {
        CPrintToChat(client, "{green}[Laser] {white}Usage: sm_throwlaser <#userid|name> <0|1|2|3|-1> <damage>");
        CPrintToChat(client, "{green}[Laser] {white}0 = Aim {red}|{white} 1 = Linear {red}|{white} 2 = Linear random");
        CPrintToChat(client, "{green}[Laser] {white}3 = Linear random repeat {red}|{white} -1 = Stop repeating");
    }
    return Plugin_Handled;
}

void KillLaser(const char[] laserName, const char[] trackStart, const char[] trackEnd, const char[] trainName)
{
    int laser = FindEntityByTargetName(laserName);
    if (laser != INVALID_ENT_REFERENCE && AcceptEntityInput(laser, "Kill"))
    {
        laser = INVALID_ENT_REFERENCE;
    }
    int track0 = FindEntityByTargetName(trackStart);
    if (track0 != INVALID_ENT_REFERENCE && AcceptEntityInput(track0, "Kill"))
    {
        track0 = INVALID_ENT_REFERENCE;
    }
    int track1 = FindEntityByTargetName(trackEnd);
    if (track1 != INVALID_ENT_REFERENCE && AcceptEntityInput(track1, "Kill"))
    {
        track1 = INVALID_ENT_REFERENCE;
    }
    int train = FindEntityByTargetName(trainName);
    if (train != INVALID_ENT_REFERENCE && AcceptEntityInput(train, "Kill"))
    {
        train = INVALID_ENT_REFERENCE;
    }
}

void ThrowLaser(int client, float distanceStart, float distanceEnd, float speed, LaserMode mode)
{
    if(!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE) return;

    float vecEyeAngles[3];
    float vecEyeOrigin[3];
    float vecForward[3];

    float startPos[3];
    float endPos[3];

    GetClientEyeAngles(client, vecEyeAngles);
    GetClientEyePosition(client, vecEyeOrigin);

    // Get the forward vector of the eye direction
    GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
    // Add distance by scaling the forward vector
    ScaleVector(vecForward, distanceStart);
    // Add the two positions to get the final position
    AddVectors(vecEyeOrigin, vecForward, startPos); 

    GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(vecForward, distanceEnd);
    AddVectors(vecEyeOrigin, vecForward, endPos); 

    switch (mode)
    {
        case LINEAR:
        {
            startPos[2] = vecEyeOrigin[2];
            endPos[2] = vecEyeOrigin[2];
        }
        case LINEAR_RANDOM, LINEAR_RANDOM_REPEAT:
        {
            int height = 0;
            int random = GetRandomInt(0, 2);
            switch (random)
            {
                case 1:
                {
                    height = LASER_HEIGHT;
                }
                case 2:
                {
                    height = LASER_HEIGHT*2;
                }
            }
            float vecAbsOrigin[3];
            GetClientAbsOrigin(client, vecAbsOrigin);
            startPos[2] = vecAbsOrigin[2] + height;
            endPos[2] = vecAbsOrigin[2] + height;
        }
    }

    char trackname[255];
    char prevtrackname[255];

    float g_vecTracks[2][3];
    g_vecTracks[0] = startPos;
    g_vecTracks[1] = endPos;

    for (int i = sizeof(g_vecTracks) - 1; i >= 0; i--)
    {
        FormatEx(trackname, sizeof(trackname), "%s%i", LASER_TRACK, i);
        CreatePath(trackname, g_vecTracks[i], prevtrackname);
        strcopy(prevtrackname, sizeof(prevtrackname), trackname);
    }

    int velocity = RoundToZero(speed);

    // Create func_tracktrain
    int tracktrain = CreateTrackTrain(LASER_TRAIN, LASER_TRACK_START, velocity);

    int laser = CreateProp(LASER, LASER_ENABLE_DMG);

    if (laser < 0 || tracktrain < 0) return;

    // Parent it to func_tracktrain
    ParentToEntity(laser, tracktrain);

    EmitSoundToAll(PRECACHE_MOVE_SND, laser, SNDCHAN_AUTO, .volume=1.0);

    if (mode == LINEAR_RANDOM_REPEAT && !repeat)
    {
        repeat = true;
        g_RepeatLaserTimer = CreateTimer(LASER_REPEAT_TIMER, Timer_ThrowLaser, GetClientSerial(client), TIMER_REPEAT);
    }
    else if (mode != LINEAR_RANDOM_REPEAT)
    {
        repeat = false;
        CreateTimer(LASER_KILL_TIMER, Timer_KillLaser, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_ThrowLaser(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if(!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE) return Plugin_Stop;
    if (repeat)
    {
        KillLaser(LASER, LASER_TRACK_START, LASER_TRACK_END, LASER_TRAIN);
        ThrowLaser(client, LASER_DISTANCE_START, LASER_DISTANCE_END, LASER_SPEED, LINEAR_RANDOM_REPEAT);
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

public Action Timer_KillLaser(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if(!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE) return Plugin_Stop;
    if (!repeat)
    {
        KillLaser(LASER, LASER_TRACK_START, LASER_TRACK_END, LASER_TRAIN);
    }
    return Plugin_Stop;
}

stock int CreateProp(const char[] name, bool dieOnCollision)
{
    int ent = CreateEntityByName("prop_dynamic_override");

    if (ent < 1)
    {
        LogError( "Couldn't create prop_dynamic_override!" );
        return -1;
    }

    DispatchKeyValue(ent, "targetname", name);
    DispatchKeyValue(ent, "solid", "0");
    DispatchKeyValue(ent, "model", PROP_MODEL);
    DispatchKeyValue(ent, "disableshadows", "1");
    DispatchKeyValue(ent, "disablereceiveshadows", "1");
    DispatchSpawn(ent);

    if (dieOnCollision)
    {
        SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
        SetEntProp(ent, Prop_Data, "m_nSolidType", 2);
        SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);
        SDKHook(ent, SDKHook_StartTouch, Hook_PropHit);
    }

    return ent;
}

public Action Hook_PropHit(int originEntity, int targetEntity)
{
    if (IsValidClient(targetEntity) && IsPlayerAlive(targetEntity))
    {
        SDKHooks_TakeDamage(targetEntity, targetEntity, targetEntity, laserDamage);
    }
    return Plugin_Continue;
}

stock int CreateTrackTrain(const char[] name, const char[] firstpath, int speed)
{
    int ent = CreateEntityByName("func_tracktrain");

    if (ent < 1)
    {
        LogError("Couldn't create func_tracktrain!");
        return -1;
    }

    char spd[255];
    IntToString(speed, spd, sizeof(spd));

    char spawnflags[12];
    FormatEx(spawnflags, sizeof(spawnflags), "%i", SF_NOUSERCONTROL | SF_PASSABLE);
    
    DispatchKeyValue(ent, "targetname", name);
    DispatchKeyValue(ent, "target", firstpath);
    DispatchKeyValue(ent, "model", MAGIC_BRUSH_MODEL);
    DispatchKeyValue(ent, "startspeed", spd);
    DispatchKeyValue(ent, "speed", spd);
    
    //DispatchKeyValue( ent, "MoveSound", MOVE_SND );
    
    // Make turning smoother
    DispatchKeyValue(ent, "wheels", "256");
    DispatchKeyValue(ent, "bank", "20");
    
    DispatchKeyValue(ent, "orientationtype", "2"); // Linear blend, adds some smoothness
    
    DispatchKeyValue(ent, "spawnflags", spawnflags);
    DispatchSpawn(ent);
    
    // Brush model specific stuff
    SetEntProp(ent, Prop_Send, "m_fEffects", 32);
    
    return ent;
}

stock int CreatePath(const char[] name, const float pos[3], const char[] nexttarget)
{
    int ent = CreateEntityByName("path_track");

    if (ent < 1)
    {
        LogError("Couldn't create path_track!");
        return -1;
    }
    
    DispatchKeyValue(ent, "targetname", name);
    DispatchKeyValue(ent, "target", nexttarget);
    DispatchSpawn(ent);
    
    // path_tracks have to be activated to assign targets.
    ActivateEntity(ent);
    
    TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
    
    return ent;
}

stock bool ParentToEntity(int ent, int target)
{
    SetVariantEntity(target);
    return AcceptEntityInput(ent, "SetParent");
}

public int FindEntityByTargetName(const char[] sTargetnameToFind)
{
	int iEntity = INVALID_ENT_REFERENCE;
	while((iEntity = FindEntityByClassname(iEntity, "*")) != INVALID_ENT_REFERENCE)
	{
		char sTargetname[64];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

		if (strcmp(sTargetnameToFind, sTargetname, false) == 0)
		{
			return iEntity;
		}
	}
	return INVALID_ENT_REFERENCE;
}

stock bool IsValidClient(int client, bool isABotAValidClient = true)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (!isABotAValidClient && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client);
}
