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
#include <sdkhooks>
#include <colors_csgo>	// https://forums.alliedmods.net/showthread.php?p=2205447#post2205447
#include <smlib>		// https://github.com/bcserv/smlib

#define __LAST_REV__ 		"v:0.1.0"

#pragma newdecls required
#include <roleplay.inc>	// https://www.ts-x.eu

StringMap g_hReceipe;
bool g_bCanCraft[65][MAX_ITEMS];

//#define DEBUG

int lstJOB[] =  { 11, 21, 31, 41, 51, 61, 71, 81, 111, 121, 131, 171, 191, 211, 221 };

public Plugin myinfo = {
	name = "Jobs: ARTISAN", author = "KoSSoLaX",
	description = "RolePlay - Jobs: Artisan",
	version = __LAST_REV__, url = "https://www.ts-x.eu"
};

enum craft_type {
	craft_raw,
	craft_amount,
	craft_rate,
	craft_type_max
}
// ----------------------------------------------------------------------------
public Action Cmd_Reload(int args) {
	char name[64];
	GetPluginFilename(INVALID_HANDLE, name, sizeof(name));
	ServerCommand("sm plugins reload %s", name);
	return Plugin_Continue;
}
public void OnPluginStart() {
	RegServerCmd("rp_quest_reload", Cmd_Reload);
	RegConsoleCmd("rp_givemepoint", CmdGivePoint);
	
	SQL_TQuery(rp_GetDatabase(), SQL_LoadReceipe, "SELECT `itemid`, `raw`, `amount`, REPLACE(`extra_cmd`, 'rp_item_primal ', '') `rate` FROM `rp_csgo`.`rp_craft` C INNER JOIN `rp_items` I ON C.`raw`=I.`id` ORDER BY `itemid`, `raw`", 0, DBPrio_Low);
	
	for (int i = 1; i <= MaxClients; i++)
		if( IsValidClient(i) )
			OnClientPostAdminCheck(i);
}
public Action CmdGivePoint(int client, int args) {
	rp_SetClientInt(client, i_ArtisanPoints, rp_GetClientInt(client, i_ArtisanPoints) + 1);
	return Plugin_Handled;
}
public void SQL_LoadReceipe(Handle owner, Handle hQuery, const char[] error, any client) {
	if( g_hReceipe ) {
		g_hReceipe.Clear();
		delete g_hReceipe;
	}
	g_hReceipe = new StringMap();
	
	int data[craft_type_max];
	char itemID[12];
	ArrayList magic;
	
	while( SQL_FetchRow(hQuery) ) {
		SQL_FetchString(hQuery, 0, itemID, sizeof(itemID));
		data[craft_raw] = SQL_FetchInt(hQuery, 1);
		data[craft_amount] = SQL_FetchInt(hQuery, 2);
		data[craft_rate] = SQL_FetchInt(hQuery, 3);
		
		if( !g_hReceipe.GetValue(itemID, magic) ) {
			magic = new ArrayList(sizeof(data), 0);
			g_hReceipe.SetValue(itemID, magic);
		}
		magic.PushArray(data, sizeof(data));
	}
	return;
}
public void OnClientPostAdminCheck(int client) {
	#if defined DEBUG
	PrintToServer("OnClientPostAdminCheck");
	#endif
	
	rp_HookEvent(client, RP_OnPlayerUse, fwdUse);
	for(int i = 0; i < MAX_ITEMS; i++)
		g_bCanCraft[client][i] = false;
	
	char szSteamID[65], query[1024];
	GetClientAuthId(client, AuthId_Engine, szSteamID, sizeof(szSteamID));
	Format(query, sizeof(query), "SELECT `itemid` FROM `rp_craft_book` WHERE `steamid`='%s' AND `itemid`>0 AND `itemid`<%d;", szSteamID, MAX_ITEMS);
	SQL_TQuery(rp_GetDatabase(), SQL_LoadCraftbook, query, client);
}
public void SQL_LoadCraftbook(Handle owner, Handle hQuery, const char[] error, any client) {
	while( SQL_FetchRow(hQuery) ) {
		g_bCanCraft[client][SQL_FetchInt(hQuery, 0)] = true;
	}
}
public Action fwdUse(int client) {
	if( rp_GetZoneInt(rp_GetPlayerZone(client), zone_type_type) == 31 ) {
		int target = GetClientTarget(client);
		
		if( IsValidEdict(target) && IsValidEntity(target) ) {
			if( rp_IsValidDoor(target) )
				return Plugin_Continue;
			char classname[65];
			GetEdictClassname(target, classname, sizeof(classname));
			if( StrContains(classname, "rp_bank_") == 0 ) {
				return Plugin_Continue;
			}
		}
		displayArtisanMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
void displayArtisanMenu(int client) {
	#if defined DEBUG
	PrintToServer("displayArtisanMenu");
	#endif
	
	Handle menu = CreateMenu(eventArtisanMenu);
	SetMenuTitle(menu, "== Artisanat ==");
	
	AddMenuItem(menu, "build", 	"Constuire");
	AddMenuItem(menu, "recycl", "Recycler");
	AddMenuItem(menu, "learn", 	"Apprendre");
	AddMenuItem(menu, "book", 	"Livre des recettes");
	AddMenuItem(menu, "stats", 	"Vos informations"); // Niveau, XP, fatigue, ... 
	
	
	for (int i = 0; i <= 100; i++) {
		char tmp[43], tmp2[64];
		getLoadingBar2(tmp, sizeof(tmp), i / 100.0);
		Format(tmp2, sizeof(tmp2)-1, "%s   = %d", tmp, i);
		AddMenuItem(menu, tmp2, tmp2);
	}
	
	
	DisplayMenu(menu, client, 30);
}
void displayBuildMenu(int client, int jobID, int itemID) {
	if( rp_GetClientInt(client, i_ItemCount) == 0 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous n'avez aucune matière première.");
		return;
	}
	
	int clientItem[MAX_ITEMS], data[craft_type_max];
	for(int i = 0; i < MAX_ITEMS; i++)
		clientItem[i] = rp_GetClientItem(client, i);
	
	char tmp[64], tmp2[64], prettyJob[2][64];
	bool can;
	ArrayList magic;
	
	Handle menu = CreateMenu(eventArtisanMenu);
	if( jobID == 0 ) {
		SetMenuTitle(menu, "== Artisanat: Constuire");
		AddMenuItem(menu, "build -1", "Tous les jobs");
		
		for (int i = 0; i < sizeof(lstJOB); i++) {
			
			rp_GetJobData(lstJOB[i], job_type_name, tmp, sizeof(tmp));
			ExplodeString(tmp, " - ", prettyJob, sizeof(prettyJob), sizeof(prettyJob[]));
			Format(tmp, sizeof(tmp), "build %d", lstJOB[i]);
			AddMenuItem(menu, tmp, prettyJob[1]);
		}
	}
	else if( itemID == 0 ) {
		SetMenuTitle(menu, "== Artisanat: Constuire");
		
		for(int i = 0; i < MAX_ITEMS; i++) {
			if( !g_bCanCraft[client][i] )
				continue;
			if( rp_GetItemInt(i, item_type_job_id) != jobID && jobID != -1 )
				continue;
			Format(tmp, sizeof(tmp), "%d", i);
			if( !g_hReceipe.GetValue(tmp, magic) )
				continue;
			
			can = true;
			
			for (int j = 0; j < magic.Length; j++) {
				magic.GetArray(j, data);
				
				if( clientItem[data[craft_raw]] < data[craft_amount] ) {
					can = false;
					break;
				}
			}
			
			rp_GetItemData(i, item_type_name, tmp2, sizeof(tmp2));
			if( can ) {
				Format(tmp, sizeof(tmp), "build %d %d", jobID, i);
			}
			else {
				Format(tmp, sizeof(tmp), "book %d %d", jobID, i);
				Format(tmp2, sizeof(tmp2), "%s - M.P. insuffisante", tmp2);
			}
			
			AddMenuItem(menu, tmp, tmp2);
		}
	}
	else {
		
		rp_GetItemData(itemID, item_type_name, tmp2, sizeof(tmp2));
		Format(tmp2, sizeof(tmp2), "== Artisanat: Construire: %s", tmp2);
		SetMenuTitle(menu, tmp2);
		
		Format(tmp, sizeof(tmp), "%d", itemID);
		if( !g_hReceipe.GetValue(tmp, magic) )
			return;
		
		int min = 999999999, delta;
		float duration = getDuration(itemID);
		
		for (int j = 0; j < magic.Length; j++) { // Pour chaque items de la recette:
			magic.GetArray(j, data);
			
			delta = clientItem[data[craft_raw]] / data[craft_amount];
			if( delta < min )
				min = delta;
		}
		
		for (int i = 1; i <= min; i++) {
			Format(tmp, sizeof(tmp), "build %d %d %d", jobID, itemID, i);
			Format(tmp2, sizeof(tmp2), "Constuire %d (%.1fsec)", i, duration*i);
			
			AddMenuItem(menu, tmp, tmp2);
		}
	}
	
	DisplayMenu(menu, client, 30);
}
void displayRecyclingMenu(int client, int itemID) {
	
	if( rp_GetClientInt(client, i_ItemCount) == 0 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous n'avez aucun item à recycler.");
		return;
	}
	
	Handle menu = CreateMenu(eventArtisanMenu);
	char tmp[64], tmp2[64];
	
	if( itemID == 0 ) {
		SetMenuTitle(menu, "== Artisanat: Recycler");
		
		for(int i = 0; i < MAX_ITEMS; i++) {
			if( rp_GetClientItem(client, i) <= 0 )
				continue;
			if( getDuration(i) <= -0.1 )
				continue;
			
			rp_GetItemData(i, item_type_name, tmp2, sizeof(tmp2));
			Format(tmp, sizeof(tmp), "recycle %d", i);
			Format(tmp2, sizeof(tmp2), "%s (%i)",tmp2,rp_GetClientItem(client, i));
			AddMenuItem(menu, tmp, tmp2);
		}
	}
	else {
		rp_GetItemData(itemID, item_type_name, tmp2, sizeof(tmp2));
		Format(tmp2, sizeof(tmp2), "== Artisanat: Recycler: %s", tmp2);
		SetMenuTitle(menu, tmp2);
		
		float duration = getDuration(itemID);
		Format(tmp, sizeof(tmp), "recycle %d %d", itemID, rp_GetClientItem(client, itemID));
		Format(tmp2, sizeof(tmp2), "Tout recycler (%.1fsec)", duration*rp_GetClientItem(client, itemID));
		AddMenuItem(menu, tmp, tmp2);
		
		for(int i = 1; i <= rp_GetClientItem(client, itemID); i++) {
			
			Format(tmp, sizeof(tmp), "recycle %d %d", itemID, i);
			Format(tmp2, sizeof(tmp2), "Recycler %d (%.1fsec)", i, duration*i);
			
			AddMenuItem(menu, tmp, tmp2);
		}
	}
	

	DisplayMenu(menu, client, 30);
}
void displayLearngMenu(char[] type, int client, int jobID, int itemID) {
	
	char tmp[64], tmp2[64], prettyJob[2][64];
	ArrayList magic;
	Handle menu = CreateMenu(eventArtisanMenu);
	int count = rp_GetClientInt(client, i_ArtisanPoints);
	int data[craft_type_max];
	bool can, skip = StrEqual(type, "learn") ? false : true;
	if( !skip && count == 0 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous n'avez aucun point d'apprentissage.");
		return;
	}
	
	if( !skip )
		SetMenuTitle(menu, "== Artisanat: Apprendre (%d)", count);
	else
		SetMenuTitle(menu, "== Artisanat: Livre des recettes", count);
	
	if( jobID == 0 ) {
		for (int i = 0; i < sizeof(lstJOB); i++) {
			
			rp_GetJobData(lstJOB[i], job_type_name, tmp, sizeof(tmp));
			ExplodeString(tmp, " - ", prettyJob, sizeof(prettyJob), sizeof(prettyJob[]));
			Format(tmp, sizeof(tmp), "%s %d", type, lstJOB[i]);
			AddMenuItem(menu, tmp, prettyJob[1]);
		}
	}
	else if( itemID == 0 ) {
		for(int i = 0; i < MAX_ITEMS; i++) {
			if( g_bCanCraft[client][i]  && !skip )
				continue;
			if( !g_bCanCraft[client][i]  && skip )
				continue;
			if( rp_GetItemInt(i, item_type_job_id) != jobID )
				continue;
			Format(tmp, sizeof(tmp), "%d", i);
			if( !g_hReceipe.GetValue(tmp, magic) )
				continue;
			can = true;
			if( count*250 < rp_GetItemInt(i, item_type_prix) && !skip )
				can = false;
			
			rp_GetItemData(i, item_type_name, tmp2, sizeof(tmp2));
			if( StrContains(tmp2, "MISSING") == 0 )
				continue;
			Format(tmp, sizeof(tmp), "%s %d %d", type, jobID, i);
			Format(tmp2, sizeof(tmp2), "%s (%i)",tmp2, RoundToCeil(float(rp_GetItemInt(i, item_type_prix)) / 250.0));
			
			AddMenuItem(menu, tmp, tmp2, (can?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED));
		}
	}
	else {
		rp_GetItemData(itemID, item_type_name, tmp, sizeof(tmp));
		SetMenuTitle(menu, "== Artisanat: Livre: %s", tmp);
		
		Format(tmp, sizeof(tmp), "%d", itemID);
		g_hReceipe.GetValue(tmp, magic);
		
		for (int j = 0; j < magic.Length; j++) { // Pour chaque items de la recette:
			magic.GetArray(j, data);
			
			rp_GetItemData(data[craft_raw], item_type_name, tmp, sizeof(tmp));
			Format(tmp2, sizeof(tmp2), "%dx%s (%d%%)", data[craft_amount], tmp, data[craft_rate]);
			AddMenuItem(menu, tmp2, tmp2, ITEMDRAW_DISABLED);
		}
		if( !skip )  {
			Format(tmp, sizeof(tmp), "%s %d %d 1", type, jobID, itemID);
			AddMenuItem(menu, tmp, "Apprendre");
		}
	}
	
	DisplayMenu(menu, client, 30);
}
public int eventArtisanMenu(Handle menu, MenuAction action, int client, int param2) {
	#if defined DEBUG
	PrintToServer("eventArtisanMenu");
	#endif
	
	if( action == MenuAction_Select ) {
		char options[64], buffer[4][16];
		ArrayList magic;
		int data[craft_type_max];
		
		GetMenuItem(menu, param2, options, sizeof(options));
		ExplodeString(options, " ", buffer, sizeof(buffer), sizeof(buffer[]));
		PrintToChat(client, "%s-->%s,%s,%s,%s", options, buffer[0], buffer[1], buffer[2], buffer[3]);
		
		if( StrContains(options, "build", false) == 0 ) {
			if( StringToInt(buffer[3]) == 0 )
				displayBuildMenu(client, StringToInt(buffer[1]), StringToInt(buffer[2]));
			else if( g_hReceipe.GetValue(buffer[2], magic) ) {			
				startBuilding(client, StringToInt(buffer[2]), StringToInt(buffer[3]), StringToInt(buffer[3]));
			}
		}
		else if( StrContains(options, "recycl", false) == 0 ) {
			if( StringToInt(buffer[2]) == 0 )
				displayRecyclingMenu(client, StringToInt(buffer[1]));
			else if( g_hReceipe.GetValue(buffer[1], magic) ) {
				
				int itemID = StringToInt(buffer[1]);
				int amount = StringToInt(buffer[2]);
				if( amount > rp_GetClientItem(client, itemID) )
					amount = rp_GetClientItem(client, itemID);
				float duration = getDuration(itemID) * float(amount);
				
				rp_GetItemData(itemID, item_type_name, options, sizeof(options));
				rp_ClientGiveItem(client, StringToInt(buffer[1]), -amount);
				
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous commencer à recycler %dx %s. Cette opération va durer %.1f seconde%s.", amount, options, duration, duration>=2.0?"s":"");
				
				for (int i = 0; i < magic.Length; i++) {  // Pour chaque items de la recette:
					magic.GetArray(i, data);
					for (int j = 0; j < data[craft_amount]; j++) { // Pour chaque quantité nécessaire de la recette
						for (int k = 0; k < amount; k++) { // On multiplie par la quantité
							if( data[craft_rate] >= Math_GetRandomInt(0, 100) ) // De facon aléatoire
								rp_ClientGiveItem(client, data[craft_raw]);
						}
					}
				}
				duration = 1.0;
				ServerCommand("sm_effect_panel %d %f \"Recyclage de %dx %s\"", client, duration, amount, options);
				rp_HookEvent(client, RP_PrePlayerPhysic, fwdFrozen, duration);
				return;
			}
		}
		else if( StrContains(options, "learn", false) == 0 ) {
			if( StringToInt(buffer[3]) == 0 )
				displayLearngMenu("learn", client, StringToInt(buffer[1]), StringToInt(buffer[2]));
			else {
				int itemID = StringToInt(buffer[2]);
				int count = rp_GetClientInt(client, i_ArtisanPoints);
				if( count*250 < rp_GetItemInt(itemID, item_type_prix) ) {
					return;
				}
				
				g_bCanCraft[client][itemID] = true;
				rp_SetClientInt(client, i_ArtisanPoints, count - RoundToCeil(float(rp_GetItemInt(itemID, item_type_prix)) / 250.0));
				char query[1024], szSteamID[32];
				GetClientAuthId(client, AuthId_Engine, szSteamID, sizeof(szSteamID));
				Format(query, sizeof(query), "INSERT INTO `rp_craft_book` (`steamid`, `itemid`) VALUES ('%s', '%d');", szSteamID, itemID);
				SQL_TQuery(rp_GetDatabase(), SQL_QueryCallBack, query);
			}
		}
		else if( StrContains(options, "book", false) == 0 ) {
			if( StringToInt(buffer[3]) == 0 )
				displayLearngMenu("book", client, StringToInt(buffer[1]), StringToInt(buffer[2]));
		}
	}
	else if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
public Action fwdFrozen(int client, float& speed, float& gravity) {
	speed = 0.0;
	gravity = 0.0; 
	return Plugin_Stop;
}
float getDuration(int itemID) {
	if( rp_GetItemInt(itemID, item_type_job_id) == 91 )
		return -1.0;
	char tmp[12];
	int data[craft_type_max];
	Format(tmp, sizeof(tmp), "%d", itemID);
	
	ArrayList magic;
	if( !g_hReceipe.GetValue(tmp, magic) )
		return -1.0;
	
	
	float duration = 0.0;
	for (int i = 0; i < magic.Length; i++) {
		magic.GetArray(i, data);
		duration += 0.01 * data[craft_amount];
	}
	return duration;
}
void startBuilding(int client, int itemID, int total, int amount) {
	
	float duration = getDuration(itemID);

	if( amount > 0 && duration >= -0.0001 ) {
		Handle dp;
		CreateDataTimer(duration, stopBuilding, dp, TIMER_DATA_HNDL_CLOSE|TIMER_REPEAT);
		WritePackCell(dp, client);
		WritePackCell(dp, itemID);
		WritePackCell(dp, total);
		WritePackCell(dp, amount);
	}
}
public Action stopBuilding(Handle timer, Handle dp) {
	ResetPack(dp);
	int client = ReadPackCell(dp);
	int itemID = ReadPackCell(dp);
	int total = ReadPackCell(dp);
	int amount = ReadPackCell(dp);
	
	if( !IsValidClient(client) ) {
		return Plugin_Stop;
	}
	
	ArrayList magic;
	int data[craft_type_max];
	char tmp[64];
	Format(tmp, sizeof(tmp), "%d", itemID);
	if( !g_hReceipe.GetValue(tmp, magic) )
		return Plugin_Stop;
					
	for (int j = 0; j < magic.Length; j++) { // Pour chaque items de la recette:
		magic.GetArray(j, data);
		
		if( data[craft_amount] > rp_GetClientItem(client,data[craft_raw]) )
			return Plugin_Stop;
	}
	
	rp_ClientGiveItem(client, itemID, 1);
	for (int i = 0; i < magic.Length; i++) {  // Pour chaque items de la recette:
		magic.GetArray(i, data);
		rp_ClientGiveItem(client, data[craft_raw], -data[craft_amount]);
	}
	ResetPack(dp);
	WritePackCell(dp, client);
	WritePackCell(dp, itemID);
	WritePackCell(dp, total);
	WritePackCell(dp, amount-1);
	
	if( amount <= 0 )
		return Plugin_Stop;
	
	Handle menu = CreateMenu(eventArtisanMenu);
	SetMenuTitle(menu, "== Artisanat: Construction");
	getLoadingBar(tmp, sizeof(tmp), (float(total)-float(amount)) / float(total) );
	AddMenuItem(menu, tmp, tmp);
	DisplayMenu(menu, client, 1);
	
	return Plugin_Continue;
}


void getLoadingBar(char[] str, int length, float percent) {
	int full = RoundToFloor(length * percent / GetCharBytes("█"));
	float left = (length * percent / GetCharBytes("█")) - float(full);
	if( full > length )
		full = length;
	
	for (int i = 0; i < full; i++)
		Format(str, length, "%s█", str);
	
	
	if( full < length ) {
		if( left > 0.75 ) 
			Format(str, length, "%s▓", str);
		else if( left > 0.5 )
			Format(str, length, "%s░", str);
		else if( left > 0.25 )
			Format(str, length, "%s▒", str);
	}
}

void getLoadingBar2(char[] str, int length, float percent) {
	int full = RoundToFloor(percent * 100);
	int left = full % 10;
	full = (full - left) / 10;
	for(int i=0; i<full; i++)
		Format(str, length, "%s█", str);
	
	if(left > 0){
		if(left > 7)
			Format(str, length, "%s▓", str);
		else if(left > 4)
			Format(str, length, "%s░", str);
		else if(left > 1)
			Format(str, length, "%s▒", str);
	}
}