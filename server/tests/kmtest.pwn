// Automated test for the Kingmakers RP gamemode. Loaded as a side script by
// server/tests/run.sh: an open.mp NPC plays the part of a real player
// (register, commands, reconnect, login) and every check prints PASS or FAIL.

#include <open.mp>

new gNpc = INVALID_PLAYER_ID, gStep = 0, gFailures = 0;

Check(bool:ok, const what[])
{
	if (ok) printf("[TEST] PASS %s", what);
	else
	{
		printf("[TEST] FAIL %s", what);
		gFailures++;
	}
}

Cmd(const format_[], arg = 0)
{
	new c[64];
	format(c, sizeof(c), format_, arg);
	return CallRemoteFunction("OnPlayerCommandText", "is", gNpc, c);
}

Dialog(dialogid, const text[])
{
	CallRemoteFunction("OnDialogResponse", "iiiis", gNpc, dialogid, 1, -1, text);
}

DbInt(const column[])
{
	new DB:db = DB_Open("kingmakers.db"), query[96], value = -1;
	format(query, sizeof(query), "SELECT %s FROM accounts WHERE name = 'KmTestUser'", column);
	new DBResult:result = DB_ExecuteQuery(db, query);
	if (DB_GetRowCount(result) > 0) value = DB_GetFieldInt(result, 0);
	DB_FreeResultSet(result);
	DB_Close(db);
	return value;
}

forward Step();
public Step()
{
	switch (++gStep)
	{
		case 1:
		{
			gNpc = NPC_Create("KmTestUser");
			Check(IsPlayerConnected(gNpc), "test player connects");
		}
		case 2:
		{
			Check(DbInt("id") == -1, "new player has no account yet");
			Dialog(1, "abc");
			Check(DbInt("id") == -1, "too short password is rejected");
			Dialog(1, "secret123");
			Check(DbInt("id") > 0, "register creates the account");
			Check(DbInt("money") == 5000, "new account starts with $5000");
			NPC_Spawn(gNpc);
		}
		case 3:
		{
			Check(GetPlayerMoney(gNpc) == 5000, "money is given on spawn");

			Cmd("/police");
			Check(GetPlayerSkin(gNpc) == 280, "/police puts on the uniform");
			Cmd("/police");
			Check(GetPlayerSkin(gNpc) != 280, "/police again goes off duty");

			Cmd("/setmoney %d 777", gNpc);
			Check(GetPlayerMoney(gNpc) == 5000, "non-admins cannot use /setmoney");
			SendRconCommand("makeadmin kmtestuser 3");
			Check(DbInt("admin") == 3, "makeadmin console command saves the level");
			Cmd("/setmoney %d 777", gNpc);
			Check(GetPlayerMoney(gNpc) == 777, "admins can use /setmoney");

			CallRemoteFunction("OnPlayerDeath", "iii", gNpc, gNpc, 0);
			Check(GetPlayerWantedLevel(gNpc) == 0, "suicide does not make you wanted");
			new other = NPC_Create("KmTestVictim");
			CallRemoteFunction("OnPlayerDeath", "iii", other, gNpc, 0);
			NPC_Destroy(other);
			Check(GetPlayerWantedLevel(gNpc) == 2, "a kill gives 2 wanted stars");
			Cmd("/police");
			Check(GetPlayerSkin(gNpc) != 280, "wanted players cannot join the police");
			Cmd("/clearwanted %d", gNpc);
			Check(GetPlayerWantedLevel(gNpc) == 0, "/clearwanted clears the wanted level");

			Check(Cmd("/work") == 1, "/work starts a delivery");
			Check(Cmd("/nosuchcommand") == 0, "unknown commands are not handled");
			NPC_SetPos(gNpc, 1500.0, -1700.0, 13.5);
		}
		case 4:
		{
			NPC_Destroy(gNpc);
		}
		case 5:
		{
			Check(DbInt("money") == 777, "money is saved on disconnect");
			Check(floatabs(float(DbInt("CAST(pos_x AS INTEGER)")) - 1500.0) < 1.0, "position is saved on disconnect");
			gNpc = NPC_Create("KmTestUser");
		}
		case 6:
		{
			Check(Cmd("/stats") == 1 && GetPlayerMoney(gNpc) == 0, "commands are blocked before login");
			Dialog(2, "wrongpass");
			Dialog(2, "secret123");
			NPC_Spawn(gNpc);
		}
		case 7:
		{
			// NPCs ignore SetPlayerPos, so restoring the position cannot be checked here
			Check(GetPlayerMoney(gNpc) == 777, "login restores money");
			Check(Cmd("/setmoney %d 1", gNpc) == 1, "login restores admin level");

			if (gFailures == 0) print("[TEST] ALL PASSED");
			else printf("[TEST] %d FAILED", gFailures);
			SendRconCommand("exit");
		}
	}
	return 1;
}

public OnFilterScriptInit()
{
	SetTimer("Step", 700, true);
	return 1;
}
