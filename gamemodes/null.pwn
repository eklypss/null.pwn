// Basic, clean & dynamic gamemode for SA-MP (WIP)
// August 2016

// Main include 
#include <a_samp>

// (Re)define MAX values
#undef MAX_VEHICLES
#define MAX_VEHICLES 100
#undef MAX_PLAYERS
#define MAX_PLAYERS 50
#define MAX_ENTRANCES 50
#define MAX_DELIVERYPOINTS 50

// Other includes
#include <a_mysql>
#include <sscanf2>
#include <streamer>
#include <YSI\y_commands>
#include <YSI\y_colours>
#include <YSI\y_timers>
#include <YSI\y_iterate>
#include <YSI\y_dialog>

// MySQL info & connection handle
#define MySQL_Host "localhost"
#define MySQL_User "root"
#define MySQL_Password ""
#define MySQL_Database "null"
new gMySQL;

// Server-sided money definitions
#define ResetMoneyBar ResetPlayerMoney
#define UpdateMoneyBar GivePlayerMoney

// Time definitions
#define MONEY_CHECK_INTERVAL 5000
#define JETPACK_CHECK_INTERVAL 10000
#define ANNOUNCE_DURATION 5000

// Skin and object ID definitions
#define SKIN_PILOT 61
#define SKIN_SAILOR 32
#define SKIN_TRUCKER 95
#define OBJECT_ENTRANCE 1559

// Game settings
#define LOCAL_CHAT_RANGE 50
#define START_MONEY 5000
#define CHEAT_FLAGS_LIMIT 3

// Color definitions (for different entities)
#define LABEL_COLOR -1

// Other definitions
#define INFINITE 0x7FFFFFFF



// Dialogs
new gVehicleDialog = -1;
new gPlaneDialog = -1;
new gHelicopterDialog = -1;
new gBoatDialog = -1;
new gBikeDialog = -1;
new gCarDialog = -1;
new gWeaponDialog = -1;
new gClassDialog = -1;

// Delivery point variables

enum e_DeliveryPointData
{
	ID,
	bool: IsValid = false,
	Float: DelPos[3],
	Name[64],
	Text3D: LabelHandle,	
	CheckpointHandle
}

new DeliveryPointData[MAX_DELIVERYPOINTS][e_DeliveryPointData];

// Enter-exit variables

enum e_EnterExitData
{
	ID,
	IsValid,
	Float: EnterPos[3],
	Float: ExitPos[3],
	Float: ExitAngle,
	EnterInterior,
	ExitInterior,
	EnterVirtualWorld,
	ExitVirtualWorld,
	PickupHandle
};

new EnterExitData[MAX_ENTRANCES][e_EnterExitData];

// Player data variables
enum e_PlayerData
{
	Score,
	Money,
	Kills,
	Deaths,
	Class,

	bool: InMission,
	bool: Alive,
	bool: Admin,
	bool: HasSpawned,

	MissionsCompleted,
	FishCaught,
	LastVehicle,

	EEStage,
	Float:EEPos[3],
	EEInt,
	EEVW,
	EELast,
	DPLast,

	FailedLogins,
	CheatFlags

};


new PlayerData[MAX_PLAYERS + 1][e_PlayerData];

// Player classes

enum
{
	PLAYER_CLASS_NONE = 0,
	PLAYER_CLASS_PILOT = 1,
	PLAYER_CLASS_SAILOR = 2,
	PLAYER_CLASS_TRUCKER = 3
};

// Start of main code

main() {}

public OnGameModeInit()
{
	printf("Starting..");

	// Connect to MySQL database
	gMySQL = mysql_connect(MySQL_Host, MySQL_User, MySQL_Database, MySQL_Password);
	if(mysql_errno() != 0) print("Could not connect to the MySQL database!");

	// Load entities
	LoadVehicles();
	LoadEnterExists();
	LoadDeliveryPoints();

	// Assign unique IDs to dialogs
	gVehicleDialog = Dialog_ObtainID();
	gPlaneDialog = Dialog_ObtainID();
	gHelicopterDialog = Dialog_ObtainID();
	gBoatDialog = Dialog_ObtainID();	
	gBikeDialog = Dialog_ObtainID();
	gCarDialog = Dialog_ObtainID();
	gWeaponDialog = Dialog_ObtainID();
	gClassDialog = Dialog_ObtainID();

	// Alternative commands / shortcuts
	Command_AddAltNamed("kill", "suicide");
	Command_AddAltNamed("car", "v");
	Command_AddAltNamed("car", "veh");
	Command_AddAltNamed("car", "vehicle");
	Command_AddAltNamed("car", "spawncar");
	Command_AddAltNamed("stats", "sts");
	Command_AddAltNamed("stats", "s");
	Command_AddAltNamed("info", "i");
	Command_AddAltNamed("givecash", "gc");
	Command_AddAltNamed("weapon", "givegun");
	Command_AddAltNamed("weapon", "gg");
	Command_AddAltNamed("weapon", "gun");
	Command_AddAltNamed("weapon", "w");
	Command_AddAltNamed("weapon", "wep");
	Command_AddAltNamed("weapon", "weap");
	Command_AddAltNamed("local", "l");
	return 1;
}

public OnGameModeExit()
{
	printf("Exiting..");

	// Close the MySQL connection
	mysql_close(gMySQL);
	return 1;
}

public OnPlayerConnect(playerid)
{
	new szName[24], szString[128];
	GetPlayerName(playerid, szName, sizeof(szName));
	format(szString, sizeof(szString), "%s (%d) "AZURE"has joined the server.", szName, playerid);
	SendClientMessageToAll(X11_HONEYDEW3, szString);
    SetPlayerColor(playerid, X11_AZURE);
	// Reset player variables, credits: Yashas
    memcpy(PlayerData[playerid], PlayerData[MAX_PLAYERS], 0, sizeof(PlayerData[])*4, sizeof(PlayerData[]));
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	new szName[24], szString[128];
	GetPlayerName(playerid, szName, sizeof(szName));
	format(szString, sizeof(szString), "%s (%d) "AZURE"has left the server.", szName, playerid);
	SendClientMessageToAll(X11_HONEYDEW3, szString);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	PlayerData[playerid][Alive] = true;
	if(!PlayerData[playerid][HasSpawned])
	{
		SetMoney(playerid, START_MONEY);
		PlayerData[playerid][HasSpawned] = true;
	}

	if(PlayerData[playerid][Class] == PLAYER_CLASS_NONE)
	{
		Dialog_Show(playerid, DIALOG_STYLE_LIST, "Class Selection", "Pilot\nSailor\nTrucker", "Select", "", gClassDialog);
	}
	else
	{
		switch(PlayerData[playerid][Class])
		{
			// Todo: set spawn points, show help
			case 1: SetPlayerSkin(playerid, SKIN_PILOT);
			case 2: SetPlayerSkin(playerid, SKIN_SAILOR);
			case 3: SetPlayerSkin(playerid, SKIN_TRUCKER);
		}
	}
}

public OnPlayerDeath(playerid, killerid, reason)
{
	SendDeathMessage(killerid, playerid, reason);
	PlayerData[playerid][Alive] = false;
	PlayerData[playerid][Deaths] ++;
	if(killerid != INVALID_PLAYER_ID)
	{
		PlayerData[killerid][Kills] ++;
	}
}

public OnRconLoginAttempt(ip[], password[], success)
{
	new szIP[16], szPlayer = INVALID_PLAYER_ID;
	foreach(Player, i)
	{
		GetPlayerIp(i, szIP, sizeof(szIP));
		if(!strcmp(szIP, ip))
		{
			szPlayer = i;
			break;
		}
	}

	if(szPlayer != INVALID_PLAYER_ID)
	{
		new szName[24];
		GetPlayerName(szPlayer, szName, sizeof(szName));
		if(success)
		{
			PlayerData[szPlayer][Admin] = true;
			SendClientMessage(szPlayer, X11_HONEYDEW3, "Logged in as an admin.");
			printf("Player %s (ID: %d) (IP: %s) successfully logged into RCON.", szName, szPlayer, szIP);
		}
		else
		{
			PlayerData[szPlayer][FailedLogins] ++;
			printf("Player %s (ID: %d) (IP: %s) failed to log into RCON, failed attempts: %d.", szName, szPlayer, szIP, PlayerData[szPlayer][FailedLogins]);
			if(PlayerData[szPlayer][FailedLogins] >= 3)
			{
				Kick(szPlayer);
				printf("Kicking player %s (ID: %d) (IP: %s) for excessive failed logins.", szName, szPlayer, szIP);
			}
		}
	} else printf("Something went wrong with OnRconLoginAttempt."); // TODO: Handle the error
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(dialogid == gVehicleDialog)
	{
		if(response)
		{
			switch(listitem)
			{
				case 0: Dialog_Show(playerid, DIALOG_STYLE_LIST, "Airplanes", "Skimmer\nRustler\nBeagle\nCropduster\nStuntplane\nShamal\nHydra\nNevada\nAT-400\nAndromada\nDodo", "Select", "Back", gPlaneDialog);
				case 1: Dialog_Show(playerid, DIALOG_STYLE_LIST, "Helicopters", "Leviathan\nHunter\nSeasparrow\nSparrow\nMaverick\nNews Maverick\nPolice Maverick\nCargobob\nRaindance", "Select", "Back", gHelicopterDialog);				
				case 2: Dialog_Show(playerid, DIALOG_STYLE_LIST, "Boats", "Predator\nSquallo\nSpeeder\nReefer\nTropic\nCoastguard\nDinghy\nMarquis\nJetmax\nLaunch", "Select", "Back", gBoatDialog);
				case 3: Dialog_Show(playerid, DIALOG_STYLE_LIST, "Bikes", "Pizzaboy\nPCJ-600\nFaggio\nFreeway\nSanchez\nQuad\nBMX\nBike\nMountain Bike\nFCR-900\nNRG-500\nHPV-1000\nBF-400\nWayfarer", "Select", "Back", gBikeDialog);
				case 4: Dialog_Show(playerid, DIALOG_STYLE_LIST, "Cars", "todo", "Select", "Back", gCarDialog);
			}
		}
	}
	else if(dialogid == gPlaneDialog)
	{
		if(response)
		{
			if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to spawn vehicles.");
			new Float: szPosition[3], szModelID, szVehicle;
			GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
			switch(listitem)
			{
				case 0: szModelID = 460;
				case 1: szModelID = 476;
				case 2: szModelID = 511;
				case 3: szModelID = 512;
				case 4: szModelID = 513;
				case 5: szModelID = 519;
				case 6: szModelID = 520;
				case 7: szModelID = 553;
				case 8: szModelID = 577;
				case 9: szModelID = 592;
				case 10: szModelID = 593;
			}
			szVehicle = CreateVehicle(szModelID, szPosition[0], szPosition[1], szPosition[2], 0, 0, 0, 0);
			PutPlayerInVehicle(playerid, szVehicle, 0);
		} else return Dialog_Show(playerid, DIALOG_STYLE_LIST, "Vehicle Selection", ""AZURE"Planes\n"AZURE"Helicopters\n"DEEPSKYBLUE3"Boats\n"YELLOW2"Bikes\n"YELLOW2"Cars", "Select", "Cancel", gVehicleDialog);
	}
	else if(dialogid == gHelicopterDialog)
	{
		if(response)
		{
			if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to spawn vehicles.");			
			new Float: szPosition[3], szModelID, szVehicle;
			GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
			switch(listitem)
			{
				case 0: szModelID = 417;
				case 1: szModelID = 425;
				case 2: szModelID = 447;
				case 3: szModelID = 469;
				case 4: szModelID = 487;
				case 5: szModelID = 488;
				case 6: szModelID = 497;
				case 7: szModelID = 548;
				case 8: szModelID = 563;
			}
			szVehicle = CreateVehicle(szModelID, szPosition[0], szPosition[1], szPosition[2], 0, 0, 0, 0);
			PutPlayerInVehicle(playerid, szVehicle, 0);
		} else return Dialog_Show(playerid, DIALOG_STYLE_LIST, "Vehicle Selection", ""AZURE"Planes\n"AZURE"Helicopters\n"DEEPSKYBLUE3"Boats\n"YELLOW2"Bikes\n"YELLOW2"Cars", "Select", "Cancel", gVehicleDialog);
	}
	else if(dialogid == gBoatDialog)
	{
		if(response)
		{
			if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to spawn vehicles.");			
			new Float: szPosition[3], szModelID, szVehicle;
			GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
			switch(listitem)
			{
				case 0: szModelID = 430;
				case 1: szModelID = 446;
				case 2: szModelID = 452;
				case 3: szModelID = 453;
				case 4: szModelID = 454;
				case 5: szModelID = 472;
				case 6: szModelID = 473;
				case 7: szModelID = 484;
				case 8: szModelID = 493;
				case 9: szModelID = 595;
			}
			szVehicle = CreateVehicle(szModelID, szPosition[0], szPosition[1], szPosition[2], 0, 0, 0, 0);
			PutPlayerInVehicle(playerid, szVehicle, 0);
		} else return Dialog_Show(playerid, DIALOG_STYLE_LIST, "Vehicle Selection", ""AZURE"Planes\n"AZURE"Helicopters\n"DEEPSKYBLUE3"Boats\n"YELLOW2"Bikes\n"YELLOW2"Cars", "Select", "Cancel", gVehicleDialog);
	}
	else if(dialogid == gBikeDialog)
	{
		if(response)
		{
			if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to spawn vehicles.");			
			new Float: szPosition[3], szModelID, szVehicle;
			GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
			switch(listitem)
			{
				case 0: szModelID = 448;
				case 1: szModelID = 461;
				case 2: szModelID = 462;
				case 3: szModelID = 463;
				case 4: szModelID = 468;
				case 5: szModelID = 471;
				case 6: szModelID = 481;
				case 7: szModelID = 509;
				case 8: szModelID = 510;
				case 9: szModelID = 521;
				case 10: szModelID = 522;
				case 11: szModelID = 523;
				case 12: szModelID = 581;
				case 13: szModelID = 586;
			}
			szVehicle = CreateVehicle(szModelID, szPosition[0], szPosition[1], szPosition[2], 0, 0, 0, 0);
			PutPlayerInVehicle(playerid, szVehicle, 0);
		} else return Dialog_Show(playerid, DIALOG_STYLE_LIST, "Vehicle Selection", ""AZURE"Planes\n"AZURE"Helicopters\n"DEEPSKYBLUE3"Boats\n"YELLOW2"Bikes\n"YELLOW2"Cars", "Select", "Cancel", gVehicleDialog);
	}
	else if(dialogid == gWeaponDialog)
	{
		if(response)
		{
			if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to spawn weapons.");		
			switch(listitem)
			{
				case 0: ResetPlayerWeapons(playerid);
				case 1: GivePlayerWeapon(playerid, WEAPON_GRENADE, INFINITE);
				case 2: GivePlayerWeapon(playerid, WEAPON_TEARGAS, INFINITE);
				case 3: GivePlayerWeapon(playerid, WEAPON_MOLTOV, INFINITE);
				case 4: GivePlayerWeapon(playerid, WEAPON_COLT45, INFINITE);
				case 5: GivePlayerWeapon(playerid, WEAPON_SILENCED, INFINITE);
				case 6: GivePlayerWeapon(playerid, WEAPON_DEAGLE, INFINITE);
				case 7: GivePlayerWeapon(playerid, WEAPON_SHOTGUN, INFINITE);
				case 8: GivePlayerWeapon(playerid, WEAPON_SAWEDOFF, INFINITE);
				case 9: GivePlayerWeapon(playerid, WEAPON_SHOTGSPA, INFINITE);
				case 10: GivePlayerWeapon(playerid, WEAPON_UZI, INFINITE);
				case 11: GivePlayerWeapon(playerid, WEAPON_MP5, INFINITE);
				case 12: GivePlayerWeapon(playerid, WEAPON_AK47, INFINITE);
				case 13: GivePlayerWeapon(playerid, WEAPON_M4, INFINITE);
				case 14: GivePlayerWeapon(playerid, WEAPON_TEC9, INFINITE);
				case 15: GivePlayerWeapon(playerid, WEAPON_RIFLE, INFINITE);
				case 16: GivePlayerWeapon(playerid, WEAPON_SNIPER, INFINITE);
				case 17: GivePlayerWeapon(playerid, WEAPON_ROCKETLAUNCHER, INFINITE);
				case 18: GivePlayerWeapon(playerid, WEAPON_HEATSEEKER, INFINITE);
				case 19: GivePlayerWeapon(playerid, WEAPON_FLAMETHROWER, INFINITE);				
				case 20: GivePlayerWeapon(playerid, WEAPON_MINIGUN, INFINITE);
				case 21: GivePlayerWeapon(playerid, WEAPON_SPRAYCAN, INFINITE);
				case 22: GivePlayerWeapon(playerid, WEAPON_FIREEXTINGUISHER, INFINITE);
				case 23: GivePlayerWeapon(playerid, WEAPON_PARACHUTE, INFINITE);
			}	
		}
	}
	else if(dialogid == gClassDialog)
	{
		if(response)
		{
			switch(listitem)
			{
				case 0: 
				{
					SetPlayerColor(playerid, X11_SNOW2);
					SendClientMessage(playerid, X11_AZURE, "Class selected: "HONEYDEW3"Pilot");
					SetPlayerSkin(playerid, SKIN_PILOT);
					PlayerData[playerid][Class] = PLAYER_CLASS_PILOT;
				}
				case 1: 
				{
					SetPlayerColor(playerid, X11_STEELBLUE2);
					SendClientMessage(playerid, X11_AZURE, "Class selected: "HONEYDEW3"Sailor");
					SetPlayerSkin(playerid, SKIN_SAILOR);
					PlayerData[playerid][Class] = PLAYER_CLASS_SAILOR;
				}
				case 2: 
				{
					SetPlayerColor(playerid, X11_PERU);
					SendClientMessage(playerid, X11_AZURE, "Class selected: "HONEYDEW3"Trucker");
					SetPlayerSkin(playerid, SKIN_TRUCKER);
					PlayerData[playerid][Class] = PLAYER_CLASS_TRUCKER;
				}
			}
			SendClientMessage(playerid, X11_AZURE, "You can use "HONEYDEW3"/cc "AZURE"to use the class specific chat or "HONEYDEW3"/changeclass "AZURE"to change your class.");			
		}
		else
		{
			Dialog_Show(playerid, DIALOG_STYLE_LIST, "Class Selection", "Pilot\nSailor\nTrucker", "Select", "", gClassDialog);
			SendClientMessage(playerid, X11_FIREBRICK1, "You must select a class before you can play.");
		}
	}
	return 1;
}

public OnPlayerCommandPerformed(playerid, cmdtext[], success)
{
	if(!success) return SendClientMessage(playerid, X11_FIREBRICK1, "Unknown command.");
	else return 1;
}

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
	if(!IsAdmin(playerid))
	{
		new szString[128], szName[24], szWeaponName[24];
		GetPlayerName(playerid, szName, sizeof(szName));
		GetWeaponName(weaponid, szWeaponName, sizeof(szWeaponName));
		format(szString, sizeof(szString), "%s (%d) "AZURE"shot a weapon: "HONEYDEW3"%s", szName, playerid, szWeaponName);
		SendAdminMessage(szString);
		ResetPlayerWeapons(playerid);
		PlayerData[playerid][CheatFlags] ++;
		if(PlayerData[playerid][CheatFlags] >= CHEAT_FLAGS_LIMIT)
		{
			printf("%s (%d) reached the max cheat flags limit, kicking..", szName, playerid);
			Kick(playerid);
		}
	}
}

public OnPlayerPickUpDynamicPickup(playerid, pickupid)
{
	for(new i = 0; i < MAX_ENTRANCES; i++)
	{
		if(pickupid == EnterExitData[i][PickupHandle])
		{
			SetPlayerVirtualWorld(playerid, EnterExitData[i][ExitVirtualWorld]);
			SetPlayerInterior(playerid, EnterExitData[i][ExitInterior]);
			SetPlayerPos(playerid, EnterExitData[i][ExitPos][0], EnterExitData[i][ExitPos][1], EnterExitData[i][ExitPos][2]);
			SetPlayerFacingAngle(playerid, EnterExitData[i][ExitAngle]);
			SetCameraBehindPlayer(playerid);
		}
	}
	return 1;
}

public OnPlayerEnterDynamicCP(playerid, checkpointid)
{
	for(new i = 0; i < MAX_DELIVERYPOINTS; i++)
	{
		if(checkpointid == DeliveryPointData[i][CheckpointHandle])
		{
			new szString[128];
			format(szString, sizeof(szString), "Delivery point: "HONEYDEW3"%s "AZURE"(ID %d)", DeliveryPointData[i][Name], i);
			SendClientMessage(playerid, X11_AZURE, szString);
		}
	}	
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(oldstate == PLAYER_STATE_ONFOOT && newstate == PLAYER_STATE_DRIVER)
	{
		if(!PlayerData[playerid][InMission])
		{
			if(PlayerData[playerid][Class] == PLAYER_CLASS_TRUCKER)
			{
				new szVehicleID = GetVehicleModel(GetPlayerVehicleID(playerid));

				switch(szVehicleID)
				{
					case 408, 414, 433, 455, 456, 498, 499, 524, 573, 578:
					{
						SendClientMessage(playerid, X11_AZURE, "You can use "HONEYDEW3"/mission "AZURE"to start a truck delivery mission.");
					}
					default:
					{
						print("not ok");
					}
				}
			}
		}
		else
		{
			if(PlayerData[playerid][LastVehicle] == GetPlayerVehicleID(playerid))
			{
				// Continue the mission
			}
			else
			{
				// Cancel the mission
			}
		}
	}
	return 1;
}


public OnPlayerTakeDamage(playerid, issuerid, Float: amount, weaponid, bodypart)
{
    if(issuerid != INVALID_PLAYER_ID)
    {
        new
            szString[128],
            szWeaponName[24],
            szTargetName[MAX_PLAYER_NAME],
            szPlayerName[MAX_PLAYER_NAME];
 
        GetPlayerName(playerid, szPlayerName, sizeof(szPlayerName));
        GetPlayerName(issuerid, szTargetName, sizeof(szTargetName));
 
        GetWeaponName(weaponid, szWeaponName, sizeof(szWeaponName));
 
        format(szString, sizeof(szString), "%s has made %.0f damage to %s, weapon: %s", szTargetName, amount, szPlayerName, szWeaponName);
        SendClientMessageToAll(-1, szString);
    }
    return 1;
}

// Custom functions

IsAdmin(playerid)
{
	if(IsPlayerAdmin(playerid) || PlayerData[playerid][Admin]) return true;
	else return false;
}

IsAlive(playerid)
{
	return PlayerData[playerid][Alive];
}

GiveMoney(playerid, amount)
{
	PlayerData[playerid][Money] += amount;
	SetMoneyBar(playerid, PlayerData[playerid][Money]);
}

SetMoney(playerid, amount)
{
	PlayerData[playerid][Money] = amount;
	SetMoneyBar(playerid, amount);
}

ResetMoney(playerid)
{
	PlayerData[playerid][Money] = 0;
	SetMoneyBar(playerid, 0);
}

GetMoney(playerid)
{
	return PlayerData[playerid][Money];
}

SetMoneyBar(playerid, amount)
{
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, amount);
}

SendAdminMessage(string[])
{
	new szString[128];
	format(szString, sizeof(szString), "(Admin) "HONEYDEW3"%s", string);
	foreach(Player, i)
	{
		if(IsAdmin(i))
		{
			SendClientMessage(i, X11_FIREBRICK1, szString);
		}
	}
}

LoadVehicles()
{
	mysql_tquery(gMySQL, "SELECT * From `vehicles`", "OnVehicleLoad");
}

LoadEnterExists()
{
	mysql_tquery(gMySQL, "SELECT * From `entrances`", "OnEnterExitLoad");
}

LoadDeliveryPoints()
{
	mysql_tquery(gMySQL, "SELECT * From `deliverypoints`", "OnDeliveryPointLoad");
}

CreateEnterExit(Float: eX, Float: eY, Float: eZ, Float: iX, Float: iY, Float: iZ, Float: iAngle, eInt, iInt, eVW, iVW)
{
	for(new i = 0; i < MAX_ENTRANCES; i++)
	{
		if(EnterExitData[i][IsValid] == 1) continue;
		EnterExitData[i][ID] = i;
		EnterExitData[i][PickupHandle] = CreateDynamicPickup(OBJECT_ENTRANCE, 1, eX, eY, eZ, eVW, eInt);
		EnterExitData[i][EnterInterior] = eInt;
		EnterExitData[i][EnterVirtualWorld] = eVW;
		EnterExitData[i][ExitInterior] = iInt;
		EnterExitData[i][ExitVirtualWorld] = iVW;
		EnterExitData[i][EnterPos][0] = eX;
		EnterExitData[i][EnterPos][1] = eY;
		EnterExitData[i][EnterPos][2] = eZ;
		EnterExitData[i][ExitPos][0] = iX;
		EnterExitData[i][ExitPos][1] = iY;
		EnterExitData[i][ExitPos][2] = iZ;
		EnterExitData[i][ExitAngle] = iAngle;
		EnterExitData[i][IsValid] = 1;		
		printf("Enter-exit ID %d created, entrance pos: %f %f %f | exit pos: %f %f %f angle: %f | interiors: %d %d | vws: %d %d", i, eX, eY, eZ, iX, iY, iZ, iAngle, eInt, iInt, eVW, iVW);
		return i;
	}
	return -1;
}

CreateDeliveryPoint(Float: dX, Float: dY, Float: dZ, dName[64])
{
	for(new d = 0; d < MAX_DELIVERYPOINTS; d++)
	{
		if(DeliveryPointData[d][IsValid]) continue;
		DeliveryPointData[d][ID] = d;
		DeliveryPointData[d][Name] = dName;
		DeliveryPointData[d][DelPos][0] = dX;
		DeliveryPointData[d][DelPos][1] = dY;
		DeliveryPointData[d][DelPos][2] = dZ;
		DeliveryPointData[d][IsValid] = true;
		DeliveryPointData[d][LabelHandle] = CreateDynamic3DTextLabel("", LABEL_COLOR, dX, dY, dZ, 50.0);  
		DeliveryPointData[d][CheckpointHandle] = CreateDynamicCP(dX, dY, dZ, 2.0);
		foreach(Player, i)
		{
			TogglePlayerDynamicCP(i, DeliveryPointData[d][CheckpointHandle], false);
		}
		printf("Delivery point ID '%s' (ID: %d) created, position: %f %f %f", dName, d, dX, dY, dZ);
		return d;
	}
	return -1;
}

EnterExitExists(id)
{
	if(EnterExitData[id][IsValid] == 1) return true;
	else return false; 
}

DeliveryPointExists(id)
{
	if(DeliveryPointData[id][IsValid]) return true;
	else return false;
}


// MySQL callbacks

forward OnVehicleLoad();
public OnVehicleLoad()
{
	new szRows, szFields, szCount = 0;
	cache_get_data(szRows, szFields, gMySQL);
	if(szRows)
	{
		for(new i = 0; i < cache_num_rows(); i++)
		{
			CreateVehicle(cache_get_field_content_int(i, "Model"), cache_get_field_content_float(i, "X"), cache_get_field_content_float(i, "Y"), cache_get_field_content_float(i, "Z"), cache_get_field_content_float(i, "Angle"), cache_get_field_content_int(i, "Color1"), cache_get_field_content_int(i, "Color2"), 60);
			szCount ++;
		}
		printf("Loaded %d vehicles from the MySQL database.", szCount);
	} else print("No vehicles to load in the MySQL database!");
	return true;
}

forward OnEnterExitLoad();
public OnEnterExitLoad()
{
	new szRows, szFields, szCount = 0;
	cache_get_data(szRows, szFields, gMySQL);
	if(szRows)
	{
		for(new i = 0; i < cache_num_rows(); i++)
		{
			CreateEnterExit(cache_get_field_content_float(i, "EnterX"), cache_get_field_content_float(i, "EnterY"), cache_get_field_content_float(i, "EnterZ"), cache_get_field_content_float(i, "ExitX"), cache_get_field_content_float(i, "ExitY"), cache_get_field_content_float(i, "ExitZ"), 
				cache_get_field_content_float(i, "ExitAngle"), cache_get_field_content_int(i, "EnterInterior"), cache_get_field_content_int(i, "ExitInterior"), cache_get_field_content_int(i, "EnterVirtualWorld"), cache_get_field_content_int(i, "ExitVirtualWorld"));
			szCount ++;
		}
		printf("Loaded %d enter-exists from the MySQL database.", szCount);
	} else print("No enter-exists to load in the MySQL database!");
	return true;
}

forward OnDeliveryPointLoad();
public OnDeliveryPointLoad()
{
	new szRows, szFields, szCount = 0;
	cache_get_data(szRows, szFields, gMySQL);
	if(szRows)
	{
		new szString[64];
		for(new i = 0; i < cache_num_rows(); i++)
		{
			cache_get_field_content(i, "Name", szString);
			CreateDeliveryPoint(cache_get_field_content_float(i, "X"), cache_get_field_content_float(i, "Y"), cache_get_field_content_float(i, "Z"), szString);
			szCount ++;
		}
		printf("Loaded %d delivery points from the MySQL database.", szCount);
	} else print("No delivery points to load in the MySQL database!");
	return true;
}



forward OnVehicleSaved(playerid);
public OnVehicleSaved(playerid)
{
	printf("A new vehicle was added to the database.");
	SendClientMessage(playerid, X11_AZURE, "Vehicle successfully saved.");
	return 1;
}

forward OnEnterExitSaved(playerid);
public OnEnterExitSaved(playerid)
{
	printf("A new enter-exit was added to the database.");
	SendClientMessage(playerid, X11_AZURE, "Enter-exit successfully saved.");
	return 1;
}


forward OnDeliveryPointSaved(playerid);
public OnDeliveryPointSaved(playerid)
{
	printf("A new delivery point was added to the database.");
	SendClientMessage(playerid, X11_AZURE, "Delivery point successfully saved.");
	return 1;
}

// Tasks

task MoneyCheck[MONEY_CHECK_INTERVAL]()
{
	foreach(Player, i)
	{
		if(GetPlayerMoney(i) != GetMoney(i))
		{
			new szString[128], szName[24];
			GetPlayerName(i, szName, sizeof(szName));
			format(szString, sizeof(szString), "%s (%d) "AZURE"Money: "HONEYDEW3"$%d"AZURE", should be: "HONEYDEW3"$%d"AZURE", total flags: %d"HONEYDEW3"", szName, i, GetPlayerMoney(i), GetMoney(i));
			SendAdminMessage(szString);
			ResetMoney(i);

			PlayerData[i][CheatFlags] ++;
			if(PlayerData[i][CheatFlags] >= CHEAT_FLAGS_LIMIT)
			{
				printf("%s (%d) reached the max cheat flags limit, kicking..", szName, i);
				Kick(i);
			}
		}
	}
}

task JetpackCheck[JETPACK_CHECK_INTERVAL]()
{
	foreach(Player, i)
	{
		if(GetPlayerSpecialAction(i) == SPECIAL_ACTION_USEJETPACK && !IsAdmin(i))
		{
			new szName[24], szString[128];
			GetPlayerName(i, szName, sizeof(szName));
			format(szString, sizeof(szString), "Kicking %s (%d) for using a jetpack.", szName, i);
			SendAdminMessage(szString);
			print(szString);
			Kick(i);
		}
	}
}

// Commands

CMD:kill(playerid, params[])
{
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");
	SetPlayerHealth(playerid, 0);
	return 1;
}

CMD:car(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");		
	new szID;
	if(!sscanf(params, "d", szID))
	{
		if(szID >= 400 && szID <= 611)
		{
			new Float: szX, Float: szY, Float: szZ, szVehicle;
			GetPlayerPos(playerid, szX, szY, szZ);
			szVehicle = CreateVehicle(szID, szX, szY, szZ, 0.0, 0, 0, 60);
			PutPlayerInVehicle(playerid, szVehicle, 0);
		} else return SendClientMessage(playerid, X11_FIREBRICK1, "Invalid model ID.");
	}
	else
	{
		Dialog_Show(playerid, DIALOG_STYLE_LIST, "Vehicle Selection", ""AZURE"Planes\n"AZURE"Helicopters\n"DEEPSKYBLUE3"Boats\n"YELLOW2"Bikes\n"YELLOW2"Cars", "Select", "Cancel", gVehicleDialog);
	}
	return 1;
}

CMD:info(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szTarget;
	if(!sscanf(params, "u", szTarget))
	{
		if(szTarget != INVALID_PLAYER_ID)
		{
			new szString[128], szName[24], szIP[16];
			GetPlayerIp(playerid, szIP, sizeof(szIP));
			GetPlayerName(szTarget, szName, sizeof(szName));
			format(szString, sizeof(szString), "ID: "HONEYDEW3"%d "AZURE"Name: "HONEYDEW3"%s "AZURE"IP: "HONEYDEW3"%s", szTarget, szName, szIP);
			SendClientMessage(playerid, X11_AZURE, szString);
		} else SendClientMessage(playerid, X11_FIREBRICK1, "Player not found.");
	} else SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /info [id]");
	return 1;
}

CMD:announce(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szString[64];
	if(!sscanf(params, "s[64]", szString))
	{
		GameTextForAll(szString, ANNOUNCE_DURATION, 3);
	} else SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /announce [text]");
	return 1;
}

CMD:givecash(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szTarget, szAmount;
	if(!sscanf(params, "ud", szTarget, szAmount))
	{
		if(szTarget != INVALID_PLAYER_ID)
		{
			GiveMoney(szTarget, szAmount);
		}
	} else SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /givecash [id] [amount]");
	return 1;
}

CMD:kick(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szTarget;
	if(!sscanf(params, "u", szTarget))
	{
		if(szTarget != INVALID_PLAYER_ID)
		{
			if(szTarget != playerid)
			{
				Kick(szTarget);
			} else SendClientMessage(playerid, X11_FIREBRICK1, "You cannot kick yourself.");
		} else SendClientMessage(playerid, X11_FIREBRICK1, "Player not found.");
	} else SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /kick [id]");
	return 1;
}


CMD:stats(playerid, params[])
{
	new szString[128], szName[24], szTarget;
	if(!sscanf(params, "u", szTarget))
	{
		if(szTarget != INVALID_PLAYER_ID)
		{
			GetPlayerName(szTarget, szName, sizeof(szName));
			format(szString, sizeof(szString), "Stats for "HONEYDEW3"%s (%d) "AZURE"Kills: "HONEYDEW3"%d "AZURE"Deaths: "HONEYDEW3"%d "AZURE"Money: "HONEYDEW3"$%d", szName, szTarget, PlayerData[szTarget][Kills], PlayerData[szTarget][Deaths], GetMoney(szTarget));
		} else SendClientMessage(playerid, X11_FIREBRICK1, "Player not found.");
	}
	else
	{
		GetPlayerName(playerid, szName, sizeof(szName));
		format(szString, sizeof(szString), "Stats for "HONEYDEW3"%s (%d) "AZURE"Kills: "HONEYDEW3"%d "AZURE"Deaths: "HONEYDEW3"%d "AZURE"Money: "HONEYDEW3"$%d", szName, playerid, PlayerData[playerid][Kills], PlayerData[playerid][Deaths], GetMoney(playerid));
	}
	SendClientMessage(playerid, X11_AZURE, szString);
	return 1;
}

CMD:savevehicle(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");		
	if(IsPlayerInAnyVehicle(playerid))
	{
		new Float: szPosition[3], Float: szAngle, szModelID, szQuery[256];
		szModelID = GetVehicleModel(GetPlayerVehicleID(playerid));
		GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
		GetVehicleZAngle(GetPlayerVehicleID(playerid), szAngle);
		mysql_format(gMySQL, szQuery, sizeof(szQuery), "INSERT INTO `vehicles` (`Model`, `X`, `Y`, `Z`, `Angle`, `Color1`, `Color2`) VALUES (%d, %f, %f, %f, %f, %d, %d)", szModelID, szPosition[0], szPosition[1], szPosition[2], szAngle, random(255), random(255));
		mysql_tquery(gMySQL, szQuery, "OnVehicleSaved", "i", playerid);
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "You must be in a vehicle to use this command.");
	return 1;
}

CMD:weapon(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");		
	Dialog_Show(playerid, DIALOG_STYLE_LIST, "Weapon Selection", ""FIREBRICK1"Reset Weapons\nGrenade\nTear Gas\nMolotov Cocktail\n9mm\nSilenced 9mm\nDesert Eagle\nShotgun\nSawnoff Shotgun\nCombat Shotgun\nMicro SMG\nMP5\nAK-47\nM4\nTec-9\nCountry Rifle\nSniper Rifle\nRPG\nHS Rocket\nFlamethrower\nMinigun\nSpraycan\nFire Extinguisher\nParachute", "Select", "Cancel", gWeaponDialog);
	return 1;
}

CMD:changeclass(playerid, params[])
{
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");		
	Dialog_Show(playerid, DIALOG_STYLE_LIST, "Class Selection", "Pilot\nSailor\nTrucker", "Select", "", gClassDialog);
	return 1;
}

CMD:cc(playerid, params[])
{
	if(PlayerData[playerid][Class] != PLAYER_CLASS_NONE)
	{
		new szMessage[128];
		if(!sscanf(params, "s[128]", szMessage))
		{
			new szString[128], szName[24];
			GetPlayerName(playerid, szName, sizeof(szName));

			switch(PlayerData[playerid][Class])
			{
				case 1: format(szString, sizeof(szString), ""SNOW"(Pilot Chat) "HONEYDEW3"%s: "SNOW"%s", szName, szMessage);
				case 2: format(szString, sizeof(szString), ""STEELBLUE2"(Sailor Chat) "HONEYDEW3"%s: "SNOW"%s", szName, szMessage);
				case 3: format(szString, sizeof(szString), ""PERU"(Trucker Chat) "HONEYDEW3"%s: "SNOW"%s", szName, szMessage);
			}
			foreach(Player, i)
			{
				if(PlayerData[i][Class] == PlayerData[playerid][Class])
				{
					SendClientMessage(i, X11_AZURE, szString);
				}
			}		
		} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /cc [message]");
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "You must select a class before you can use the class chat.");
	return 1;
}

CMD:local(playerid, params[])
{
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");		
	new szMessage[128];
	if(!sscanf(params, "s[128]", szMessage))
	{
		new Float: szPosition[3], szString[128], szName[24];
		GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
		GetPlayerName(playerid, szName, sizeof(szName));
		format(szString, sizeof(szString), "(Local Chat) "HONEYDEW3"%s: "SNOW"%s", szName, szMessage);
		foreach(Player, i)
		{
			if(IsPlayerInRangeOfPoint(i, LOCAL_CHAT_RANGE, szPosition[0], szPosition[1], szPosition[2]) && IsAlive(i))
			{
				SendClientMessage(i, X11_YELLOWGREEN, szString);
			}
		}
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /local [message]");
	return 1;
}

CMD:createee(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(!IsAlive(playerid)) return SendClientMessage(playerid, X11_FIREBRICK1, "You must be alive in order to use this command.");			
	switch(PlayerData[playerid][EEStage])
	{
		case 0:
		{
			PlayerData[playerid][EEVW] = GetPlayerVirtualWorld(playerid);
			PlayerData[playerid][EEInt] = GetPlayerInterior(playerid);
			GetPlayerPos(playerid, PlayerData[playerid][EEPos][0], PlayerData[playerid][EEPos][1], PlayerData[playerid][EEPos][2]);
			SendClientMessage(playerid, X11_AZURE, "Pickup location set. Walk to the desired teleport location and use the command again.");
			PlayerData[playerid][EEStage] = 1;
		}
		case 1:
		{
			new szString[128], szID, Float:szPosition[4], szVirtualWorld, szInterior;
			szVirtualWorld = GetPlayerVirtualWorld(playerid);		
			szInterior = GetPlayerInterior(playerid);					
			GetPlayerPos(playerid, szPosition[0], szPosition[1], szPosition[2]);
			GetPlayerFacingAngle(playerid, szPosition[3]);
			szID = CreateEnterExit(PlayerData[playerid][EEPos][0], PlayerData[playerid][EEPos][1], PlayerData[playerid][EEPos][2], szPosition[0], szPosition[1], szPosition[2], szPosition[3], PlayerData[playerid][EEInt], szInterior, PlayerData[playerid][EEVW], szVirtualWorld);
			format(szString, sizeof(szString), "Enter-exit ID "HONEYDEW3"%d "AZURE"created. Use "HONEYDEW3"/saveenter "AZURE"to save the entrance to the MySQL database.", szID);
			SendClientMessage(playerid, X11_AZURE, szString);
			PlayerData[playerid][EEStage] = 0;
			PlayerData[playerid][EELast] = szID;
		}
	}
	return 1;
}

CMD:infoee(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szID;
	if(!sscanf(params, "u", szID))
	{
		if(EnterExitExists(szID))
		{
			new szString[128];
			format(szString, sizeof(szString), "Entrance ID "HONEYDEW3"%d "AZURE"data: "HONEYDEW3"%f %f %f %f "AZURE"| "HONEYDEW"%d %d", szID, EnterExitData[szID][ExitPos][0], EnterExitData[szID][ExitPos][1], EnterExitData[szID][ExitPos][2], EnterExitData[szID][ExitAngle], EnterExitData[szID][ExitInterior], EnterExitData[szID][ExitVirtualWorld]);
			SendClientMessage(playerid, X11_AZURE, szString);
		} else return SendClientMessage(playerid, X11_FIREBRICK1, "Error: Invalid entrance ID.");
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /infoee [entrance id]");
	return 1;
}

CMD:saveee(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(EnterExitExists(PlayerData[playerid][EELast]))
	{
		new szQuery[256], szID;
		szID = PlayerData[playerid][EELast];
		mysql_format(gMySQL, szQuery, sizeof(szQuery), "INSERT INTO `entrances` (`EnterX`, `EnterY`, `EnterZ`, `ExitX`, `ExitY`, `ExitZ`, `ExitAngle`, `EnterVirtualWorld`, `ExitVirtualWorld`, `EnterInterior`, `ExitInterior`) VALUES (%f, %f, %f, %f, %f, %f, %f, %d, %d, %d, %d)", 	
			EnterExitData[szID][EnterPos][0], EnterExitData[szID][EnterPos][1], EnterExitData[szID][EnterPos][2], 
			EnterExitData[szID][ExitPos][0], EnterExitData[szID][ExitPos][1], EnterExitData[szID][ExitPos][2], EnterExitData[szID][ExitAngle], 
			EnterExitData[szID][EnterVirtualWorld], EnterExitData[szID][ExitVirtualWorld], EnterExitData[szID][EnterInterior], EnterExitData[szID][ExitInterior]);
		mysql_tquery(gMySQL, szQuery, "OnEnterExitSaved", "i", playerid);
	}
	return 1;
}

CMD:createdp(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szName[64];
	if(!sscanf(params, "s[64]", szName))
	{
		new Float: Position[3];
		GetPlayerPos(playerid, Position[0], Position[1], Position[2]);
		PlayerData[playerid][DPLast] = CreateDeliveryPoint(Position[0], Position[1], Position[2], szName); 
		SendClientMessage(playerid, X11_AZURE, "Delivery point created. Use "HONEYDEW3"/savedp"AZURE" to save the delivery point to the MySQL database.");
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /createdp [name]");
	return 1;
}

CMD:enabledp(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szID;
	if(!sscanf(params, "d", szID))
	{
		if(DeliveryPointExists(szID))
		{
			TogglePlayerDynamicCP(playerid, DeliveryPointData[szID][CheckpointHandle], true);
			UpdateDynamic3DTextLabelText(DeliveryPointData[szID][LabelHandle], LABEL_COLOR, DeliveryPointData[szID][Name]);			
		} else return SendClientMessage(playerid, X11_FIREBRICK1, "Invalid delivery point ID.");
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /enabledp [delivery point id]");
	return 1;	
}

CMD:disabledp(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	new szID;
	if(!sscanf(params, "d", szID))
	{
		if(DeliveryPointExists(szID))
		{
			TogglePlayerDynamicCP(playerid, DeliveryPointData[szID][CheckpointHandle], false);
			UpdateDynamic3DTextLabelText(DeliveryPointData[szID][LabelHandle], LABEL_COLOR, "");
		} else return SendClientMessage(playerid, X11_FIREBRICK1, "Invalid delivery point ID.");
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Usage: /disabledp [delivery point id]");
	return 1;	
}

CMD:savedp(playerid, params[])
{
	if(!IsAdmin(playerid)) return 0;
	if(DeliveryPointExists(PlayerData[playerid][DPLast]))
	{
		new szID, szQuery[256];
		szID = PlayerData[playerid][DPLast];
		mysql_format(gMySQL, szQuery, sizeof(szQuery), "INSERT INTO `deliverypoints` (`X`, `Y`, `Z`, `Name`) VALUES (%f, %f, %f, '%s')", DeliveryPointData[szID][DelPos][0], DeliveryPointData[szID][DelPos][1], DeliveryPointData[szID][DelPos][2], DeliveryPointData[szID][Name]);
		mysql_tquery(gMySQL, szQuery, "OnDeliveryPointSaved", "i", playerid);	
	} else return SendClientMessage(playerid, X11_FIREBRICK1, "Invalid delivery point.");
	return 1;
}
