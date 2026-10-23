// Kingmakers RP - starter open.mp gamemode.
// Build: the "Build Server" GitHub Action compiles this with the open.mp
// Pawn compiler and packs a ready-to-run server.

#include <open.mp>

#define COLOR_INFO      0x33CCFFFF
#define COLOR_ERROR     0xFF6347FF
#define COLOR_SUCCESS   0x9ACD32FF

#define SPAWN_X         1481.0
#define SPAWN_Y         -1771.0
#define SPAWN_Z         18.8
#define SPAWN_ANGLE     0.0

main()
{
	print("\n  Kingmakers RP gamemode loaded\n");
}

public OnGameModeInit()
{
	SetGameModeText("Kingmakers RP");
	UsePlayerPedAnims();
	DisableInteriorEnterExits();

	// Civilian skins at Los Santos City Hall
	new const skins[] = { 2, 7, 21, 23, 26, 29, 46, 59, 60, 98, 12, 40, 41, 56, 91, 93 };
	for (new i = 0; i < sizeof(skins); i++)
	{
		AddPlayerClass(skins[i], SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_ANGLE);
	}

	// A few cars outside City Hall
	AddStaticVehicle(411, 1468.0, -1738.0, 13.2, 270.0, -1, -1); // Infernus
	AddStaticVehicle(560, 1468.0, -1743.0, 13.2, 270.0, -1, -1); // Sultan
	AddStaticVehicle(522, 1468.0, -1748.0, 13.0, 270.0, -1, -1); // NRG-500
	AddStaticVehicle(596, 1494.0, -1738.0, 13.2, 90.0, 0, 1);    // Police car
	return 1;
}

public OnPlayerConnect(playerid)
{
	new name[MAX_PLAYER_NAME], msg[96];
	GetPlayerName(playerid, name, sizeof(name));
	format(msg, sizeof(msg), "%s joined Kingmakers RP.", name);
	SendClientMessageToAll(COLOR_INFO, msg);
	SendClientMessage(playerid, COLOR_INFO, "Welcome to Kingmakers RP! Type /help for commands.");
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	new name[MAX_PLAYER_NAME], msg[96];
	GetPlayerName(playerid, name, sizeof(name));
	format(msg, sizeof(msg), "%s left the server.", name);
	SendClientMessageToAll(COLOR_INFO, msg);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid, SPAWN_X, SPAWN_Y, SPAWN_Z);
	SetPlayerFacingAngle(playerid, 180.0);
	SetPlayerCameraPos(playerid, SPAWN_X, SPAWN_Y - 5.0, SPAWN_Z + 1.0);
	SetPlayerCameraLookAt(playerid, SPAWN_X, SPAWN_Y, SPAWN_Z);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	SetPlayerInterior(playerid, 0);
	GivePlayerMoney(playerid, 5000 - GetPlayerMoney(playerid));
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/help", true))
	{
		SendClientMessage(playerid, COLOR_INFO, "Commands: /car [model 400-611], /heal, /pos, /help");
		return 1;
	}

	if (!strcmp(cmdtext, "/heal", true))
	{
		SetPlayerHealth(playerid, 100.0);
		SendClientMessage(playerid, COLOR_SUCCESS, "You have been healed.");
		return 1;
	}

	if (!strcmp(cmdtext, "/pos", true))
	{
		new Float:x, Float:y, Float:z, msg[96];
		GetPlayerPos(playerid, x, y, z);
		format(msg, sizeof(msg), "Position: %.2f, %.2f, %.2f (interior %d)", x, y, z, GetPlayerInterior(playerid));
		SendClientMessage(playerid, COLOR_INFO, msg);
		return 1;
	}

	if (!strcmp(cmdtext, "/car", true, 4) && (cmdtext[4] == ' ' || cmdtext[4] == '\0'))
	{
		new model = (cmdtext[4] == ' ') ? strval(cmdtext[5]) : 411;
		if (model < 400 || model > 611)
		{
			SendClientMessage(playerid, COLOR_ERROR, "Usage: /car [model 400-611]");
			return 1;
		}
		if (IsPlayerInAnyVehicle(playerid))
		{
			SendClientMessage(playerid, COLOR_ERROR, "Leave your current vehicle first.");
			return 1;
		}
		new Float:x, Float:y, Float:z, Float:angle;
		GetPlayerPos(playerid, x, y, z);
		GetPlayerFacingAngle(playerid, angle);
		new vehicleid = CreateVehicle(model, x, y, z + 1.0, angle, -1, -1, -1);
		if (vehicleid == INVALID_VEHICLE_ID)
		{
			SendClientMessage(playerid, COLOR_ERROR, "Could not create the vehicle.");
			return 1;
		}
		LinkVehicleToInterior(vehicleid, GetPlayerInterior(playerid));
		SetVehicleVirtualWorld(vehicleid, GetPlayerVirtualWorld(playerid));
		PutPlayerInVehicle(playerid, vehicleid, 0);
		return 1;
	}

	return 0;
}
