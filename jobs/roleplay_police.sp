/*
 * Cette oeuvre, création, site ou texte est sous licence Creative Commons Attribution
 * - Pas d’Utilisation Commerciale
 * - Partage dans les Mêmes Conditions 4.0 International. 
 * Pour accéder à une copie de cette licence, merci de vous rendre à l'adresse suivante
 * http://creativecommons.org/licenses/by-nc-sa/4.0/ .
 *
 * Merci de respecter le travail fourni par le ou les auteurs 
 * https://www.ts-x.eu/ - kossolax@ts-x.eu
 */
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors_csgo>	// https://forums.alliedmods.net/showthread.php?p=2205447#post2205447
#include <smlib>		// https://github.com/bcserv/smlib
#include <emitsoundany> // https://forums.alliedmods.net/showthread.php?t=237045

#define __LAST_REV__ 		"v:0.1.0"

#pragma newdecls required
#include <roleplay.inc>	// https://www.ts-x.eu

//#define DEBUG
#define ITEM_MANDAT			4
#define	ITEM_GPS			144

#define	MENU_TIME_DURATION	60
#define MAX_AREA_DIST		500
#define	MAX_LOCATIONS		150
#define	MAX_ZONES			300
#define MODEL_PRISONNIER	"models/player/rgmodels/rginmate/rginmate.mdl"

public Plugin myinfo = {
	name = "Jobs: Police", author = "KoSSoLaX",
	description = "RolePlay - Jobs: Police",
	version = __LAST_REV__, url = "https://www.ts-x.eu"
};
// TODO: Opérateur de bit dans le /cop.
// TODO: Message de débug oublié :(
// TODO: Le joueur s'est fait la male --> Synchro avec rp_users2. Condamnation même si déco
// TODO: Utiliser des TQuery pour le /perquiz.
// TODO: Trouver une manière plus propre que d'utiliser int g_iCancel[65];
// TODO: Améliorer le cache du JobToZoneID
// TODO: Le /amende :(

enum jail_raison_type {
	jail_raison = 0,
	jail_temps,
	jail_temps_nopay,
	jail_amende,
	
	jail_type_max
};
char g_szJailRaison[][][128] = {
	{ "Garde à vue",						"12", 	"12",	"0"},
	{ "Meurtre",							"-1", 	"-1",	"-1"},
	{ "Agression physique",					"1", 	"6",	"250"},
	{ "Intrusion propriétée privée",		"0", 	"3",	"100"},
	{ "Fuite, refus d'obtempérer",			"0", 	"6",	"200"},
	{ "Vol",								"0", 	"3",	"50"},
	{ "Insultes, Irrespect",				"1", 	"6",	"250"},
	{ "Trafique illégal, tenative de vol",	"0", 	"6",	"100"},
	{ "Nuisance sonore",					"0", 	"6",	"100"},
	{ "Tir dans la rue",					"0", 	"6",	"50"},
	{ "Conduite dangeureuse",				"0", 	"6",	"150"},
	{ "Mutinerie, évasion",					"-2", 	"-2",	"50"}	
};
int g_iCancel[65];
enum tribunal_type {
	tribunal_steamid = 0,
	tribunal_duration,
	tribunal_code,
	tribunal_option,
	
	tribunal_max
}
char g_szTribunal_DATA[65][tribunal_max][64];
// ----------------------------------------------------------------------------
public void OnPluginStart() {
	RegConsoleCmd("sm_jugement", Cmd_Jugement);
	
	RegServerCmd("rp_item_mandat", 		Cmd_ItemPickLock,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_ratio",		Cmd_ItemRatio,			"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_SendToJail",		Cmd_SendToJail,			"RP-ITEM",	FCVAR_UNREGISTERED);
	for (int i = 1; i <= MaxClients; i++)
		if( IsValidClient(i) )
			OnClientPostAdminCheck(i);
}
public Action Cmd_SendToJail(int args) {
	SendPlayerToJail(GetCmdArgInt(1));
}
public void OnMapStart() {
	PrecacheModel(MODEL_PRISONNIER, true);
}
// ----------------------------------------------------------------------------
public void OnClientPostAdminCheck(int client) {
	rp_HookEvent(client, RP_OnPlayerCommand, fwdCommand);
	rp_HookEvent(client, RP_OnPlayerSpawn, fwdSpawn);
}
public Action fwdSpawn(int client) {
	if( rp_GetClientInt(client, i_JailTime) > 0 )
		SendPlayerToJail(client, 0);
	return Plugin_Continue;
}
public void OnClientDisconnect(int client) {
	rp_UnhookEvent(client, RP_OnPlayerCommand, fwdCommand);
	rp_UnhookEvent(client, RP_OnPlayerSpawn, fwdSpawn);
}
public Action fwdCommand(int client, char[] command, char[] arg) {	
	if( StrEqual(command, "cop") || StrEqual(command, "cops") ) {
		return Cmd_Cop(client);
	}
	else if( StrEqual(command, "vis") || StrEqual(command, "invis") ) {
		return Cmd_Vis(client);
	}
	else if( StrEqual(command, "tazer") || StrEqual(command, "tazeur") || StrEqual(command, "taser") ) {
		return Cmd_Tazer(client);
	}
	else if( StrEqual(command, "enjail") || StrEqual(command, "injail") || StrEqual(command, "jaillist") ) {
		return Cmd_InJail(client);
	}
	else if( StrEqual(command, "jail") || StrEqual(command, "prison") ) {
		return Cmd_Jail(client);
	}
	else if( StrEqual(command, "perquiz") || StrEqual(command, "perqui") ) {
		return Cmd_Perquiz(client);
	}
	else if( StrEqual(command, "tribunal") ) {
		return Cmd_Tribunal(client);
	}
	else if( StrEqual(command, "mandat") ) {
		return Cmd_Mandat(client);
	}
	else if( StrEqual(command, "push") ) {
		return Cmd_Push(client);
	}
	else if( StrEqual(command, "conv") ) {
		return Cmd_Conv(client);
	}
	else if( StrEqual(command, "amende") || StrEqual(command, "amande") ) {
		return Cmd_Amende(client, arg);
	}
	else if( StrEqual(command, "audience") || StrEqual(command, "audiance") ) {
		return Cmd_Audience(client);
	}
	return Plugin_Continue;
}
// ----------------------------------------------------------------------------
public Action Cmd_Amende(int client, const char[] arg) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( job != 101 && job != 102 && job != 103 && job != 104 && job != 105 && job != 106 ) {
		ACCESS_DENIED(client);
	}
	
	if( !rp_GetClientBool(client, b_MaySteal) ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Impossible pour le moment.");
		return Plugin_Handled;
	}
	int target = GetClientTarget(client);

	if( !IsValidClient(target) )
		return Plugin_Handled;

	if( !IsPlayerAlive(target) )
		return Plugin_Handled;
	
	if( rp_GetZoneInt(rp_GetPlayerZone(client), zone_type_type) != 101 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous devez être dans le tribunal pour utiliser cette commande.");
		return Plugin_Handled;
	}
		
	int amount = StringToInt(arg);

	if( amount <= 0 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas donner une amende de moins de 0$.");
		return Plugin_Handled;
	}
	if( amount > (rp_GetClientInt(target, i_Money)+rp_GetClientInt(target, i_Bank)) ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Ce joueur n'a pas assez d'argent.");
		return Plugin_Handled;
	}

	int maxAmount = 0;
	switch( job ) {
		case 101: maxAmount = 100000000;	// Président
		case 102: maxAmount = 250000;		// Vice Président
		case 103: maxAmount = 100000;		// Haut juge 2
		case 104: maxAmount = 100000;		// Haut juge 1
		case 105: maxAmount = 25000;		// Juge 2
		case 106: maxAmount = 10000;		// Juge 1

	}
	if( amount > maxAmount ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Amende trop élevée.");
		return Plugin_Handled;
	}

	rp_SetJobCapital(101, ( rp_GetJobCapital(101) + (amount/4)*3 ) );

	rp_SetClientInt(client, i_Money, rp_GetClientInt(client, i_Money) + (amount / 4));
	rp_SetClientInt(target, i_Money, rp_GetClientInt(target, i_Money) - amount);

	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez pris %i$ a %N.", amount, target);
	CPrintToChat(target, "{lightblue}[TSX-RP]{default} %N vous a pris %i$.", client, amount);

	char SteamID[64], szTarget[64];
		
	GetClientAuthId(client, AuthId_Engine, SteamID, sizeof(SteamID), false);
	GetClientAuthId(target, AuthId_Engine, szTarget, sizeof(szTarget), false);
		
	char szQuery[1024];
	Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '4', '%i', '%s', '%i');",
	SteamID, rp_GetClientJobID(client), GetTime(), 0, "Amande", amount/4);

	SQL_TQuery(rp_GetDatabase(), SQL_QueryCallBack, szQuery);

	
	LogToGame("[TSX-RP] [AMENDE] %N (%s) a pris %i$ a %N (%s).", client, SteamID, amount, target, szTarget);
	rp_SetClientBool(client, b_MaySteal, false);
	
	CreateTimer(30.0, AllowStealing, client);
	return Plugin_Handled;
}
public Action Cmd_Cop(int client) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( rp_GetClientJobID(client) != 1 && job != 101 && job != 102 && job != 107 && job != 108 && job != 109 ) {
		ACCESS_DENIED(client);
	}
	int zone = rp_GetPlayerZone(client);
	int bit = rp_GetZoneBit(zone);
		
	if( bit & BITZONE_BLOCKJAIL || bit & BITZONE_JAIL || bit & BITZONE_HAUTESECU || bit & BITZONE_LACOURS ) { // Flic ripoux
		ACCESS_DENIED(client);
	}
	if( rp_GetClientVehiclePassager(client) > 0 || Client_GetVehicle(client) > 0 || rp_GetClientInt(client, i_Sickness) ) { // En voiture, ou très malade
		ACCESS_DENIED(client);
	}
	if( (job == 8 || job == 9) && rp_GetZoneInt(zone, zone_type_type) != 1 ) { // Gardien, policier dans le PDP
		ACCESS_DENIED(client);
	}
	if( (job == 107 || job == 108 || job == 109 ) && rp_GetZoneInt(zone, zone_type_type) != 1 && rp_GetZoneInt(zone, zone_type_type) != 101 ) { // GOS, Marshall, ONU dans Tribunal
		ACCESS_DENIED(client);
	}
	if( !rp_GetClientBool(client, b_MaySteal) || rp_GetClientBool(client, b_Stealing) ) { // Pendant un vol
		ACCESS_DENIED(client);
	}
	
	float origin[3], vecAngles[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, vecAngles);
	
	if( GetClientTeam(client) == CS_TEAM_CT ) {
		CS_SwitchTeam(client, CS_TEAM_T);
		SetEntityHealth(client, 100);
		rp_SetClientInt(client, i_Kevlar, 100);
		FakeClientCommand(client, "say /shownotes");
	}
	else if( GetClientTeam(client) == CS_TEAM_T ) {
		CS_SwitchTeam(client, CS_TEAM_CT);
		SetEntityHealth(client, 500);
		rp_SetClientInt(client, i_Kevlar, 250);
	}
		
	rp_ClientResetSkin(client);
	TeleportEntity(client, origin, vecAngles, NULL_VECTOR);
	rp_SetClientBool(client, b_MaySteal, false);
	CreateTimer(5.0, AllowStealing, client);
	return Plugin_Handled;
}
public Action Cmd_Vis(int client) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( job != 1 && job != 2 && job != 5 && job != 6 ) { // Chef, co chef, gti, cia
		ACCESS_DENIED(client);
	}
	int zone = rp_GetPlayerZone(client);
	int bit = rp_GetZoneBit(zone);
		
	if( bit & BITZONE_BLOCKJAIL || bit & BITZONE_JAIL || bit & BITZONE_HAUTESECU || bit & BITZONE_LACOURS ) { // Flic ripoux
		ACCESS_DENIED(client);
	}
	if( rp_GetClientVehiclePassager(client) > 0 || Client_GetVehicle(client) > 0 || rp_GetClientInt(client, i_Sickness) ) { // En voiture, ou très malade
		ACCESS_DENIED(client);
	}
	if( !rp_GetClientBool(client, b_MaySteal) || rp_GetClientBool(client, b_Stealing) ) { // Pendant un vol
		ACCESS_DENIED(client);
	}
	
	if( !rp_GetClientBool(client, b_Invisible)) {

		
		rp_ClientColorize(client, { 255, 255, 255, 0 } );
		rp_SetClientBool(client, b_Invisible, true);
		rp_SetClientBool(client, b_MaySteal, false);
		
		ClientCommand(client, "r_screenoverlay effects/hsv.vmt");
		
		if( job  == 6 ) {
			rp_SetClientFloat(client, fl_invisibleTime, GetGameTime() + 30.0);
			CreateTimer(120.0, AllowStealing, client);
		}
		else if ( job == 5 ) {
			rp_SetClientFloat(client, fl_invisibleTime, GetGameTime() + 60.0);
			CreateTimer(150.0, AllowStealing, client);
		}
		else if (job == 1 ||  job== 2 ) {
			rp_SetClientFloat(client, fl_invisibleTime, GetGameTime() + 90.0);
			rp_SetClientBool(client, b_MaySteal, true);
		}
		
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous êtes maintenant invisible.");
	}
	else {
		rp_ClientReveal(client);
	}
	return Plugin_Handled;
}
public Action Cmd_Tazer(int client) {
	char tmp[128], tmp2[128], szQuery[1024];
	int job = rp_GetClientInt(client, i_Job);
		
	if( rp_GetClientJobID(client) != 1 && rp_GetClientJobID(client) != 101 ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_GetClientVehiclePassager(client) > 0 || Client_GetVehicle(client) > 0 || rp_GetClientInt(client, i_Sickness) ) { // En voiture, ou très malade
		ACCESS_DENIED(client);
	}
	if( !rp_GetClientBool(client, b_MaySteal) ) {
		ACCESS_DENIED(client);
	}
	
	int target = GetClientTarget(client);
	if( target <= 0 || !IsValidEdict(target) || !IsValidEntity(target) )
		return Plugin_Handled;
	
	int Tzone = rp_GetPlayerZone(target);
	
	if( IsValidClient(target) ) {
		// Joueur:
		if( GetClientTeam(client) == CS_TEAM_T && job != 1 && job != 2 && job != 5 ) {
			ACCESS_DENIED(client);
		}
		if( GetClientTeam(target) == CS_TEAM_CT ) {
			ACCESS_DENIED(client);
		}
		
		float time;
		rp_Effect_Tazer(client, target);
		rp_HookEvent(target, RP_PreHUDColorize, fwdTazerBlue, 9.0);
		rp_HookEvent(target, RP_PrePlayerPhysic, fwdFrozen, 7.5);
		
		rp_SetClientFloat(target, fl_TazerTime, 9.0);

		CPrintToChat(target, "{lightblue}[TSX-RP]{default} Vous avez été tazé par %N", client);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez taze %N", target);

		rp_SetClientBool(client, b_MaySteal, false);
		switch( job ) {
				case 1:		time = 0.001;
				case 101:	time = 0.001;
				case 2:		time = 0.5;
				case 102:	time = 0.5;
				case 5:		time = 6.0;
				case 6:		time = 7.0;
				case 7:		time = 8.0;
				case 107:	time = 8.0;
				case 8:		time = 9.0;
				case 108:	time = 9.0;
				case 9:		time = 10.0;
				case 109:	time = 10.0;
				
				default: time = 10.0;
		}
		CreateTimer(time, 	AllowStealing, client);
	}
	else {
		// Props:
		int reward = -1;
		int owner = rp_GetBuildingData(target, BD_owner);
		GetEdictClassname(target, tmp2, sizeof(tmp2));
		
		if( owner != 0 && rp_IsMoveAble(target) && (Tzone == 0 || rp_GetZoneInt(Tzone, zone_type_type) <= 1	) ) {
			// PROPS
			
			if( IsValidClient( owner ) )
				CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Un de vos props a été supprimé.");
				
			rp_GetZoneData(Tzone, zone_type_name, tmp, sizeof(tmp));
			LogToGame("[TSX-RP] [TAZER] %L a supprimé un props de %L dans %s", client, target, tmp );
			
			reward = 0;
			if( rp_GetBuildingData(target, BD_started)+120 < GetTime() ) {
				Entity_GetModel(target, tmp, sizeof(tmp));
				if( StrContains(tmp, "popcan01a") == -1 ) {
					reward = 100;
				}
			}
		}
		else if ( StrContains(tmp2, "weapon_") == 0 && GetEntPropEnt(target, Prop_Send, "m_hOwnerEntity") == -1 ) {
			
			rp_GetZoneData(Tzone, zone_type_name, tmp, sizeof(tmp));
			LogToGame("[TSX-RP] [TAZER] %L a supprimé une arme %s dans %s", client, tmp2, tmp);
			
			reward = 100;
			if( rp_GetWeaponBallType(target) != ball_type_none ) {
				reward = 250;
			}
		}
		else if ( StrContains(tmp2, "rp_cashmachine_") == 0 ) {
			
			rp_GetZoneData(Tzone, zone_type_name, tmp, sizeof(tmp));
			LogToGame("[TSX-RP] [TAZER] %L a supprimé une machine de %L dans %s", client, owner, tmp);
			
			reward = 25;
			if( rp_GetBuildingData(target, BD_started)+120 < GetTime() ) {
				reward = 100;
			}
			
			if( owner > 0 ) {
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez detruit la machine de %N", owner);
				CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Une de vos machines a faux billet a été detruite par un policier.");
			}
		}
		else if ( StrContains(tmp2, "rp_plant_") == 0 ) {
			
			rp_GetZoneData(Tzone, zone_type_name, tmp, sizeof(tmp));
			LogToGame("[TSX-RP] [TAZER] %L a supprimé un plant de %L dans %s", client, owner, tmp);
			
			reward = 100;
			if( rp_GetBuildingData(target, BD_started)+120 < GetTime() ) {
				reward = 1000;
			}
			
			if( owner > 0 ) {
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez detruit le plant de drogue de %N", owner);
				CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Un de vos plant de drogue a été detruit par un policier.");
			}
		}
		
		if( reward >= 0 )  {
			
			rp_Effect_Tazer(client, target);
			rp_Effect_PropExplode(target, true);
			AcceptEntityInput(target, "Kill");
			
			rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) + reward);
			rp_SetJobCapital(1, rp_GetJobCapital(1) + reward*2);
						
				
			GetClientAuthId(client, AuthId_Engine, tmp, sizeof(tmp), false);
			Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '3', '%i', '%s', '%i');",
			tmp, rp_GetClientJobID(client), GetTime(), 1, "TAZER", reward);

			SQL_TQuery(rp_GetDatabase(), SQL_QueryCallBack, szQuery);
		}
	}
	return Plugin_Handled;
}
public Action Cmd_InJail(int client) {
	char tmp[256];
	
	int zone;
	
	Handle menu = CreateMenu(MenuNothing);
	SetMenuTitle(menu, "Liste des joueurs en prison:");
	
	for( int i=1;i<=MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
			
		zone = rp_GetZoneBit(rp_GetPlayerZone(i));
		if( zone & BITZONE_JAIL ||  zone & BITZONE_LACOURS ||  zone & BITZONE_HAUTESECU ) {
			
			Format(tmp, sizeof(tmp), "%N  - %.1f heures", i, rp_GetClientInt(i, i_JailTime)/60.0 );
			AddMenuItem(menu, tmp, tmp,	ITEMDRAW_DISABLED);
		}
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);
		
	return Plugin_Handled;
}
public Action Cmd_Jail(int client) {
	
	int job = rp_GetClientInt(client, i_Job);
		
	if( rp_GetClientJobID(client) != 1 && rp_GetClientJobID(client) != 101 ) {
		ACCESS_DENIED(client);
	}

	
	if( GetClientTeam(client) == CS_TEAM_T && (job == 8 || job == 9 || job == 107 || job == 108 || job == 109 ) ) {
		ACCESS_DENIED(client);
	}
	
	int target = GetClientTarget(client);
	if( target <= 0 || !IsValidEdict(target) || !IsValidEntity(target) )
		return Plugin_Handled;
	
	int Czone = rp_GetPlayerZone(client);
	int Cbit = rp_GetZoneBit(Czone);
	
	int Tzone = rp_GetPlayerZone(target);
	int Tbit = rp_GetZoneBit(Tzone);
	
	if( Entity_GetDistance(client, target) > MAX_AREA_DIST*3 ) {
		ACCESS_DENIED(client);
	}
	
	if( Cbit & BITZONE_BLOCKJAIL ||  Tbit & BITZONE_BLOCKJAIL ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_GetZoneInt(Czone, zone_type_type) == 101 && (job == 101 || job == 102 || job == 103 || job == 104 || job == 105 || job == 106) ) {

		int maxAmount = 0;
		switch( job ) {
			case 101: maxAmount = 1000;		// Président
			case 102: maxAmount = 300;		// Vice Président
			case 103: maxAmount = 100;		// Haut juge 2
			case 104: maxAmount = 100;		// Haut juge 1
			case 105: maxAmount = 35;		// Juge 2
			case 106: maxAmount = 24;		// Juge 1
		}

		// Setup menu
		Handle menu = CreateMenu(eventAskJail2Time);
		char tmp[256], tmp2[256];
		Format(tmp, 255, "Combien de temps doit rester %N?", target);
		SetMenuTitle(menu, tmp);

		Format(tmp, 255, "%i_-1", target);
		AddMenuItem(menu, tmp, "Prédéfinie");

		for(int i=6; i<=600; i += 6) {

			if( i > maxAmount )
				break;

			Format(tmp, 255, "%i_%i", target, i);
			Format(tmp2, 255, "%i Heures", i);

			AddMenuItem(menu, tmp, tmp2);
		}

		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_DURATION);
			
		
		return Plugin_Handled;
	}

	if( rp_IsValidVehicle(target) ) {
		int client2 = GetEntPropEnt(target, Prop_Send, "m_hPlayer");
		if( IsValidClient(client2) )
			rp_ClientVehicleExit(client2, target, true);
		return Plugin_Handled;
	}
	else if( !IsValidClient(target) ) {
		return Plugin_Handled;
	}
	
	if( GetClientTeam(target) == CS_TEAM_CT && !(job == 101 || job == 102 || job == 103 ) ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_GetClientInt(target, i_JailTime) <= 60 )
		rp_SetClientInt(target, i_JailTime, 60);
	
	SendPlayerToJail(target, client);
	// g_iUserMission[target][mission_type] = -1; 
	
	return Plugin_Handled;
}
public Action Cmd_Perquiz(int client) {
	int job = rp_GetClientInt(client, i_Job);
	
	if( rp_GetClientJobID(client) != 1 && rp_GetClientJobID(client) != 101 ) {
		ACCESS_DENIED(client);
	}
	if( job == 8 || job == 9 || job == 109 || job == 108 ) {
		ACCESS_DENIED(client);
	}
	if( GetClientTeam(client) == CS_TEAM_T ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_GetClientFloat(client, fl_CoolDown) > GetGameTime() ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez rien utiliser pour encore %.2f seconde(s).", (rp_GetClientFloat(client, fl_CoolDown)-GetGameTime()) );
		return Plugin_Handled;
	}

	rp_SetClientFloat(client, fl_CoolDown, GetGameTime() + 5.0);
	
	int job_id = 0;
	int zone = rp_GetPlayerZone( GetClientTarget(client) );
	if( zone > 0 ) {
		job_id = rp_GetZoneInt(zone, zone_type_type);
	}
	if( job_id <= 0 || job_id > 250 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cette porte ne peut pas être perquisitionnée.");
		return Plugin_Handled;
	}

	if( job_id == 1 || job_id == 151 || job_id == 101 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cette porte ne peut pas être perquisitionnée.");
		return Plugin_Handled;
	}
	
	
	Handle menu = CreateMenu(MenuPerquiz);
	SetMenuTitle(menu, "Gestion des perquisitions");
	Handle DB = rp_GetDatabase();
	SQL_LockDatabase( DB ); // !!!!!!!!!!!
	char szQuery[1024];
	Format(szQuery, sizeof(szQuery), "SELECT `time` FROM  `rp_perquiz` WHERE `job`='%i' ORDER BY `id` DESC LIMIT 1;", job_id);
	Handle row = SQL_Query(DB, szQuery);
	if( row != INVALID_HANDLE ) {
		if( SQL_FetchRow(row) ) {
			char tmp[128];
			Format(tmp, sizeof(tmp), "Il y a %d minutes", (GetTime()-SQL_FetchInt(row, 0))/60 );
			AddMenuItem(menu, "", tmp,		ITEMDRAW_DISABLED);
		}
		else {
			AddMenuItem(menu, "", "Pas encore perqui",		ITEMDRAW_DISABLED);
		}
	}
	SQL_UnlockDatabase( DB );

	char szResp[128];
	Format(szResp, sizeof(szResp), "Responsable: %N", GetPerquizResp(job_id));

	AddMenuItem(menu, "", szResp,		ITEMDRAW_DISABLED);
	AddMenuItem(menu, "start",	"Debuter");
	AddMenuItem(menu, "cancel", "Annuler");
	AddMenuItem(menu, "stop",	"Terminer");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);
	
	return Plugin_Handled;
}
public Action Cmd_Mandat(int client) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( job != 101 && job != 102 && job != 103 && job != 104 && job != 105 && job != 106 ) {
		ACCESS_DENIED(client);
	}
	int target = GetClientTarget(client);
	if( target <= 0 || !IsValidEdict(target) || !IsValidEntity(target) )
		return Plugin_Handled;
	
	if( rp_GetClientJobID(target) != 1 && rp_GetClientJobID(target) != 101 ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_GetClientItem(target, ITEM_MANDAT) < 10 ) {
		rp_ClientGiveItem(target, ITEM_MANDAT);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez donner un mandat a: %N", target);
		CPrintToChat(target, "{lightblue}[TSX-RP]{default} Vous avez recu un mandat de: %N", client);
	}
	return Plugin_Handled;
}
public Action Cmd_Push(int client) {
	
	int job = rp_GetClientInt(client, i_Job);
		
	if( rp_GetClientJobID(client) != 1 && rp_GetClientJobID(client) != 101 ) {
		ACCESS_DENIED(client);
	}
	
	if( GetClientTeam(client) == CS_TEAM_T && (job == 8 || job == 9 || job == 107 || job == 108 || job == 109 ) ) {
		ACCESS_DENIED(client);
	}
	
	int target = GetClientTarget(client);
	if( target <= 0 || !IsValidEdict(target) || !IsValidEntity(target) )
		return Plugin_Handled;
	
	if( Entity_GetDistance(client, target) > MAX_AREA_DIST*3 ) {
		ACCESS_DENIED(client);
	}
	
	if( !rp_GetClientBool(client, b_MaySteal) ) {
		ACCESS_DENIED(client);
	}
	rp_SetClientBool(client, b_MaySteal, false);
	CreateTimer(7.5, AllowStealing, client);
	
	float cOrigin[3], tOrigin[3];
	GetClientAbsOrigin(client, cOrigin);
	GetClientAbsOrigin(target, tOrigin);

	cOrigin[2] -= 100.0;

	float f_Velocity[3];
	SubtractVectors(tOrigin, cOrigin, f_Velocity);
	NormalizeVector(f_Velocity, f_Velocity);
	ScaleVector(f_Velocity, 500.0);

	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, f_Velocity);
	
	return Plugin_Handled;
}
public Action Cmd_Audience(int client) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( job != 101 && job != 102 && job != 103 && job != 104 && job != 105 && job != 106 ) {
		ACCESS_DENIED(client);
	}
	
	char tmp[2048], tmp2[128];
	rp_GetJobData(job, job_type_name, tmp2, sizeof(tmp2));
	Format(tmp, sizeof(tmp), "https://www.ts-x.eu/popup.php?url=https://docs.google.com/forms/d/1u4PFUsNBtVphggSyF3McU0gkA_o-6jEMSk0qmp0epFU/viewform?entry.249878658=%N%20-%20%s",
	client, tmp2);
		
		
	QueryClientConVar(client, "cl_disablehtmlmotd", view_as<ConVarQueryFinished>ClientConVar, client);
	ShowMOTDPanel(client, "Role-Play: Audience", tmp, MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}
public void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	
	if( StrEqual(cvarName, "cl_disablehtmlmotd", false) ) {
		if( StrEqual(cvarValue, "0") == false ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Des problemes d'affichage? Entrer cl_disablehtmlmotd 0 dans votre console puis relancer CS:GO.");
		}
	}
}
// ----------------------------------------------------------------------------
public Action Cmd_Jugement(int client, int args) {
	
	char arg1[12];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int job = rp_GetClientInt(client, i_Job);
	
	if( job != 101 && job != 102 && job != 103 && job != 104 ) {
		ACCESS_DENIED(client);
	}
	
	Handle DB = rp_GetDatabase();
	
	if( StrEqual(g_szTribunal_DATA[client][tribunal_code], arg1, false) ) {
		if( StrEqual(g_szTribunal_DATA[client][tribunal_option], "unknown") ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Le code est incorecte, le jugement a été annulé.");
			return Plugin_Handled;
		}
		
		char SteamID[64], UserName[64];
		
		GetClientAuthId(client, AuthId_Engine, SteamID, sizeof(SteamID), false);
		GetClientName(client,UserName,63);
		
		char szReason[128], tmp[64];
		for(int i=2; i<=args; i++) {
			
			GetCmdArg(i, tmp, sizeof(tmp));
			Format(szReason, sizeof(szReason), "%s%s ", szReason, tmp);
		}
		
		char buffer_name[ sizeof(UserName)*2+1 ];
		SQL_EscapeString(DB, UserName, buffer_name, sizeof(buffer_name));
		
		char buffer_reason[ sizeof(szReason)*2+1 ];
		SQL_EscapeString(DB, szReason, buffer_reason, sizeof(buffer_reason));
		
		char szQuery[2048];
		if( StringToInt(g_szTribunal_DATA[client][tribunal_duration]) > 0 ) {
			
			Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_users2` (`id`, `steamid`, `jail`, `pseudo`, `steamid2`, `raison`) VALUES", szQuery);
			Format(szQuery, sizeof(szQuery), "%s (NULL, '%s', '%i', '%s', '%s', '%s');", 
				szQuery,
				g_szTribunal_DATA[client][tribunal_steamid],
				StringToInt(g_szTribunal_DATA[client][tribunal_duration])*60,
				buffer_name,
				SteamID,
				buffer_reason
			);
			
			SQL_TQuery(DB, SQL_QueryCallBack, szQuery);
			
			LogToGame("[TSX-RP] [TRIBUNAL_V2] le juge %s %s a condamné %s à faire %s heures de prison pour %s",
				UserName,
				SteamID,
				g_szTribunal_DATA[client][tribunal_steamid],
				g_szTribunal_DATA[client][tribunal_duration],
				szReason
			);
			
			CPrintToChatAll("{lightblue}[TSX-RP]{default} Le juge %s %s a condamné %s à faire %s heures de prison pour %s",
				UserName,
				SteamID,
				g_szTribunal_DATA[client][tribunal_steamid],
				g_szTribunal_DATA[client][tribunal_duration],
				szReason
			);
		}
		else {
			LogToGame("[TSX-RP] [TRIBUNAL_V2] le juge %s %s a acquitté %s pour %s",
				UserName,
				SteamID,
				g_szTribunal_DATA[client][tribunal_steamid],
				szReason
			);
			
			CPrintToChatAll("{lightblue}[TSX-RP]{default} Le juge %s %s a acquitté %s pour %s",
				UserName,
				SteamID,
				g_szTribunal_DATA[client][tribunal_steamid],
				szReason
			);
		}
		
		if( StrEqual(g_szTribunal_DATA[client][tribunal_option], "forum") ) {
			
			Format(szQuery, sizeof(szQuery), "DELETE FROM `ts-x`.`site_report` WHERE `report_steamid`='%s';", g_szTribunal_DATA[client][tribunal_steamid]);
			SQL_TQuery(DB, SQL_QueryCallBack, szQuery);
			
			Format(szQuery, sizeof(szQuery), "DELETE FROM `ts-x`.`site_tribunal` WHERE `report_steamid`='%s';", g_szTribunal_DATA[client][tribunal_steamid]);
			SQL_TQuery(DB, SQL_QueryCallBack, szQuery);
		}
		
	}
	
	char random[6];
	String_GetRandom(random, sizeof(random), sizeof(random) - 1);
	
	Format(g_szTribunal_DATA[client][tribunal_code], 63, random);
	Format(g_szTribunal_DATA[client][tribunal_option], 63, "unknown");
	
	return Plugin_Handled;
}
// ----------------------------------------------------------------------------
public Action Cmd_Conv(int client) {
	
	int job = rp_GetClientInt(client, i_Job);
		
	if( rp_GetClientJobID(client) != 101 ) {
		ACCESS_DENIED(client);
	}
	if( job == 109 || job == 108 || job == 107 ) {
		ACCESS_DENIED(client);
	}
	
	// Setup menu
	Handle menu = CreateMenu(eventConvocation);
	SetMenuTitle(menu, "Liste des joueurs:");
	char tmp[24], tmp2[64];

	for(int i=1; i<=MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;

		Format(tmp, sizeof(tmp), "%i", i);
		Format(tmp2, sizeof(tmp2), "%N", i);

		AddMenuItem(menu, tmp, tmp2);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);

	return Plugin_Handled;
}
public int eventConvocation(Handle menu, MenuAction action, int client, int param2) {
	
	if( action == MenuAction_Select ) {
		char options[128];
		GetMenuItem(menu, param2, options, sizeof(options));
		int target = StringToInt(options);
		
		// Setup menu
		Handle menu2 = CreateMenu(eventConvocation_2);
		Format(options, sizeof(options), "Quel convocation donner a %N", target);
		SetMenuTitle(menu2, options);
		
		Format(options, sizeof(options), "%i_1", target);
		AddMenuItem(menu2, options, "Premiere");
		
		Format(options, sizeof(options), "%i_2", target);
		AddMenuItem(menu2, options, "Deuxieme");
		
		Format(options, sizeof(options), "%i_3", target);
		AddMenuItem(menu2, options, "Troisieme");
		
		
		Format(options, sizeof(options), "%i_0", target);
		AddMenuItem(menu2, options, "Rechercher");
		
		Format(options, sizeof(options), "%i_-1", target);
		AddMenuItem(menu2, options, "Stop recherche");
		
		
		SetMenuExitButton(menu2, true);
		DisplayMenu(menu2, client, MENU_TIME_DURATION*10);
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
public int eventConvocation_2(Handle menu, MenuAction action, int client, int param2) {
	
	if( action == MenuAction_Select ) {
		char options[64], optionsBuff[2][64];
		GetMenuItem(menu, param2, options, sizeof(options));
		
		ExplodeString(options, "_", optionsBuff, sizeof(optionsBuff), sizeof(optionsBuff[]));
		
		int target = StringToInt(optionsBuff[0]);
		int etat = StringToInt(optionsBuff[1]);
		rp_GetZoneData(rp_GetPlayerZone(client), zone_type_name, options, sizeof(options));
		
		if( etat == -1 ) {
			CPrintToChatAll("{lightblue} ================================== {default}");
			CPrintToChatAll("{lightblue}[TSX-RP] [TRIBUNAL]{default} %N n'est plus recherché par le Tribunal.", target);
			CPrintToChatAll("{lightblue} ================================== {default}");
		}
		else if( etat == 0 ) {
			CPrintToChatAll("{lightblue} ================================== {default}");
			CPrintToChatAll("{lightblue}[TSX-RP] [TRIBUNAL]{default} %N est recherché par le Tribunal.", target);
			CPrintToChatAll("{lightblue} ================================== {default}");
		}
		else {
			CPrintToChatAll("{lightblue} ================================== {default}");
			CPrintToChatAll("{lightblue}[TSX-RP] [TRIBUNAL]{default} %N est appelé dans le %s. [%i/3]", target, options, etat);
			CPrintToChatAll("{lightblue} ================================== {default}");
		}
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
// ----------------------------------------------------------------------------
public Action Cmd_Tribunal(int client) {
	int job = rp_GetClientInt(client, i_Job);
		
	if( job != 1 && job != 2 && job != 101 && job != 102 && job != 103 && job != 104 && job != 105 && job != 106 ) {
		ACCESS_DENIED(client);
	}
	if( rp_GetZoneInt( rp_GetPlayerZone(client), zone_type_type) != 101 ) {
		ACCESS_DENIED(client);
	}
	
	// Setup menu
	Handle menu = CreateMenu(MenuTribunal_main);

	SetMenuTitle(menu, "  Tribunal \n--------------------");

	if( job == 101 || job == 102 || job == 103 || job == 104 ) {
		AddMenuItem(menu, "forum",		"Juger les cas du forum");
		AddMenuItem(menu, "connected",	"Juger un joueur présent");
		AddMenuItem(menu, "disconnect",	"Juger un joueur récement déconnecté");
	}
	AddMenuItem(menu, "stats",		"Voir les stats d'un joueur");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);

	return Plugin_Handled;
}
public int MenuTribunal_main(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuTribunal_main");
	#endif
	if( p_oAction == MenuAction_Select && client != 0) {
		char options[64];
		GetMenuItem(p_hItemMenu, p_iParam2, options, 63);
		
		Handle menu = CreateMenu(MenuTribunal_selectplayer);
		Handle DB = rp_GetDatabase();
		
		if( StrEqual( options, "forum", false) ) {
			
			SetMenuTitle(menu, "  Tribunal - Cas Forum \n--------------------");
			PrintToServer("LOCK-2");
			SQL_LockDatabase(DB);
			
			char szQuery[1024];
			Format(szQuery, sizeof(szQuery), "SELECT `site_report`.`report_steamid`,COUNT(*) AS count FROM `ts-x`.`site_report`,`ts-x`.`site_tribunal` WHERE");
			Format(szQuery, sizeof(szQuery), "%s `site_tribunal`.`report_steamid`=`site_report`.`report_steamid` GROUP BY", szQuery);
			Format(szQuery, sizeof(szQuery), "%s `site_report`.`report_steamid` HAVING COUNT(*) >= 5 ORDER BY count DESC;", szQuery);
			
			Handle hQuery = SQL_Query(DB, szQuery);
			
			if( hQuery != INVALID_HANDLE ) {
				while( SQL_FetchRow(hQuery) ) {
					
					char tmp[255], tmp2[255], szSteam[32];
					
					SQL_FetchString(hQuery, 0, szSteam, sizeof(szSteam));
					int count=SQL_FetchInt(hQuery, 1);
					
					Format(tmp, sizeof(tmp), "%s %s", options, szSteam);
					
					Format(tmp2, sizeof(tmp2), "[%i] %s", count, szSteam);
					AddMenuItem(menu, tmp, tmp2);
				}
			}
			
			if( hQuery != INVALID_HANDLE )
				CloseHandle(hQuery);
			
			SQL_UnlockDatabase(DB);
			PrintToServer("UNLOCK-2");
		}
		else if( StrEqual( options, "connected", false) ) {
			
			SetMenuTitle(menu, "  Tribunal - Cas connecté \n--------------------");
			char tmp[255], tmp2[255], szSteam[32];
			
			for(int i = 1; i <= MaxClients; i++) {
				if( !IsValidClient(i) )
					continue;
				
				if( rp_GetZoneInt( rp_GetPlayerZone(i), zone_type_type) != 101 ) 
					continue;				
				
				GetClientAuthId(i, AuthId_Engine, szSteam, sizeof(szSteam), false);
				Format(tmp, sizeof(tmp), "%s %s", options, szSteam);
				
				Format(tmp2, sizeof(tmp2), "%N - %s", i, szSteam);
				AddMenuItem(menu, tmp, tmp2);
			}
		}
		else if( StrEqual( options, "disconnect", false) ) {
			
			SetMenuTitle(menu, "  Tribunal - Cas déconnecté \n--------------------");
			PrintToServer("LOCK-3");
			SQL_LockDatabase(DB);
			Handle hQuery = SQL_Query(DB, "SELECT `steamid`, `name` FROM `rp_users` ORDER BY `rp_users`.`last_connected` DESC LIMIT 100;");
			char tmp[255], tmp2[255], szSteam[32], buffer_szSteam[32];
			
			if( hQuery != INVALID_HANDLE ) {
				while( SQL_FetchRow(hQuery) ) {
				
					SQL_FetchString(hQuery, 0, szSteam, sizeof(szSteam));
					SQL_FetchString(hQuery, 1, tmp2, sizeof(tmp2));
					
					bool found = false;
					for(int i = 1; i <= MaxClients; i++) {
						if( !IsValidClient(i) )
							continue;
						
						
						GetClientAuthId(i, AuthId_Engine, buffer_szSteam, sizeof(buffer_szSteam), false);
						
						if( StrEqual(szSteam, buffer_szSteam) ) {
							found = true;
							break;
						}
					}
					
					if( found )
						continue;
					
					Format(tmp, sizeof(tmp), "%s %s", options, szSteam);
					Format(tmp2, sizeof(tmp2), "%s - %s", tmp2, szSteam);
					AddMenuItem(menu, tmp, tmp2);
				}
			}
			
			if( hQuery != INVALID_HANDLE )
				CloseHandle(hQuery);
			SQL_UnlockDatabase(DB);
			PrintToServer("UNLOCK-3");
		}
		else if( StrEqual( options, "stats", false) ) {
			
			SetMenuTitle(menu, "  Tribunal - Stats joueur \n--------------------");
			char tmp[255], tmp2[255], szSteam[32];
			
			for(int i = 1; i <= MaxClients; i++) {
				if( !IsValidClient(i) )
					continue;
				
				if( rp_GetZoneInt( rp_GetPlayerZone(i), zone_type_type) != 101 ) 
					continue;
				
				GetClientAuthId(i, AuthId_Engine, szSteam, sizeof(szSteam), false);
				
				Format(tmp, sizeof(tmp), "%s %s", options, szSteam);
				
				Format(tmp2, sizeof(tmp2), "%N - %s", i, szSteam);
				AddMenuItem(menu, tmp, tmp2);
			}
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_DURATION);
	}
	else if( p_oAction == MenuAction_End ) {
		
		CloseHandle(p_hItemMenu);
	}
}
public int MenuTribunal_selectplayer(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuTribunal_selectplayer");
	#endif
	if( p_oAction == MenuAction_Select && client != 0) {
		char buff_options[255], options[2][64], option[64], szSteamID[64];
		GetMenuItem(p_hItemMenu, p_iParam2, buff_options, 254);
		
		ExplodeString(buff_options, " ", options, sizeof(options), sizeof(options[]));
		strcopy(option, sizeof(option), options[0]);
		strcopy(szSteamID, sizeof(szSteamID), options[1]);
		
		
		char uniqID[64], szIP[64], szQuery[1024];
		String_GetRandom(uniqID, sizeof(uniqID), 32);
		GetClientIP(client, szIP, sizeof(szIP));
		
		Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_tribunal` (`uniqID`, `timestamp`, `steamid`, `IP`) VALUES ('%s', '%i', '%s', '%s');", uniqID, GetTime(), szSteamID, szIP);
		Handle DB = rp_GetDatabase();
		
		PrintToServer("LOCK-1");
		SQL_LockDatabase(DB);
		SQL_Query(DB, szQuery);
		SQL_UnlockDatabase(DB);
		PrintToServer("UNLOCK-1");
		
		char szTitle[128], szURL[512];
		Format(szTitle, sizeof(szTitle), "Tribunal: %s", szSteamID);
		Format(szURL, sizeof(szURL), "http://www.ts-x.eu/popup.php?url=/index.php?page=tribunal&action=case&steamid=%s&tokken=%s", szSteamID, uniqID);
		
		ShowMOTDPanel(client, szTitle, szURL, MOTDPANEL_TYPE_URL);
		
		if( !StrEqual(option, "stats") ) {
			
			Handle menu = CreateMenu(MenuTribunal_Apply);
			SetMenuTitle(menu, "  Tribunal - Sélection de la peine \n--------------------");
			
			char tmp[255], tmp2[255];
			
			for(int i=0; i<=100; i+=2) {
				Format(tmp, sizeof(tmp), "%s %s %i", option, szSteamID, i);
				Format(tmp2, sizeof(tmp2), "%i heures", i);
				AddMenuItem(menu, tmp, tmp2);
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_DURATION*2*10);
		}
	}
	else if( p_oAction == MenuAction_End ) {
		
		CloseHandle(p_hItemMenu);
	}
	
}
public int MenuTribunal_Apply(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuTribunal_Apply");
	#endif
	if( p_oAction == MenuAction_Select && client != 0) {
		char buff_options[255], options[3][64];
		GetMenuItem(p_hItemMenu, p_iParam2, buff_options, 254);
		
		ExplodeString(buff_options, " ", options, sizeof(options), sizeof(options[]));
		
		char random[6];
		String_GetRandom(random, sizeof(random), sizeof(random) - 1);
		
		strcopy(g_szTribunal_DATA[client][tribunal_option], 63, options[0]);
		strcopy(g_szTribunal_DATA[client][tribunal_steamid], 63, options[1]);
		strcopy(g_szTribunal_DATA[client][tribunal_duration], 63, options[2]);
		strcopy(g_szTribunal_DATA[client][tribunal_code], 63, random);
		
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Afin de confirmer votre jugement, tappez maintenant /jugement %s votre raison.", random);
	}
	else if( p_oAction == MenuAction_End ) {
		
		CloseHandle(p_hItemMenu);
	}
}
public int MenuTribunal(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	
	if (p_oAction == MenuAction_Select) {
		
		char szMenuItem[64];
		if( GetMenuItem(p_hItemMenu, p_iParam2, szMenuItem, sizeof(szMenuItem)) ) {
			
			int target = StringToInt(szMenuItem);
			if( !IsValidClient(target) ) {
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Le joueur s'est déconnecté.");
				return;
			}
			
			char uniqID[64], szSteamID[64], szIP[64], szQuery[1024];
			
			String_GetRandom(uniqID, sizeof(uniqID), 32);
			GetClientAuthId(target, AuthId_Engine, szSteamID, sizeof(szSteamID), false);
			GetClientIP(client, szIP, sizeof(szIP));
			
			Handle DB = rp_GetDatabase();
			
			Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_tribunal` (`uniqID`, `timestamp`, `steamid`, `IP`) VALUES ('%s', '%i', '%s', '%s');", uniqID, GetTime(), szSteamID, szIP);
			PrintToServer("LOCK-4");
			SQL_LockDatabase(DB);
			SQL_Query(DB, szQuery);
			SQL_UnlockDatabase(DB);
			PrintToServer("UNLOCK-4");
			char szTitle[128], szURL[512];
			Format(szTitle, sizeof(szTitle), "Tribunal: %N", target);
			Format(szURL, sizeof(szURL), "http://www.ts-x.eu/popup.php?url=/index.php?page=tribunal&action=case&steamid=%s&tokken=%s", szSteamID, uniqID);
			
			ShowMOTDPanel(client, szTitle, szURL, MOTDPANEL_TYPE_URL);
			return;
		}		
	}
	else if (p_oAction == MenuAction_End) {
		CloseHandle(p_hItemMenu);
	}
}
// ----------------------------------------------------------------------------
void SendPlayerToJail(int target, int client = 0) {
	static float fLocation[MAX_LOCATIONS][3];
	char tmp[128];
	
	#if defined DEBUG
	PrintToServer("SendPlayerToJail: %d %d", target, client);
	#endif
	
	rp_ClientGiveItem(client, 1, -rp_GetClientItem(client, 1));
	rp_ClientGiveItem(client, 2, -rp_GetClientItem(client, 2));
	rp_ClientGiveItem(client, 3, -rp_GetClientItem(client, 3));
	
	int MaxJail = 0;	
	float MinHull[3], MaxHull[3];
	GetEntPropVector(target, Prop_Send, "m_vecMins", MinHull);
	GetEntPropVector(target, Prop_Send, "m_vecMaxs", MaxHull);
	
	for (int j = 0; j <= 1; j++) {
		for( int i=0; i<MAX_LOCATIONS; i++ ) {
			rp_GetLocationData(i, location_type_base, tmp, sizeof(tmp));
			if( StrEqual(tmp, "jail", false) ) {
				
				fLocation[MaxJail][0] = float(rp_GetLocationInt(i, location_type_origin_x));
				fLocation[MaxJail][1] = float(rp_GetLocationInt(i, location_type_origin_y));
				fLocation[MaxJail][2] = float(rp_GetLocationInt(i, location_type_origin_z)) + 5.0;
				
				MaxJail++;
				
				if( j == 0 ) {
					Handle tr = TR_TraceHullFilterEx(fLocation[MaxJail], fLocation[MaxJail], MinHull, MaxHull, MASK_PLAYERSOLID, TraceRayDontHitSelf, target);
					if( TR_DidHit(tr) ) {
						CloseHandle(tr);
						MaxJail--;
						continue;
					}
					CloseHandle(tr);
				}
			}
		}
		if( MaxJail > 0 )
			break;
	}
	
	if( MaxJail == 0 ) {
		LogToGame("DEBUG ---> AUCUNE JAIL DISPO TROUVEE OMG");
	}
	
	if( GetClientTeam(target) == CS_TEAM_CT ) {
		CS_SwitchTeam(target, CS_TEAM_T);
	}
	
	Entity_SetModel(target, MODEL_PRISONNIER);
	
	if( IsValidClient(client) ) {
		
		
		if( !IsValidClient(rp_GetClientInt(target, i_JailledBy)) )
			rp_SetClientInt(target, i_JailledBy, client);
		
		
		CPrintToChat(target, "{lightblue}[TSX-RP]{default} %N vous a mis en prison.", client);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez mis %N en prison.", target);
		
		AskJailTime(client, target);
		LogToGame("[TSX-RP] [JAIL-0] %L (%d) a mis %L (%d) en prison.", client, rp_GetPlayerZone(client, 1.0), target, rp_GetPlayerZone(target, 1.0));
		
	}
	
	int rand = Math_GetRandomInt(0, (MaxJail-1));
	TeleportEntity(target, fLocation[rand], NULL_VECTOR, NULL_VECTOR);
	FakeClientCommandEx(target, "sm_stuck");
}
// ----------------------------------------------------------------------------
void AskJailTime(int client, int target) {
	char tmp[256], tmp2[12];
	
	Handle menu = CreateMenu(eventSetJailTime);
	Format(tmp, 255, "Combien de temps doit rester %N?", target);	
	SetMenuTitle(menu, tmp);
	
	Format(tmp, 255, "%d_-1", target);
	AddMenuItem(menu, tmp, "Annuler la peine / Liberer");
	
	if( rp_GetClientJobID(client) == 101 ) {
		Format(tmp, 255, "%d_-3", target);
		AddMenuItem(menu, tmp, "Jail Tribunal N°1");
		Format(tmp, 255, "%d_-2", target);
		AddMenuItem(menu, tmp, "Jail Tribunal N°2");
	}
	
	for(int i=0; i<sizeof(g_szJailRaison); i++) {
		
		Format(tmp2, sizeof(tmp2), "%d_%d", target, i);
		AddMenuItem(menu, tmp2, g_szJailRaison[i][jail_raison]);
	}
	
	SetMenuExitButton(menu, true);
	
	DisplayMenu(menu, client, MENU_TIME_DURATION);	
}
public int eventAskJail2Time(Handle menu, MenuAction action, int client, int param2) {
	
	if( action == MenuAction_Select ) {
		char options[64];
		GetMenuItem(menu, param2, options, 63);
		
		char data[2][32];
		
		ExplodeString(options, "_", data, sizeof(data), sizeof(data[]));
		
		int iTarget = StringToInt(data[0]);
		int iTime = StringToInt(data[1]);
		
		if( iTime < 0 ) {
			AskJailTime(client, iTarget);
			
			
			if( rp_GetClientInt(iTarget, i_JailTime) <= 60 )
				rp_SetClientInt(iTarget, i_JailTime, 1*60);
			
			SendPlayerToJail(iTarget);
		}
		else {
			
			SendPlayerToJail(iTarget);
			rp_SetClientInt(iTarget, i_JailTime,iTime*60);		
			rp_SetClientInt(iTarget, i_JailledBy, client);
			
			CPrintToChatAll("{lightblue}[TSX-RP]{default} %N a été condamne à faire %i heures de prison par le juge %N.", iTarget, iTime, client);
			LogToGame("[TSX-RP] [JUGE] %L a été condamne à faire %i heures de prison par le juge %L.", iTarget, iTime, client);
		}
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
public int eventSetJailTime(Handle menu, MenuAction action, int client, int param2) {
	char options[64], data[2][32], szQuery[1024];
	
	if( action == MenuAction_Select ) {
		
		
		GetMenuItem(menu, param2, options, 63);		
		ExplodeString(options, "_", data, sizeof(data), sizeof(data[]));
		
		int target = StringToInt(data[0]);
		int type = StringToInt(data[1]);
		int time_to_spend;
		int jobID = rp_GetClientJobID(client);
		//FORCE_Release(iTarget);
		
		if( type == -1 ) {
			rp_SetClientInt(target, i_JailTime, 0);
			rp_SetClientInt(target, i_jailTime_Last, 0);
			rp_SetClientInt(target, i_JailledBy, 0);
			
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez libéré %N.", target);
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} %N vous a liberé.", client);
			
			LogToGame("[TSX-RP] [JAIL] [LIBERATION] %L a liberé %L", client, target);
			
			rp_ClientResetSkin(target);
			rp_ClientSendToSpawn(target, true);
			return;
		}
		if( type == -2 || type == -3 ) {
			
			if( type == -3 )
				TeleportEntity(target, view_as<float>{-276.0, -276.0, -1980.0}, NULL_VECTOR, NULL_VECTOR);
			else
				TeleportEntity(target, view_as<float>{632.0, -1258.0, -1980.0}, NULL_VECTOR, NULL_VECTOR);
			
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} Vous avez été mis en prison, en attente de jugement par: %N", client);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez mis: %N en prison du Tribunal.", target);
			
			if( rp_GetClientInt(target, i_JailTime) <= 360 )
				rp_SetClientInt(target, i_JailTime, 360);
			
			LogToGame("[TSX-RP] [TRIBUNAL] %L a mis %L en prison du Tribunal.", client, target);
			return;
		}
		
		
		int amende = StringToInt(g_szJailRaison[type][jail_amende]);
		
		if( amende == -1 )
			amende = rp_GetClientInt(target, i_KillingSpread) * 200;
		
		if( String_StartsWith(g_szJailRaison[type][jail_raison], "Vol") ) {
			amende += rp_GetClientInt(target, i_LastVolAmount);
			if( IsValidClient( rp_GetClientInt(target, i_LastVolTarget) ) ) {
				int tg = rp_GetClientInt(target, i_LastVolTarget);
				rp_SetClientInt(tg, i_Money, rp_GetClientInt(tg, i_Money) + rp_GetClientInt(target, i_LastVolAmount));
			}
		}
		else {
			amendeCalculation(target, amende);
		}
		
		if( rp_GetClientInt(target, i_Money) >= amende || (
			(rp_GetClientInt(target, i_Money)+rp_GetClientInt(target, i_Bank)) >= amende*250 && amende <= 2500) ) {
			
			rp_SetClientInt(target, i_Money, rp_GetClientInt(target, i_Money) - amende);
			rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) + (amende / 4));
			rp_SetJobCapital(jobID, rp_GetJobCapital(jobID) + (amende/4 * 3));
			
			GetClientAuthId(client, AuthId_Engine, options, sizeof(options), false);
			
			Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '4', '%i', '%s', '%i');",
			options, jobID, GetTime(), 0, "Caution", amende/4);
			
			SQL_TQuery( rp_GetDatabase(), SQL_QueryCallBack, szQuery);
			
			time_to_spend = StringToInt(g_szJailRaison[type][jail_temps]);
			if( time_to_spend == -1 ) {
				float kill = float(rp_GetClientInt(target, i_KillingSpread));
				time_to_spend = RoundToCeil(Logarithm(kill + 1.0) * 4.0 * kill + 4.0); // Mais oui, c'est claire !
				
				if( kill <= 0.0 )
					time_to_spend = 2;
				rp_SetClientInt(target, i_FreekillSick, 0);
				
				time_to_spend /= 2;
			}
			
			
			if( amende > 0 ) {
				
				if( IsValidClient(target) ) {
					CPrintToChat(client, "{lightblue}[TSX-RP]{default} Une amende de %i$ a été prélevée à %N.", amende, target);
					CPrintToChat(target, "{lightblue}[TSX-RP]{default} Une caution de %i$ vous a été prelevée.", amende);
				}
			}
		}
		else {
			time_to_spend = StringToInt(g_szJailRaison[type][jail_temps_nopay]);
			if( time_to_spend == -1 ) {
				float kill = float(rp_GetClientInt(target, i_KillingSpread));
				time_to_spend = RoundToCeil(Logarithm(kill + 1.0) * 4.0 * kill + 4.0); // Mais oui, c'est claire !
				
				if( kill <= 0.0 )
					time_to_spend = 2;
				rp_SetClientInt(target, i_FreekillSick, 0);	
			}
			
			
			else if ( rp_GetClientInt(target, i_Bank) >= amende && time_to_spend != -2 ) {
				WantPayForLeaving(target, client, type, amende);
			}
		}
		
		if( time_to_spend < 0 ) {
			time_to_spend = rp_GetClientInt(target, i_JailTime) + (6 * 60);
		}
		else {
			rp_SetClientInt(target, i_jailTime_Reason, type);
			time_to_spend *= 60;
		}
		
		rp_SetClientInt(target, i_JailTime, time_to_spend);
		rp_SetClientInt(target, i_jailTime_Last, time_to_spend);
		 
		if( IsValidClient(client) && IsValidClient(target) ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} %N restera en prison %.1f heures pour \"%s\"", target, time_to_spend/60.0, g_szJailRaison[type][jail_raison]);
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} %N vous a mis %.1f heures de prison pour \"%s\"", client, time_to_spend/60.0, g_szJailRaison[type][jail_raison]); 
		}
		else {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Le joueur s'est fait la male...");
		}
		
		LogToGame("[TSX-RP] [JAIL-1] %L (%d) a mis %L (%d) en prison: Raison %s.", client, rp_GetPlayerZone(client, 1.0), target, rp_GetPlayerZone(target, 1.0), g_szJailRaison[type][jail_raison]);
		
		if( time_to_spend <= 1 ) {
			rp_ClientResetSkin(target);
			rp_ClientSendToSpawn(target, true);
		}
		else {
			StripWeapons(target);
		}
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
void WantPayForLeaving(int client, int police, int type, int amende) {
	#if defined DEBUG
	PrintToServer("WantPayForLeaving");
	#endif

	// Setup menu
	Handle menu = CreateMenu(eventPayForLeaving);
	char tmp[256];
	Format(tmp, 255, "Vous avez été mis en prison pour \n %s\nUne caution de %i$ vous est demandé", g_szJailRaison[type][jail_raison], amende);	
	SetMenuTitle(menu, tmp);
	
	Format(tmp, 255, "%i_%i_%i", police, type, amende);
	AddMenuItem(menu, tmp, "Oui, je souhaite payer ma caution");
	
	Format(tmp, 255, "0_0_0");
	AddMenuItem(menu, tmp, "Non, je veux rester plus longtemps");
	
	
	SetMenuExitButton(menu, false);
	
	DisplayMenu(menu, client, MENU_TIME_DURATION);
}
public int eventPayForLeaving(Handle menu, MenuAction action, int client, int param2) {
	#if defined DEBUG
	PrintToServer("eventPayForLeaving");
	#endif
	if( action == MenuAction_Select ) {
		char options[64], data[3][32], szQuery[2048];
		
		GetMenuItem(menu, param2, options, 63);
		
		ExplodeString(options, "_", data, sizeof(data), sizeof(data[]));
		
		
		int target = StringToInt(data[0]);
		int type = StringToInt(data[1]);
		int amende = StringToInt(data[2]);
		int jobID = rp_GetClientJobID(target);
		
		if( target == 0 && type == 0 && amande == 0)
			return;
		
		int time_to_spend = 0;
		rp_SetClientInt(client, i_Money, rp_GetClientInt(client, i_Money) - amende);
		rp_SetClientInt(target, i_AddToPay, rp_GetClientInt(target, i_AddToPay) + (amende / 4));
		rp_SetJobCapital(jobID, rp_GetJobCapital(jobID) + (amende/4 * 3));
			
		GetClientAuthId(client, AuthId_Engine, options, sizeof(options), false);
			
		Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '4', '%i', '%s', '%i');",
		options, jobID, GetTime(), 0, "Caution", amende/4);
			
		SQL_TQuery( rp_GetDatabase(), SQL_QueryCallBack, szQuery);
			
		time_to_spend = StringToInt(g_szJailRaison[type][jail_temps]);
		if( time_to_spend == -1 ) {
			float kill = float(rp_GetClientInt(target, i_KillingSpread));
			time_to_spend = RoundToCeil(Logarithm(kill + 1.0) * 4.0 * kill + 4.0); // Mais oui, c'est claire !
			
			if( kill <= 0.0 )
				time_to_spend = 2;
			rp_SetClientInt(target, i_FreekillSick, 0);
			
			time_to_spend /= 2;
		}
			
			
		if( IsValidClient(target) ) {
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} Une amende de %i$ a été prélevée à %N.", amende, client);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Une caution de %i$ vous a été prelevée.", amende);
		}
		
		time_to_spend *= 60;
		rp_SetClientInt(client, i_JailTime, time_to_spend);
		rp_SetClientInt(client, i_jailTime_Last, time_to_spend);
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
// ----------------------------------------------------------------------------
void amendeCalculation(int client, int& amende) {
	int current = rp_GetClientInt(client, i_Money) + rp_GetClientInt(client, i_Bank);
	
	if( current > 10000 )
		amende += (((current)-10000)/4000);	
}
int GetPerquizResp(int job_id) {
	
	int zone;
	
	for(int i=1; i<=MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
			
		zone = rp_GetZoneBit(rp_GetPlayerZone(i));
		if( zone & BITZONE_JAIL ||  zone & BITZONE_LACOURS ||  zone & BITZONE_HAUTESECU )
			continue;
		
		if( job_id == rp_GetClientInt(i, i_Job) )
			return i;
	}
	
	int min = 9999;
	int res = 0;
	for(int i=1; i<=MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
		zone = rp_GetZoneBit(rp_GetPlayerZone(i));
		if( zone & BITZONE_JAIL ||  zone & BITZONE_LACOURS ||  zone & BITZONE_HAUTESECU )
			continue;
			
		if( job_id == rp_GetJobInt( rp_GetClientInt(i, i_Job),  job_type_ownboss) ) {
			if( min > rp_GetClientInt(i, i_Job) ) {
				min = rp_GetClientInt(i, i_Job);
				res = i;
			}
		}
	}
	
	
	return res;
}
// ----------------------------------------------------------------------------
public int MenuPerquiz(Handle menu, MenuAction action, int client, int param2) {
	
	if( action == MenuAction_Select ) {
		char options[64];
		GetMenuItem(menu, param2, options, 63);
		
		
		int job_id = rp_GetZoneInt(rp_GetPlayerZone(GetClientTarget(client)), zone_type_type);
		
		if( job_id <= 0 || job_id > 250 ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cette porte ne peut pas être perquisitionnée.");
			return;
		}
		
		if( StrEqual(options, "start") ) {
			g_iCancel[client] = 0;
			start_perquiz(client, job_id);
		}
		else if( StrEqual(options, "cancel") ) {
			cancel_perquiz(client, job_id);
			g_iCancel[client] = 1;
		}
		else if( StrEqual(options, "stop") ) {
			end_perquiz(client, job_id);
		}
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
void start_perquiz(int client, int job) {
	
	int REP = GetPerquizResp(job);
	
	Handle dp;
	CreateDataTimer(10.0, PerquizFrame, dp, TIMER_DATA_HNDL_CLOSE);
	WritePackCell(dp, (60*1) + 10);
	WritePackCell(dp, client);
	WritePackCell(dp, job);
	WritePackCell(dp, REP);
	
	char tmp[255];
	rp_GetZoneData(JobToZoneID(job), zone_type_name, tmp, sizeof(tmp));
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	CPrintToChatAll("{lightblue}[TSX-RP] [POLICE]{default} Début d'une perquisition dans: %s.", tmp);
	LogToGame("[TSX-RP] [POLICE] Début d'une perquisition dans: %s.", tmp);
	
	if( REP > 0 )
		CPrintToChatAll("{lightblue}[TSX-RP] [POLICE]{default} %N est prié de se présenter sur les lieux.", REP);
	CPrintToChatAll("{lightblue} ================================== {default}");
	
	rp_SetJobCapital(1, rp_GetJobCapital(1) + 250);
}
void begin_perquiz(int client, int job) {
	char tmp[255];
	rp_GetZoneData(JobToZoneID(job), zone_type_name, tmp, sizeof(tmp));
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	CPrintToChatAll("{lightblue}[TSX-RP] [POLICE]{default} Début d'une perquisition dans: %s.", tmp);
	LogToGame("[TSX-RP] [POLICE] Début d'une perquisition dans: %s.", tmp);
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	
	
	rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) + 500);
	rp_SetJobCapital(1, rp_GetJobCapital(1) + 250);
	
}
void end_perquiz(int client, int job) {
	char tmp[255];
	rp_GetZoneData(JobToZoneID(job), zone_type_name, tmp, sizeof(tmp));
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	CPrintToChatAll("{lightblue}[TSX-RP] [POLICE]{default} Fin d'une perquisition dans: %s.", tmp);
	LogToGame("[TSX-RP] [POLICE] Fin d'une perquisition dans: %s.", tmp);
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	
	rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) + 500);
	rp_SetJobCapital(1, rp_GetJobCapital(1) + 500);
	
	char szQuery[1024], szSteamID[64];
	GetClientAuthId(client, AuthId_Engine, szSteamID, sizeof(szSteamID), false);
	
	Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_perquiz` (`id`, `job`, `time`, `steamid`) VALUES (NULL, '%i', UNIX_TIMESTAMP(), '%s');", job, szSteamID);
	
	SQL_TQuery(rp_GetDatabase(), SQL_QueryCallBack, szQuery);
}
void cancel_perquiz(int client, int job) {
	char tmp[255];
	rp_GetZoneData(JobToZoneID(job), zone_type_name, tmp, sizeof(tmp));
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	CPrintToChatAll("{lightblue}[TSX-RP] [POLICE]{default} Annulation d'une perquisition dans: %s.", tmp);
	LogToGame("[TSX-RP] [POLICE] Annulation d'une perquisition dans: %s.", tmp);
	
	CPrintToChatAll("{lightblue} ================================== {default}");
	
	rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) - 500);
	rp_SetJobCapital(1, rp_GetJobCapital(1) - 250);
}
public Action PerquizFrame(Handle timer, Handle dp) {
	
	ResetPack(dp);
	int time = ReadPackCell(dp) - 10;
	int client = ReadPackCell(dp);
	int job = ReadPackCell(dp);
	int target = ReadPackCell(dp);
	
	char tmp[255];
	rp_GetZoneData(JobToZoneID(job), zone_type_name, tmp, sizeof(tmp));
	
	if( !IsValidClient(client) ) {
		cancel_perquiz(0, job);
		return Plugin_Handled;
	}
	
	if( g_iCancel[client] ) {
		g_iCancel[client] = 0;
		return Plugin_Handled;
	}
	if( !IsValidClient(target) || target == 0 ) {
		begin_perquiz(client, job);
		return Plugin_Handled;
	}
	
	int zone = rp_GetZoneInt(rp_GetPlayerZone(target), zone_type_type);
	
	if( zone == job || rp_IsEntitiesNear(client, target) || time <= 0 ) {
		begin_perquiz( client, job );
		return Plugin_Handled;
	}
		
	CPrintToChat(target, "{lightblue} ================================== {default}");
	CPrintToChat(target, "{lightblue}[TSX-RP] [POLICE]{default} une perquisition commencera dans: %i secondes", time);
	CPrintToChat(target, "{lightblue}[TSX-RP] [POLICE]{default} %N est prié de se présenter à %s.", target, tmp);
	CPrintToChat(target, "{lightblue} ================================== {default}");
	
	CPrintToChat(client, "{lightblue} ================================== {default}");
	CPrintToChat(client, "{lightblue}[TSX-RP] [POLICE]{default} une perquisition commencera dans: %i secondes", time);
	CPrintToChat(client, "{lightblue}[TSX-RP] [POLICE]{default} %N est prié de se présenter à %s", target, tmp);
	CPrintToChat(client, "{lightblue} ================================== {default}");
	
	
	CreateDataTimer(10.0, PerquizFrame, dp, TIMER_DATA_HNDL_CLOSE);
	WritePackCell(dp, time);
	WritePackCell(dp, client);
	WritePackCell(dp, job);
	WritePackCell(dp, GetPerquizResp(job));
	
	return Plugin_Continue;
}
// ----------------------------------------------------------------------------
public Action AllowStealing(Handle timer, any client) {
	rp_SetClientBool(client, b_MaySteal, true);
}
public int MenuNothing(Handle menu, MenuAction action, int client, int param2) {
	if( action == MenuAction_Select ) {
		if( menu != INVALID_HANDLE )
			CloseHandle(menu);
	}
	else if( action == MenuAction_End ) {
		if( menu != INVALID_HANDLE )
			CloseHandle(menu);
	}
}
public Action fwdFrozen(int client, float& speed, float& gravity) {
	speed = 0.0;
	return Plugin_Stop;
}
public Action fwdTazerBlue(int client, int color[4]) {
	color[0] -= 50;
	color[1] -= 50;
	color[2] += 255;
	color[3] += 50;
	return Plugin_Changed;
}
public bool TraceRayDontHitSelf(int entity, int mask, any data) {
	if(entity == data) {
		return false;
	}
	return true;
}
int JobToZoneID(int job) {
	static int last;
	
	if( rp_GetZoneInt(last, zone_type_type) == job ) {
		return last;
	}
	
	for(int i=1; i<300; i++) {	
		if( rp_GetZoneInt(i, zone_type_type) == job  ) {
			last = i;
			return i;
		}
	}
	return 0;
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemRatio(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemRatio");
	#endif
	char arg1[12];
	GetCmdArg(1, arg1, sizeof(arg1));
	int client = GetCmdArgInt(2);

	if( StrEqual(arg1, "own") ) {
		char steamid[64];
		GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid), false);
		displayTribunal(client, steamid);
	}
	else if( StrEqual(arg1, "target") ) {
		if( rp_GetClientJobID(client) != 1 && rp_GetClientJobID(client) != 101 ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cet objet est réservé aux forces de l'ordre.");
			return;
		}
		CreateTimer(0.25, task_RatioTarget, client);
	}
	else if( StrEqual(arg1, "gps") ) {
		rp_ClientGiveItem(client, ITEM_GPS);
		CreateTimer(0.25, task_GPS, client);
	}
}
public Action task_RatioTarget(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("task_RatioTarget");
	#endif
	
	Handle menu = CreateMenu(MenuTribunal_selectplayer);
	SetMenuTitle(menu, "  Tribunal - Stats joueur \n--------------------");
	char tmp[255], tmp2[255], szSteam[32];
	
	for(int i = 1; i <= MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
		
		if( Entity_GetDistance(client, i) > MAX_AREA_DIST.0 )
			continue;
		
		GetClientAuthId(i, AuthId_Engine, szSteam, sizeof(szSteam), false);
		
		Format(tmp, sizeof(tmp), "stats %s", szSteam);
		
		Format(tmp2, sizeof(tmp2), "%N - %s", i, szSteam);
		AddMenuItem(menu, tmp, tmp2);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);
}
public Action task_GPS(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("task_GPS");
	#endif
	Handle menu = CreateMenu(MenuTribunal_GPS);
	SetMenuTitle(menu, "  GPS \n--------------------");
	char tmp[255], tmp2[255];
	
	for(int i = 1; i <= MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
		
		Format(tmp, sizeof(tmp), "%d", i);
		Format(tmp2, sizeof(tmp2), "%N", i);
		
		AddMenuItem(menu, tmp, tmp2);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_DURATION);
}
public int MenuTribunal_GPS(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuTribunal_GPS");
	#endif
	
	if( p_oAction == MenuAction_Select && client != 0) {
		char option[32];
		GetMenuItem(p_hItemMenu, p_iParam2, option, sizeof(option));
		int target = StringToInt(option);
		
		
		if( rp_GetClientItem(client, ITEM_GPS) <= 0 ) {
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} Vous n'avez plus de GPS.");
			return;
		}
		
		rp_ClientGiveItem(client, ITEM_GPS, -1);
		
		if( Math_GetRandomInt(1, 100) < rp_GetClientInt(target, i_Cryptage)*20 ) {
			
			CPrintToChat(target, "{lightblue}[TSX-RP]{default} Votre pot de vin envers un détective privé vient de vous sauver.");
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Un pot de vin envers un détective privé vient de le sauver...");
			
		}
		else {
			rp_SetClientInt(client, i_GPS, target);
		}
	}
	else if( p_oAction == MenuAction_End ) {
		CloseHandle(p_hItemMenu);
	}
	
}
// ----------------------------------------------------------------------------
void displayTribunal(int client, const char szSteamID[64]) {
	#if defined DEBUG
	PrintToServer("displayTribunal");
	#endif
	char uniqID[64], szIP[64], szTitle[128], szURL[512], szQuery[1024];
	
	String_GetRandom(uniqID, sizeof(uniqID));
	GetClientIP(client, szIP, sizeof(szIP));
	
	Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_tribunal` (`uniqID`, `timestamp`, `steamid`, `IP`) VALUES ('%s', '%i', '%s', '%s');", uniqID, GetTime(), szSteamID, szIP);
	
	Handle DB = rp_GetDatabase();
	
	SQL_LockDatabase(DB);
	SQL_Query(DB, szQuery);
	SQL_UnlockDatabase(DB);
	
	
	Format(szTitle, sizeof(szTitle), "Tribunal: %s", szSteamID);
	Format(szURL, sizeof(szURL), "http://www.ts-x.eu/popup.php?url=/index.php?page=tribunal&action=case&steamid=%s&tokken=%s", szSteamID, uniqID);
	
	ShowMOTDPanel(client, szTitle, szURL, MOTDPANEL_TYPE_URL);
}
// ----------------------------------------------------------------------------

public Action Cmd_ItemPickLock(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemPickLock");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	
	rp_ClientReveal(client);
	
	if( rp_GetClientJobID(client) != 1 &&  rp_GetClientJobID(client) != 101 ) {
		return Plugin_Continue;
	}
	
	int door = GetClientAimTarget(client, false);
	
	if( !rp_IsValidDoor(door) && IsValidEdict(door) && rp_IsValidDoor(Entity_GetParent(door)) )
		door = Entity_GetParent(door);
		

		
	if( !rp_IsValidDoor(door) || !rp_IsEntitiesNear(client, door, true) ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous devez viser une porte.");
		return Plugin_Handled;
	}
	
	float time = 0.5;
	
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdFrozen, time);
	ServerCommand("sm_effect_panel %d %f \"Crochetage de la porte...\"", client, time);
	
	rp_ClientColorize(client, { 255, 0, 0, 255} );
	rp_ClientReveal(client);
	
	Handle dp;
	CreateDataTimer(time-0.25, ItemPickLockOver_mandat, dp, TIMER_DATA_HNDL_CLOSE); 
	WritePackCell(dp, client);
	WritePackCell(dp, door);
	
	return Plugin_Handled;
}
public Action ItemPickLockOver_mandat(Handle timer, Handle dp) {
	
	if( dp == INVALID_HANDLE ) {
		return Plugin_Handled;
	}
	
	ResetPack(dp);
	int client 	 = ReadPackCell(dp);
	int door = ReadPackCell(dp);
	int doorID = rp_GetDoorID(door);
	
	rp_ClientColorize(client);
	
	if( !rp_IsEntitiesNear(client, door, true) ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez raté votre tentative de crochetage, vous étiez trop loin de la porte...");
		return Plugin_Handled;
	}

	rp_SetDoorLock(doorID, false); 
	rp_ClientOpenDoor(client, doorID, true);

	float vecOrigin[3], vecOrigin2[3];
	Entity_GetAbsOrigin(door, vecOrigin);
	
	for (int i = 1; i <= MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
		
		Entity_GetAbsOrigin(i, vecOrigin2);
		
		if( GetVectorDistance(vecOrigin, vecOrigin2) > MAX_AREA_DIST.0 )
			continue;
		
		CPrintToChat(i, "{lightblue}[TSX-RP]{default} La porte a été ouverte avec un mandat.");
	}
	
	return Plugin_Continue;
}
// ----------------------------------------------------------------------------
void StripWeapons(int client ) {
	int wepIdx;
	
	for( int i = 0; i < 5; i++ ){
		if( i == CS_SLOT_KNIFE ) continue; 
		
		while( ( wepIdx = GetPlayerWeaponSlot( client, i ) ) != -1 ) {
			RemovePlayerItem( client, wepIdx );
			RemoveEdict( wepIdx );
		}
	}
	
	FakeClientCommand(client, "use weapon_knife");
}