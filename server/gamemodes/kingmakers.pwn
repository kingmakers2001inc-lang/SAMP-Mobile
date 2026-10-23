// Kingmakers RP - starter open.mp gamemode.
// Build: the "Build Server" GitHub Action compiles this with the open.mp
// Pawn compiler and packs a ready-to-run server.
//
// Features: SQLite accounts (register/login, saved money/score/skin/position),
// delivery job, police duty with wanted levels and jail, admin commands.

#include <open.mp>
#include "sha256.inc"

#define COLOR_INFO      0x33CCFFFF
#define COLOR_ERROR     0xFF6347FF
#define COLOR_SUCCESS   0x9ACD32FF
#define COLOR_ADMIN     0xFFA500FF
#define COLOR_POLICE    0x3366FFFF
#define COLOR_CIVILIAN  0xFFFFFFFF

#define SPAWN_X         1481.0
#define SPAWN_Y         -1771.0
#define SPAWN_Z         18.8
#define SPAWN_ANGLE     0.0

#define START_MONEY     5000
#define MAX_LOGIN_TRIES 3
#define MAX_WANTED      6
#define JAIL_PER_STAR   60      // seconds of jail per wanted star
#define ARREST_REWARD   500     // paid to the officer per wanted star
#define POLICE_SKIN     280

#define DIALOG_REGISTER 1
#define DIALOG_LOGIN    2

#define JOB_NONE        0
#define JOB_DELIVERY    1
#define JOB_POLICE      2

enum E_PLAYER
{
	bool:pLogged,
	pAccountId,
	pAdmin,
	pWanted,
	pJob,
	pJail,
	pSkin,
	pLoginTries,
	bool:pHasSavedPos,
	Float:pPosX,
	Float:pPosY,
	Float:pPosZ,
	Float:pPosA,
	pInterior,
	pSavedMoney,    // money from the account, applied on first spawn; -1 after that
	bool:pOnDelivery
}

new gPlayer[MAX_PLAYERS][E_PLAYER];
new DB:gDb;

new const Float:gDeliverySpots[][3] =
{
	{ 2421.5, -1219.6, 25.5 },   // Pig Pen, East LS
	{ 1833.0, -1842.5, 13.6 },   // Unity Station
	{ 2104.5, -1806.5, 13.6 },   // Well Stacked Pizza, Idlewood
	{ 1352.4, -1759.0, 13.5 },   // 24/7 Commerce
	{ 1199.0, -918.0, 43.1 },    // Burger Shot, Vinewood
	{ 2229.9, -1721.5, 13.6 },   // Ganton Gym
	{ 1022.5, -1131.0, 23.9 },   // Market
	{ 2771.0, -1628.0, 10.9 }    // East Beach
};

main()
{
	print("\n  Kingmakers RP gamemode loaded\n");
}

// --- Helpers ----------------------------------------------------------------

// Returns the next space-separated word of `text` starting at `idx`.
GetWord(const text[], &idx, out[], size = sizeof (out))
{
	new len = strlen(text);
	while (idx < len && text[idx] == ' ') idx++;
	new start = idx;
	while (idx < len && text[idx] != ' ') idx++;
	strmid(out, text, start, idx, size);
	return idx - start;
}

// Returns the rest of `text` after `idx`, without leading spaces.
GetRest(const text[], idx, out[], size = sizeof (out))
{
	new len = strlen(text);
	while (idx < len && text[idx] == ' ') idx++;
	strmid(out, text, idx, len, size);
	return len - idx;
}

// Parses a player id; returns INVALID_PLAYER_ID if it is not a connected player.
ParsePlayer(const word[])
{
	if (!word[0]) return INVALID_PLAYER_ID;
	for (new i = 0; word[i]; i++)
	{
		if (word[i] < '0' || word[i] > '9') return INVALID_PLAYER_ID;
	}
	new id = strval(word);
	return IsPlayerConnected(id) ? id : INVALID_PLAYER_ID;
}

PlayerName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

SetMoney(playerid, amount)
{
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, amount);
}

SetWanted(playerid, level)
{
	if (level < 0) level = 0;
	if (level > MAX_WANTED) level = MAX_WANTED;
	gPlayer[playerid][pWanted] = level;
	SetPlayerWantedLevel(playerid, level);
	if (gPlayer[playerid][pJob] != JOB_POLICE)
	{
		SetPlayerColor(playerid, level > 0 ? 0xFF0000FF : COLOR_CIVILIAN);
	}
}

KickDelayed(playerid)
{
	// Delay so the player receives the messages sent just before
	SetTimerEx("DoKick", 500, false, "i", playerid);
}

forward DoKick(playerid);
public DoKick(playerid)
{
	Kick(playerid);
	return 1;
}

bool:IsNear(playerid, targetid, Float:range)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(targetid, x, y, z);
	return IsPlayerInRangeOfPoint(playerid, range, x, y, z)
		&& GetPlayerVirtualWorld(playerid) == GetPlayerVirtualWorld(targetid)
		&& GetPlayerInterior(playerid) == GetPlayerInterior(targetid);
}

// --- Accounts ---------------------------------------------------------------

#define HASH_ROUNDS     500

// Salted SHA-256, repeated to slow down password guessing.
HashPassword(const password[], const salt[], out[65])
{
	new buffer[129];
	format(buffer, sizeof(buffer), "%s%s", salt, password);
	Sha256(buffer, out);
	for (new i = 1; i < HASH_ROUNDS; i++)
	{
		format(buffer, sizeof(buffer), "%s%s", out, salt);
		Sha256(buffer, out);
	}
}

SaveAccount(playerid)
{
	if (!gPlayer[playerid][pLogged]) return;

	// Until the first spawn the client has not received the saved money yet
	new bool:spawnedOnce = gPlayer[playerid][pSavedMoney] == -1, query[256];
	format(query, sizeof(query),
		"UPDATE accounts SET money = %d, score = %d, skin = %d, admin = %d, wanted = %d, jail = %d WHERE id = %d",
		spawnedOnce ? GetPlayerMoney(playerid) : gPlayer[playerid][pSavedMoney],
		GetPlayerScore(playerid), gPlayer[playerid][pSkin], gPlayer[playerid][pAdmin],
		gPlayer[playerid][pWanted], gPlayer[playerid][pJail], gPlayer[playerid][pAccountId]);
	DB_FreeResultSet(DB_ExecuteQuery(gDb, query));

	// Only store the position while the player is alive in the world
	new PLAYER_STATE:playerState = GetPlayerState(playerid);
	if (spawnedOnce && gPlayer[playerid][pJail] == 0
		&& playerState != PLAYER_STATE_WASTED && playerState != PLAYER_STATE_SPECTATING)
	{
		new Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid, x, y, z);
		GetPlayerFacingAngle(playerid, a);
		format(query, sizeof(query),
			"UPDATE accounts SET pos_x = %f, pos_y = %f, pos_z = %f, pos_a = %f, interior = %d WHERE id = %d",
			x, y, z, a, GetPlayerInterior(playerid), gPlayer[playerid][pAccountId]);
		DB_FreeResultSet(DB_ExecuteQuery(gDb, query));
	}
}

ShowLoginDialog(playerid, const extra[] = "")
{
	new body[160];
	format(body, sizeof(body), "%sWelcome back, %s!\nEnter your password to log in:", extra, PlayerName(playerid));
	ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Kingmakers RP - Login", body, "Login", "Quit");
}

ShowRegisterDialog(playerid, const extra[] = "")
{
	new body[192];
	format(body, sizeof(body), "%sWelcome to Kingmakers RP, %s!\nChoose a password (6-32 characters) to create your account:", extra, PlayerName(playerid));
	ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Kingmakers RP - Register", body, "Register", "Quit");
}

LoadAccount(playerid, DBResult:result)
{
	gPlayer[playerid][pAccountId] = DB_GetFieldIntByName(result, "id");
	gPlayer[playerid][pSavedMoney] = DB_GetFieldIntByName(result, "money");
	gPlayer[playerid][pSkin] = DB_GetFieldIntByName(result, "skin");
	gPlayer[playerid][pAdmin] = DB_GetFieldIntByName(result, "admin");
	gPlayer[playerid][pWanted] = DB_GetFieldIntByName(result, "wanted");
	gPlayer[playerid][pJail] = DB_GetFieldIntByName(result, "jail");
	gPlayer[playerid][pInterior] = DB_GetFieldIntByName(result, "interior");
	gPlayer[playerid][pPosX] = DB_GetFieldFloatByName(result, "pos_x");
	gPlayer[playerid][pPosY] = DB_GetFieldFloatByName(result, "pos_y");
	gPlayer[playerid][pPosZ] = DB_GetFieldFloatByName(result, "pos_z");
	gPlayer[playerid][pPosA] = DB_GetFieldFloatByName(result, "pos_a");
	gPlayer[playerid][pHasSavedPos] = gPlayer[playerid][pPosX] != 0.0 || gPlayer[playerid][pPosY] != 0.0;
	gPlayer[playerid][pLogged] = true;
	SetPlayerScore(playerid, DB_GetFieldIntByName(result, "score"));
}

// --- Jail -------------------------------------------------------------------

PutInJail(playerid)
{
	SetPlayerInterior(playerid, 6);
	SetPlayerVirtualWorld(playerid, 0);
	SetPlayerPos(playerid, 264.0, 77.5, 1001.0);
	SetPlayerFacingAngle(playerid, 270.0);
	ResetPlayerWeapons(playerid);
	SetCameraBehindPlayer(playerid);
}

ReleaseFromJail(playerid)
{
	gPlayer[playerid][pJail] = 0;
	SetWanted(playerid, 0);
	SetPlayerInterior(playerid, 0);
	SetPlayerPos(playerid, 1552.6, -1675.6, 16.2);
	SetPlayerFacingAngle(playerid, 90.0);
	SetCameraBehindPlayer(playerid);
	SendClientMessage(playerid, COLOR_SUCCESS, "You have served your time. Stay out of trouble!");
}

forward OneSecondTimer();
public OneSecondTimer()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || gPlayer[i][pJail] <= 0) continue;
		if (--gPlayer[i][pJail] == 0)
		{
			ReleaseFromJail(i);
		}
		else if (gPlayer[i][pJail] % 30 == 0)
		{
			new msg[64];
			format(msg, sizeof(msg), "Jail time left: %d seconds.", gPlayer[i][pJail]);
			SendClientMessage(i, COLOR_POLICE, msg);
		}
	}
	return 1;
}

forward AutoSave();
public AutoSave()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i)) SaveAccount(i);
	}
	return 1;
}

// --- Delivery job -----------------------------------------------------------

StartDelivery(playerid)
{
	new spot = random(sizeof(gDeliverySpots));
	gPlayer[playerid][pOnDelivery] = true;
	SetPlayerCheckpoint(playerid, gDeliverySpots[spot][0], gDeliverySpots[spot][1], gDeliverySpots[spot][2], 4.0);
	SendClientMessage(playerid, COLOR_INFO, "Deliver the package to the red marker on your map.");
}

// --- Police -----------------------------------------------------------------

GoOffDuty(playerid)
{
	gPlayer[playerid][pJob] = JOB_NONE;
	ResetPlayerWeapons(playerid);
	if (gPlayer[playerid][pSkin] != -1) SetPlayerSkin(playerid, gPlayer[playerid][pSkin]);
	SetWanted(playerid, gPlayer[playerid][pWanted]);
	SendClientMessage(playerid, COLOR_POLICE, "You are now off duty.");
}

// --- Callbacks --------------------------------------------------------------

public OnGameModeInit()
{
	SetGameModeText("Kingmakers RP");
	UsePlayerPedAnims();
	DisableInteriorEnterExits();
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_GLOBAL);

	gDb = DB_Open("kingmakers.db");
	if (!gDb)
	{
		print("ERROR: could not open scriptfiles/kingmakers.db");
	}
	DB_FreeResultSet(DB_ExecuteQuery(gDb,
		"CREATE TABLE IF NOT EXISTS accounts (\
			id INTEGER PRIMARY KEY AUTOINCREMENT,\
			name TEXT NOT NULL UNIQUE COLLATE NOCASE,\
			hash TEXT NOT NULL,\
			salt TEXT NOT NULL,\
			money INTEGER NOT NULL DEFAULT 0,\
			score INTEGER NOT NULL DEFAULT 0,\
			skin INTEGER NOT NULL DEFAULT -1,\
			admin INTEGER NOT NULL DEFAULT 0,\
			wanted INTEGER NOT NULL DEFAULT 0,\
			jail INTEGER NOT NULL DEFAULT 0,\
			pos_x REAL NOT NULL DEFAULT 0, pos_y REAL NOT NULL DEFAULT 0,\
			pos_z REAL NOT NULL DEFAULT 0, pos_a REAL NOT NULL DEFAULT 0,\
			interior INTEGER NOT NULL DEFAULT 0)"));

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
	// Delivery vans at City Hall
	AddStaticVehicle(498, 1500.0, -1755.0, 13.6, 90.0, 1, 1);    // Boxville
	AddStaticVehicle(498, 1500.0, -1760.0, 13.6, 90.0, 1, 1);    // Boxville
	// Police cars at LSPD
	AddStaticVehicle(596, 1535.0, -1667.0, 13.1, 0.0, 0, 1);
	AddStaticVehicle(596, 1535.0, -1677.0, 13.1, 0.0, 0, 1);

	SetTimer("OneSecondTimer", 1000, true);
	SetTimer("AutoSave", 5 * 60 * 1000, true);
	return 1;
}

public OnGameModeExit()
{
	AutoSave();
	DB_Close(gDb);
	return 1;
}

public OnPlayerConnect(playerid)
{
	static const empty[E_PLAYER];
	gPlayer[playerid] = empty;
	gPlayer[playerid][pSkin] = -1;

	new msg[96];
	format(msg, sizeof(msg), "%s joined Kingmakers RP.", PlayerName(playerid));
	SendClientMessageToAll(COLOR_INFO, msg);

	new query[128];
	format(query, sizeof(query), "SELECT id FROM accounts WHERE name = '%q'", PlayerName(playerid));
	new DBResult:result = DB_ExecuteQuery(gDb, query);
	new bool:exists = DB_GetRowCount(result) > 0;
	DB_FreeResultSet(result);

	if (exists) ShowLoginDialog(playerid);
	else ShowRegisterDialog(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SaveAccount(playerid);
	gPlayer[playerid][pLogged] = false;

	new msg[96];
	format(msg, sizeof(msg), "%s left the server.", PlayerName(playerid));
	SendClientMessageToAll(COLOR_INFO, msg);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if (dialogid != DIALOG_REGISTER && dialogid != DIALOG_LOGIN) return 0;

	if (!response)
	{
		SendClientMessage(playerid, COLOR_ERROR, "You must log in to play.");
		KickDelayed(playerid);
		return 1;
	}

	new query[384], salt[17], hash[65];

	if (dialogid == DIALOG_REGISTER)
	{
		new len = strlen(inputtext);
		if (len < 6 || len > 32)
		{
			ShowRegisterDialog(playerid, "{FF6347}Password must be 6-32 characters.{FFFFFF}\n\n");
			return 1;
		}
		for (new i = 0; i < 16; i++)
		{
			salt[i] = 'a' + random(26);
		}
		salt[16] = '\0';
		HashPassword(inputtext, salt, hash);

		format(query, sizeof(query),
			"INSERT INTO accounts (name, hash, salt, money) VALUES ('%q', '%s', '%s', %d)",
			PlayerName(playerid), hash, salt, START_MONEY);
		DB_FreeResultSet(DB_ExecuteQuery(gDb, query));

		format(query, sizeof(query), "SELECT * FROM accounts WHERE name = '%q'", PlayerName(playerid));
		new DBResult:result = DB_ExecuteQuery(gDb, query);
		if (DB_GetRowCount(result) == 0)
		{
			DB_FreeResultSet(result);
			SendClientMessage(playerid, COLOR_ERROR, "Could not create your account. Please reconnect.");
			KickDelayed(playerid);
			return 1;
		}
		LoadAccount(playerid, result);
		DB_FreeResultSet(result);
		SendClientMessage(playerid, COLOR_SUCCESS, "Account created! Pick a skin and press Spawn. Type /help for commands.");
		return 1;
	}

	// DIALOG_LOGIN
	format(query, sizeof(query), "SELECT * FROM accounts WHERE name = '%q'", PlayerName(playerid));
	new DBResult:result = DB_ExecuteQuery(gDb, query);
	if (DB_GetRowCount(result) == 0)
	{
		DB_FreeResultSet(result);
		ShowRegisterDialog(playerid);
		return 1;
	}

	new storedHash[65];
	DB_GetFieldStringByName(result, "hash", storedHash);
	DB_GetFieldStringByName(result, "salt", salt);
	HashPassword(inputtext, salt, hash);

	if (strcmp(hash, storedHash, false) != 0 || !inputtext[0])
	{
		DB_FreeResultSet(result);
		if (++gPlayer[playerid][pLoginTries] >= MAX_LOGIN_TRIES)
		{
			SendClientMessage(playerid, COLOR_ERROR, "Too many wrong passwords.");
			KickDelayed(playerid);
			return 1;
		}
		ShowLoginDialog(playerid, "{FF6347}Wrong password.{FFFFFF}\n\n");
		return 1;
	}

	LoadAccount(playerid, result);
	DB_FreeResultSet(result);
	SendClientMessage(playerid, COLOR_SUCCESS, "Logged in. Press Spawn to continue where you left off. Type /help for commands.");
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

public OnPlayerRequestSpawn(playerid)
{
	if (!gPlayer[playerid][pLogged])
	{
		SendClientMessage(playerid, COLOR_ERROR, "Log in or register first.");
		return 0;
	}
	// First spawn after login: spawn where the player logged out
	if (gPlayer[playerid][pSavedMoney] != -1 && gPlayer[playerid][pHasSavedPos])
	{
		SetSpawnInfo(playerid, NO_TEAM, GetPlayerSkin(playerid),
			gPlayer[playerid][pPosX], gPlayer[playerid][pPosY], gPlayer[playerid][pPosZ], gPlayer[playerid][pPosA]);
	}
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if (!gPlayer[playerid][pLogged])
	{
		KickDelayed(playerid);
		return 1;
	}

	SetPlayerInterior(playerid, 0);

	// First spawn after login: restore the saved state
	if (gPlayer[playerid][pSavedMoney] != -1)
	{
		SetMoney(playerid, gPlayer[playerid][pSavedMoney]);
		gPlayer[playerid][pSavedMoney] = -1;

		if (gPlayer[playerid][pSkin] == -1)
		{
			gPlayer[playerid][pSkin] = GetPlayerSkin(playerid);
		}
		if (gPlayer[playerid][pHasSavedPos])
		{
			SetPlayerInterior(playerid, gPlayer[playerid][pInterior]);
			SetPlayerPos(playerid, gPlayer[playerid][pPosX], gPlayer[playerid][pPosY], gPlayer[playerid][pPosZ]);
			SetPlayerFacingAngle(playerid, gPlayer[playerid][pPosA]);
			SetCameraBehindPlayer(playerid);
		}
	}

	if (gPlayer[playerid][pJob] == JOB_POLICE)
	{
		SetPlayerSkin(playerid, POLICE_SKIN);
		GivePlayerWeapon(playerid, WEAPON_NITESTICK, 1);
		GivePlayerWeapon(playerid, WEAPON_COLT45, 200);
	}
	else if (gPlayer[playerid][pSkin] != -1)
	{
		SetPlayerSkin(playerid, gPlayer[playerid][pSkin]);
	}
	SetWanted(playerid, gPlayer[playerid][pWanted]);

	if (gPlayer[playerid][pJail] > 0)
	{
		PutInJail(playerid);
		new msg[64];
		format(msg, sizeof(msg), "You are in jail for %d more seconds.", gPlayer[playerid][pJail]);
		SendClientMessage(playerid, COLOR_POLICE, msg);
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
	if (gPlayer[playerid][pOnDelivery])
	{
		gPlayer[playerid][pOnDelivery] = false;
		DisablePlayerCheckpoint(playerid);
		SendClientMessage(playerid, COLOR_ERROR, "You died and lost the package. Type /work to try again.");
	}

	if (killerid == INVALID_PLAYER_ID || killerid == playerid) return 1;

	// Police killing a wanted suspect is fine; any other kill is a crime
	if (!(gPlayer[killerid][pJob] == JOB_POLICE && gPlayer[playerid][pWanted] > 0))
	{
		SetWanted(killerid, gPlayer[killerid][pWanted] + 2);
		SendClientMessage(killerid, COLOR_ERROR, "Murder! Your wanted level has increased.");
	}
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	if (!gPlayer[playerid][pOnDelivery]) return 1;

	gPlayer[playerid][pOnDelivery] = false;
	DisablePlayerCheckpoint(playerid);
	new pay = 300 + random(501), msg[96];
	GivePlayerMoney(playerid, pay);
	SetPlayerScore(playerid, GetPlayerScore(playerid) + 1);
	format(msg, sizeof(msg), "Delivery complete! You earned $%d. Type /work for another one.", pay);
	SendClientMessage(playerid, COLOR_SUCCESS, msg);
	return 1;
}

public OnRconCommand(cmd[])
{
	// "makeadmin <name> <level>" from the server console or /rcon in game
	new idx = 0, word[32], name[MAX_PLAYER_NAME];
	GetWord(cmd, idx, word);
	if (strcmp(word, "makeadmin", true) != 0) return 0;

	GetWord(cmd, idx, name);
	GetWord(cmd, idx, word);
	if (!name[0] || !word[0])
	{
		print("Usage: makeadmin <name> <level 0-3>");
		return 1;
	}
	new level = strval(word), query[160];
	format(query, sizeof(query), "UPDATE accounts SET admin = %d WHERE name = '%q'", level, name);
	DB_FreeResultSet(DB_ExecuteQuery(gDb, query));

	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i) && !strcmp(PlayerName(i), name, true))
		{
			gPlayer[i][pAdmin] = level;
			SendClientMessage(i, COLOR_ADMIN, "Your admin level has been changed.");
		}
	}
	printf("Admin level of %s set to %d", name, level);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!gPlayer[playerid][pLogged])
	{
		SendClientMessage(playerid, COLOR_ERROR, "Log in first.");
		return 1;
	}

	new idx = 0, cmd[32], word[32], msg[144];
	GetWord(cmdtext, idx, cmd);

	if (!strcmp(cmd, "/help", true))
	{
		SendClientMessage(playerid, COLOR_INFO, "General: /stats, /car [400-611], /heal, /pos, /help");
		SendClientMessage(playerid, COLOR_INFO, "Jobs: /work (delivery), /police (go on/off duty), /arrest [id], /quitjob");
		if (gPlayer[playerid][pAdmin] > 0)
		{
			SendClientMessage(playerid, COLOR_ADMIN, "Admin: /goto, /gethere, /kick, /clearwanted, /announce (1+), /ban (2+), /setmoney, /makeadmin (3)");
		}
		return 1;
	}

	if (!strcmp(cmd, "/stats", true))
	{
		static const jobs[][] = { "None", "Delivery", "Police" };
		format(msg, sizeof(msg), "Money: $%d | Score: %d | Wanted: %d | Job: %s | Admin: %d",
			GetPlayerMoney(playerid), GetPlayerScore(playerid), gPlayer[playerid][pWanted],
			jobs[gPlayer[playerid][pJob]], gPlayer[playerid][pAdmin]);
		SendClientMessage(playerid, COLOR_INFO, msg);
		return 1;
	}

	if (!strcmp(cmd, "/heal", true))
	{
		if (gPlayer[playerid][pJail] > 0) return SendClientMessage(playerid, COLOR_ERROR, "Not in jail."), 1;
		SetPlayerHealth(playerid, 100.0);
		SendClientMessage(playerid, COLOR_SUCCESS, "You have been healed.");
		return 1;
	}

	if (!strcmp(cmd, "/pos", true))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		format(msg, sizeof(msg), "Position: %.2f, %.2f, %.2f (interior %d)", x, y, z, GetPlayerInterior(playerid));
		SendClientMessage(playerid, COLOR_INFO, msg);
		return 1;
	}

	if (!strcmp(cmd, "/car", true))
	{
		new model = GetWord(cmdtext, idx, word) ? strval(word) : 411;
		if (model < 400 || model > 611) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /car [model 400-611]"), 1;
		if (gPlayer[playerid][pJail] > 0) return SendClientMessage(playerid, COLOR_ERROR, "Not in jail."), 1;
		if (IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, COLOR_ERROR, "Leave your current vehicle first."), 1;

		new Float:x, Float:y, Float:z, Float:angle;
		GetPlayerPos(playerid, x, y, z);
		GetPlayerFacingAngle(playerid, angle);
		new vehicleid = CreateVehicle(model, x, y, z + 1.0, angle, -1, -1, -1);
		if (vehicleid == INVALID_VEHICLE_ID) return SendClientMessage(playerid, COLOR_ERROR, "Could not create the vehicle."), 1;
		LinkVehicleToInterior(vehicleid, GetPlayerInterior(playerid));
		SetVehicleVirtualWorld(vehicleid, GetPlayerVirtualWorld(playerid));
		PutPlayerInVehicle(playerid, vehicleid, 0);
		return 1;
	}

	// --- Jobs ---

	if (!strcmp(cmd, "/work", true))
	{
		if (gPlayer[playerid][pJob] == JOB_POLICE) return SendClientMessage(playerid, COLOR_ERROR, "Go off police duty first (/police)."), 1;
		if (gPlayer[playerid][pJail] > 0) return SendClientMessage(playerid, COLOR_ERROR, "Not in jail."), 1;
		if (gPlayer[playerid][pOnDelivery]) return SendClientMessage(playerid, COLOR_ERROR, "Finish your current delivery first."), 1;
		gPlayer[playerid][pJob] = JOB_DELIVERY;
		StartDelivery(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/quitjob", true))
	{
		if (gPlayer[playerid][pJob] == JOB_POLICE)
		{
			GoOffDuty(playerid);
			return 1;
		}
		gPlayer[playerid][pJob] = JOB_NONE;
		if (gPlayer[playerid][pOnDelivery])
		{
			gPlayer[playerid][pOnDelivery] = false;
			DisablePlayerCheckpoint(playerid);
		}
		SendClientMessage(playerid, COLOR_INFO, "You quit your job.");
		return 1;
	}

	if (!strcmp(cmd, "/police", true))
	{
		if (gPlayer[playerid][pJob] == JOB_POLICE)
		{
			GoOffDuty(playerid);
			return 1;
		}
		if (gPlayer[playerid][pWanted] > 0 || gPlayer[playerid][pJail] > 0)
		{
			return SendClientMessage(playerid, COLOR_ERROR, "Wanted criminals cannot join the police."), 1;
		}
		if (gPlayer[playerid][pOnDelivery])
		{
			gPlayer[playerid][pOnDelivery] = false;
			DisablePlayerCheckpoint(playerid);
		}
		gPlayer[playerid][pJob] = JOB_POLICE;
		SetPlayerSkin(playerid, POLICE_SKIN);
		SetPlayerColor(playerid, COLOR_POLICE);
		GivePlayerWeapon(playerid, WEAPON_NITESTICK, 1);
		GivePlayerWeapon(playerid, WEAPON_COLT45, 200);
		SendClientMessage(playerid, COLOR_POLICE, "You are on police duty. Wanted players are red on the map. Use /arrest [id] near them.");
		return 1;
	}

	if (!strcmp(cmd, "/arrest", true))
	{
		if (gPlayer[playerid][pJob] != JOB_POLICE) return SendClientMessage(playerid, COLOR_ERROR, "Only police on duty can arrest."), 1;
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID || target == playerid) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /arrest [player id]"), 1;
		if (gPlayer[target][pWanted] == 0) return SendClientMessage(playerid, COLOR_ERROR, "That player is not wanted."), 1;
		if (!IsNear(playerid, target, 5.0)) return SendClientMessage(playerid, COLOR_ERROR, "You must be within 5 meters."), 1;

		new stars = gPlayer[target][pWanted];
		if (IsPlayerInAnyVehicle(target)) RemovePlayerFromVehicle(target);
		gPlayer[target][pJail] = stars * JAIL_PER_STAR;
		SetWanted(target, 0);
		PutInJail(target);
		GivePlayerMoney(playerid, stars * ARREST_REWARD);

		format(msg, sizeof(msg), "You were arrested by officer %s. Jail time: %d seconds.", PlayerName(playerid), gPlayer[target][pJail]);
		SendClientMessage(target, COLOR_POLICE, msg);
		format(msg, sizeof(msg), "Arrest successful. Reward: $%d.", stars * ARREST_REWARD);
		SendClientMessage(playerid, COLOR_SUCCESS, msg);
		return 1;
	}

	// --- Admin ---

	if (gPlayer[playerid][pAdmin] < 1) return 0;

	if (!strcmp(cmd, "/goto", true) || !strcmp(cmd, "/gethere", true))
	{
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /goto or /gethere [player id]"), 1;

		new from = target, to = playerid;
		if (!strcmp(cmd, "/goto", true))
		{
			from = playerid;
			to = target;
		}
		new Float:x, Float:y, Float:z;
		GetPlayerPos(to, x, y, z);
		SetPlayerInterior(from, GetPlayerInterior(to));
		SetPlayerVirtualWorld(from, GetPlayerVirtualWorld(to));
		SetPlayerPos(from, x + 1.0, y, z);
		return 1;
	}

	if (!strcmp(cmd, "/kick", true) || !strcmp(cmd, "/ban", true))
	{
		new bool:isBan = !strcmp(cmd, "/ban", true), reason[64];
		if (isBan && gPlayer[playerid][pAdmin] < 2) return SendClientMessage(playerid, COLOR_ERROR, "You need admin level 2."), 1;
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /kick or /ban [player id] [reason]"), 1;
		if (gPlayer[target][pAdmin] > gPlayer[playerid][pAdmin]) return SendClientMessage(playerid, COLOR_ERROR, "That player has a higher admin level."), 1;
		if (!GetRest(cmdtext, idx, reason)) strcat(reason, "No reason");

		format(msg, sizeof(msg), "Admin %s %s %s. Reason: %s", PlayerName(playerid), isBan ? "banned" : "kicked", PlayerName(target), reason);
		SendClientMessageToAll(COLOR_ADMIN, msg);
		if (isBan) BanEx(target, reason);
		else KickDelayed(target);
		return 1;
	}

	if (!strcmp(cmd, "/clearwanted", true))
	{
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /clearwanted [player id]"), 1;
		SetWanted(target, 0);
		if (gPlayer[target][pJail] > 0) ReleaseFromJail(target);
		SendClientMessage(playerid, COLOR_SUCCESS, "Wanted level and jail time cleared.");
		return 1;
	}

	if (!strcmp(cmd, "/announce", true))
	{
		new text[100];
		if (!GetRest(cmdtext, idx, text)) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /announce [text]"), 1;
		GameTextForAll(text, 5000, 3);
		return 1;
	}

	if (gPlayer[playerid][pAdmin] < 3) return 0;

	if (!strcmp(cmd, "/setmoney", true))
	{
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID || !GetWord(cmdtext, idx, word)) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /setmoney [player id] [amount]"), 1;
		SetMoney(target, strval(word));
		SendClientMessage(playerid, COLOR_SUCCESS, "Money set.");
		return 1;
	}

	if (!strcmp(cmd, "/makeadmin", true))
	{
		GetWord(cmdtext, idx, word);
		new target = ParsePlayer(word);
		if (target == INVALID_PLAYER_ID || !GetWord(cmdtext, idx, word)) return SendClientMessage(playerid, COLOR_ERROR, "Usage: /makeadmin [player id] [level 0-3]"), 1;
		new level = strval(word);
		if (level < 0 || level > 3) return SendClientMessage(playerid, COLOR_ERROR, "Level must be 0-3."), 1;
		gPlayer[target][pAdmin] = level;
		SaveAccount(target);
		format(msg, sizeof(msg), "%s set your admin level to %d.", PlayerName(playerid), level);
		SendClientMessage(target, COLOR_ADMIN, msg);
		SendClientMessage(playerid, COLOR_SUCCESS, "Admin level set.");
		return 1;
	}

	return 0;
}
