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

// Each throw adds its own id to its targetnames, so several lasers can exist at the same time
int g_iLastLaserId = 0;
int g_iRepeatLaserId = -1;

public Plugin myinfo =
{
	name        = "Laser",
	author      = "maxime1907, .Rushaway",
	description = "Throws a laser in front of someone",
	version     = "1.3.3",
	url         = "https://steamcommunity.com/id/maxime1907"
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("Laser.phrases");
    RegAdminCmd("sm_throwlaser", Command_Laser, ADMFLAG_ROOT, "Sends a laser in front of you");
    RegAdminCmd("sm_throwlaser_kill", Command_LaserKill, ADMFLAG_ROOT, "Kills the active laser");
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
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
    KillAllLasers();
    CReplyToCommand(client, "{green}[Laser] {white}%t", "Laser Killed");
    return Plugin_Handled;
}

public Action Command_Laser(int client, int args)
{
    if(!IsValidClient(client, false)) return Plugin_Handled;

    // Remove previous lasers
    KillAllLasers();

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
        CPrintToChat(client, "{green}[Laser] {white}%t", "Laser Usage");
        CPrintToChat(client, "{green}[Laser] {white}%t", "Laser Modes 1");
        CPrintToChat(client, "{green}[Laser] {white}%t", "Laser Modes 2");
    }
    return Plugin_Handled;
}

// Targetname of one entity of a laser: "<base>_<id>", e.g. "_throwinglaser_maxime1907_track0_12"
void FormatLaserName(char[] buffer, int maxlength, const char[] base, int id)
{
    FormatEx(buffer, maxlength, "%s_%d", base, id);
}

void KillEntityByTargetName(const char[] base, int id)
{
    char name[64];
    FormatLaserName(name, sizeof(name), base, id);

    int entity = FindEntityByTargetName(name);
    if (entity != INVALID_ENT_REFERENCE)
        AcceptEntityInput(entity, "Kill");
}

// Kills the prop, the train and the path tracks of one laser
void KillLaser(int id)
{
    if (id < 0) return;

    KillEntityByTargetName(LASER, id);
    KillEntityByTargetName(LASER_TRACK_START, id);
    KillEntityByTargetName(LASER_TRACK_END, id);
    KillEntityByTargetName(LASER_TRAIN, id);
}

// Kills every laser: all their targetnames start with LASER
void KillAllLasers()
{
    char sTargetname[64];
    int prefixLength = strlen(LASER);
    int iEntity = INVALID_ENT_REFERENCE;
    while((iEntity = FindEntityByClassname(iEntity, "*")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
        if (strncmp(sTargetname, LASER, prefixLength, false) == 0)
            AcceptEntityInput(iEntity, "Kill");
    }
    g_iRepeatLaserId = -1;
}

// Returns the id of the thrown laser, or -1 if none was thrown
int ThrowLaser(int client, float distanceStart, float distanceEnd, float speed, LaserMode mode)
{
    if(!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE) return -1;

    int id = ++g_iLastLaserId;

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
        FormatEx(trackname, sizeof(trackname), "%s%i_%d", LASER_TRACK, i, id);
        int track = CreatePath(trackname, g_vecTracks[i], prevtrackname);
        strcopy(prevtrackname, sizeof(prevtrackname), trackname);

        // Kill the laser as soon as it reaches the last path_track (the OnFullyOpen of a func_movelinear)
        if (i == sizeof(g_vecTracks) - 1 && track > 0)
            HookSingleEntityOutput(track, "OnPass", Output_OnLaserPathEnd, true);
    }

    int velocity = RoundToZero(speed);

    char trainname[64];
    char trackstart[64];
    char lasername[64];
    FormatLaserName(trainname, sizeof(trainname), LASER_TRAIN, id);
    FormatLaserName(trackstart, sizeof(trackstart), LASER_TRACK_START, id);
    FormatLaserName(lasername, sizeof(lasername), LASER, id);

    // Create func_tracktrain
    int tracktrain = CreateTrackTrain(trainname, trackstart, velocity);

    int laser = CreateProp(lasername, LASER_ENABLE_DMG);

    if (laser < 0 || tracktrain < 0)
    {
        KillLaser(id);
        return -1;
    }

    // Parent it to func_tracktrain
    ParentToEntity(laser, tracktrain);

    EmitSoundToAll(PRECACHE_MOVE_SND, laser, SNDCHAN_AUTO, .volume=1.0);

    if (mode == LINEAR_RANDOM_REPEAT && !repeat)
    {
        repeat = true;
        g_iRepeatLaserId = id;
        g_RepeatLaserTimer = CreateTimer(LASER_REPEAT_TIMER, Timer_ThrowLaser, GetClientSerial(client), TIMER_REPEAT);
    }
    else if (mode != LINEAR_RANDOM_REPEAT)
    {
        repeat = false;
        CreateTimer(LASER_KILL_TIMER, Timer_KillLaser, id, TIMER_FLAG_NO_MAPCHANGE);
    }

    return id;
}

public Action Timer_ThrowLaser(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if (repeat && IsValidClient(client) && GetClientTeam(client) > CS_TEAM_NONE)
    {
        KillLaser(g_iRepeatLaserId);
        g_iRepeatLaserId = ThrowLaser(client, LASER_DISTANCE_START, LASER_DISTANCE_END, LASER_SPEED, LINEAR_RANDOM_REPEAT);
        return Plugin_Continue;
    }
    if (timer == g_RepeatLaserTimer)
        g_RepeatLaserTimer = null;
    return Plugin_Stop;
}

public Action Timer_KillLaser(Handle timer, int id)
{
    KillLaser(id);
    return Plugin_Stop;
}

public void Output_OnLaserPathEnd(const char[] output, int caller, int activator, float delay)
{
    // The last path_track is named "<LASER_TRACK_END>_<id>"
    char sTargetname[64];
    GetEntPropString(caller, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

    int separator = FindCharInString(sTargetname, '_', true);
    if (separator != -1)
        KillLaser(StringToInt(sTargetname[separator + 1]));
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

