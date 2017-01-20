/*

IEE 1.2 by Mike (MP2)


### Changelog ###

1.2:
- No longer using y_hooks include
- Added 'OnPlayerEnterExitInterior' callback (OnPlayerEnterExitInterior(playerid, enterexitid, oldinterior, newinterior, Float:x, Float:y, Float:z))
- returning 0 in OnPlayerEnterExitInterior will disable the teleport.

1.1:
- Now using y_hooks to hook callbacks
- Fixed an issue with using your own pickups alongside this include
- 'world2' parameter in CreateEnterExit now set to -1 by default.
  This will prevent the player's world being changed on teleport

1.0:
 - Initial release

*/

// The 3 lines here will allow you to type "CreateEnterExit(" into pawno and a message will apear with the parameters in - useful as there's quite a few parameters
/*
native CreateEnterExit(ieeworld, Float:ieex, Float:ieey, Float:ieez, Float:ieex2, Float:ieey2, Float:ieez2, Float:ieea, ieeinterior, ieeworld2, ieemsg[] = "", ieemodel=19198);
native DeleteEnterExit(iee_id);
native IsEnterExitCreated(iee_id);
*/

forward OnPlayerEnterExitInterior(playerid, enterexitid, oldinterior, newinterior, Float:x, Float:y, Float:z);

#define IEE_COLOR 0xFFFFFFFF // Color for messages
#define PICKUP_HEIGHT_ADDITION 0.4 // Perfect height for using /save to get coordinates
#define MAX_IEE 500 // Maximum number of interior enter/exits

enum iee_enum
{
	iee_created, // Stored whether a pickup 'slot' is used
    iee_pickupid, // The ID of the pickup
	Float:iee_x, // Coordinate of teleport
	Float:iee_y, // Coordinate of teleport
	Float:iee_z, // Coordinate of teleport
	Float:iee_a, // Angle of teleport
	iee_int, // Interior of teleport
	iee_world, // World of teleport
	iee_msg[128] // A message to display to players when they enter the pickup
};

new iee_data[MAX_IEE][iee_enum];

public OnPlayerPickUpPickup(playerid, pickupid)
{
	for(new i=0; i<MAX_IEE; i++) // Loop through all IEE slots
	{
	    if(iee_data[i][iee_pickupid] == pickupid && iee_data[i][iee_created]) // Found
	    {
			if(CallLocalFunction("OnPlayerEnterExitInterior", "iiiifff", playerid, i, GetPlayerInterior(playerid), iee_data[i][iee_int], iee_data[i][iee_x], iee_data[i][iee_y], iee_data[i][iee_z]) || funcidx("OnPlayerEnterExitInterior") == -1)
			// If you return 0 in OnPlayerEnterExitInterior, the player will not be teleported. If you return nothing in that callback, the same applies.
			{
				SetPlayerPos(playerid, iee_data[i][iee_x], iee_data[i][iee_y], iee_data[i][iee_z]);
				SetPlayerFacingAngle(playerid, iee_data[i][iee_a]);
				SetPlayerInterior(playerid, iee_data[i][iee_int]);
				if(iee_data[i][iee_world] != -1) SetPlayerVirtualWorld(playerid, iee_data[i][iee_world]); // Only change world if one was set
				SetCameraBehindPlayer(playerid);
				if(strlen(iee_data[i][iee_msg])) SendClientMessage(playerid, IEE_COLOR, iee_data[i][iee_msg]);
			}
	        return 1;
	    }
	}
	return CallLocalFunction("iee_OnPlayerPickUpPickup", "ii", playerid, pickupid); // Hooking method
}

#if defined _ALS_OnPlayerPickUpPickup
    #undef OnPlayerPickUpPickup
#else
    #define _ALS_OnPlayerPickUpPickup
#endif
#define OnPlayerPickUpPickup iee_OnPlayerPickUpPickup
forward iee_OnPlayerPickUpPickup(playerid, pickupid);

/*  CreateEnterExit

	ieeworld - The virtual world that the pickup is shown in
	Float:ieex, Float:ieey, Float:ieez - The coordinates at which to create the pickup
	Float:ieex2, Float:ieey2, Float:ieez2 - The coordinates of where the teleport players that enter the pickup
	Float:ieea - The angle at which to set for the player when teleported
	ieeinterior - The interior to set when players teleport
	ieeworld2 - The world to set when players teleport (use for interiors used for several exteriors)
	ieemsg - A message to display to players when they enter the pickup (leave blank ( "" ) to disable)
	ieemodel=19198 - Custom object model for the pickup (defaults to the yellow cone)

	RETURNS:
	    This function returns the 'slot' that the pickup was assigned to, or -1 if the limit (MAX_IEE) was reached.
*/

stock CreateEnterExit(ieeworld, Float:ieex, Float:ieey, Float:ieez, Float:ieex2, Float:ieey2, Float:ieez2, Float:ieea, ieeinterior, ieeworld2 = -1, ieemsg[] = "", ieemodel=19198)
{
	for(new i=0; i<MAX_IEE; i++)
	{
	    if(iee_data[i][iee_created]) continue;
		if(ieemodel == 19198) iee_data[i][iee_pickupid] = CreatePickup(ieemodel, 1, ieex, ieey, ieez+PICKUP_HEIGHT_ADDITION, ieeworld);
		else iee_data[i][iee_pickupid] = CreatePickup(ieemodel, 1, ieex, ieey, ieez, ieeworld);
		iee_data[i][iee_x] = ieex2;
		iee_data[i][iee_y] = ieey2;
		iee_data[i][iee_z] = ieez2;
		iee_data[i][iee_a] = ieea;
		iee_data[i][iee_int] = ieeinterior;
		iee_data[i][iee_world] = ieeworld2;
		format(iee_data[i][iee_msg], 128, "%s", ieemsg);
		
		iee_data[i][iee_created] = 1;
		return i;
	}
	return -1;
}

/*  DeleteEnterExit

	iee_id - The ID of the enter/exit to delete (returned by CreateEnterExit)

	RETURNS:
	    This function returns 1 if the enter/exit was deleted or 0 if it did not exist


*/

stock DeleteEnterExit(iee_id)
{
	if(iee_id > MAX_IEE-1) return 0;
	if(iee_data[iee_id][iee_created] == 0) return 0;
	DestroyPickup(iee_data[iee_id][iee_pickupid]);
	iee_data[iee_id][iee_created] = 0;
	return 1;
}

/*  IsEnterExitCreated

	iee_id - The ID of the enter/exit to check for existance

	RETURNS:
	    This function returns 1 if the enter/exit exists or 0 if not


*/

stock IsEnterExitCreated(iee_id)
{
	if(iee_id > MAX_IEE-1) return 0;
	if(iee_data[iee_id][iee_created] == 0) return 0;
	return 1;
}

// Internal

stock iee_close() // Destroys all interior enter/exits - place " iee_close(); " under your OnGameModeExit callback.
{
	for(new i=0; i<MAX_IEE; i++) // Loop through all IEE slots
	{
	    if(iee_data[i][iee_created]) // Found
	    {
	        DestroyPickup(iee_data[i][iee_pickupid]);
	    }
	}
	return 1;
}