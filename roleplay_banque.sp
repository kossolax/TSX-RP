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
#include <colors_csgo>	// https://forums.alliedmods.net/showthread.php?p=2205447#post2205447
#include <smlib>		// https://github.com/bcserv/smlib

#define __LAST_REV__ 		"v:0.2.0"

#pragma newdecls required
#include <roleplay.inc>	// https://www.ts-x.eu

//#define DEBUG
#define MENU_TIME_DURATION	60

public Plugin myinfo = {
	name = "Jobs: Banquier", author = "KoSSoLaX",
	description = "RolePlay - Jobs: Banquier",
	version = __LAST_REV__, url = "https://www.ts-x.eu"
};

// ----------------------------------------------------------------------------
public void OnPluginStart() {
	RegServerCmd("rp_bankcard",			Cmd_ItemBankCard,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_bankkey",			Cmd_ItemBankKey,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_bankswap",			Cmd_ItemBankSwap,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_assurance",	Cmd_ItemAssurance,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_forward",		Cmd_ItemForward,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_noAction",	Cmd_ItemNoAction,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_cheque",		Cmd_ItemCheque,			"RP-ITEM",	FCVAR_UNREGISTERED);
}
// ----------------------------------------------------------------------------

public Action Cmd_ItemBankCard(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemBankCard");
	#endif
	
	int client = GetCmdArgInt(1);
	rp_SetClientBool(client, b_HaveCard, true);
	
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Votre carte banquaire est maintenant active.");
}
public Action Cmd_ItemBankKey(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemBankKey");
	#endif
	
	int client = GetCmdArgInt(1);
	rp_SetClientBool(client, b_HaveAccount, true);
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Votre compte bancaire est maintenant active.");
}
public Action Cmd_ItemBankSwap(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemBankSwap");
	#endif
	
	
	int client = GetCmdArgInt(1);
	rp_SetClientBool(client, b_PayToBank, true);
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous recevrez maintenent votre paye en banque.");
}

public Action Cmd_ItemAssurance(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemAssurance");
	#endif
	
	
	int client = GetCmdArgInt(1);
	
	if( !rp_GetClientBool(client, b_Assurance) ) {
		rp_IncrementSuccess(client, success_list_assurance);
	}
	
	rp_SetClientBool(client, b_Assurance, true);
	FakeClientCommand(client, "say /assu");
	
	return Plugin_Handled;
}
public Action Cmd_ItemNoAction(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemNoAction");
	#endif
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	char name[64];
	
	rp_ClientGiveItem(client, item_id);
	rp_GetItemData(item_id, item_type_name, name, sizeof(name));
	
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Ceci est un %s, vous en avez %d sur vous et %d en banque.", name, rp_GetClientItem(client, item_id), rp_GetClientItem(client, item_id, true));
	return;
}

int g_iChequeID = -1;

public Action Cmd_ItemCheque(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemCheque");
	#endif
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	
	if( g_iChequeID == -1 )
		g_iChequeID = item_id;
	
	rp_ClientGiveItem(client, item_id);
	CreateTimer(0.25, task_cheque, client);
}

public Action task_cheque(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("task_cheque");
	#endif
	// Setup menu
	Handle menu = CreateMenu(MenuCheque);
	SetMenuTitle(menu, "Liste des jobs disponible:");
	char tmp[12], tmp2[64];
	
	bool bJob[MAX_JOBS];
	
	for(int i = 1; i <= MaxClients; i++) {
		
		if( !IsValidClient(i) )
			continue;
		if( !IsClientConnected(i) )
			continue;
		if( rp_GetClientInt(i, i_Job) == 0 )
			continue;
		if( i == client )
			continue;
		
		int job = rp_GetClientJobID(i);
		if( job == 1 || job == 91 || job == 101 || job == 181 ) // Police, mafia, tribunal, 18th
			continue;
		
		bJob[job] = true;
	}
	
	int amount = 0;
	
	for(int i=1; i<MAX_JOBS; i++) {
		if( bJob[i] == false )
			continue;
		
		amount++;
		Format(tmp, sizeof(tmp), "%d", i);
		rp_GetJobData(i, job_type_name, tmp2, sizeof(tmp2));
		
		AddMenuItem(menu, tmp, tmp2);
	}
	
	if( amount == 0 ) {
		CloseHandle(menu);
	}
	else {
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_DURATION);
	}
}

public int MenuCheque(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuCheque");
	#endif
	
	if (p_oAction == MenuAction_Select) {
		
		char szMenuItem[64];
		if( GetMenuItem(p_hItemMenu, p_iParam2, szMenuItem, sizeof(szMenuItem)) ) {
			
			char tmp[255], tmp2[255];
			int jobID = StringToInt(szMenuItem);
			
			// Setup menu
			Handle hGiveMenu = CreateMenu(MenuCheque2);
			SetMenuTitle(hGiveMenu, "Sélectionner un objet à acheter:");
			
			for(int i = 0; i < MAX_ITEMS; i++) {
				
				if( rp_GetItemInt(i, item_type_job_id) != jobID )
					continue;
				
				rp_GetItemData(i, item_type_extra_cmd, tmp, sizeof(tmp));
				
				// Chirurgie
				if( StrContains(tmp, "rp_chirurgie", false) == 0 )
					continue;
				if( StrContains(tmp, "rp_item_contrat", false) == 0 )
					continue;
				if( StrContains(tmp, "rp_item_conprotect", false) == 0 )
					continue;
				
				rp_GetItemData(i, item_type_name, tmp, sizeof(tmp));
				
				Format(tmp2, sizeof(tmp2), "%s [%d$]", tmp, rp_GetItemInt(i, item_type_prix) );
				Format(tmp, sizeof(tmp), "%d_0_0_%d_0", i, client);
				
				AddMenuItem(hGiveMenu, tmp, tmp2);
			}
			
			SetMenuExitButton(hGiveMenu, true);
			DisplayMenu(hGiveMenu, client, MENU_TIME_DURATION);
		}
	}
	else if ( p_oAction == MenuAction_End ) {
		CloseHandle(p_hItemMenu);
	}
}
public int MenuCheque2(Handle p_hItemMenu, MenuAction p_oAction, int client, int p_iParam2) {
	#if defined DEBUG
	PrintToServer("MenuCheque2");
	#endif
	if (p_oAction == MenuAction_Select) {
		
		char szMenuItem[64];
		if( GetMenuItem(p_hItemMenu, p_iParam2, szMenuItem, sizeof(szMenuItem)) ) {
			
			char data[5][32];
			ExplodeString(szMenuItem, "_", data, sizeof(data), sizeof(data[]));
			
			int item_id = StringToInt(data[0]);
			int price = rp_GetItemInt(item_id, item_type_prix);
			int auto = rp_GetItemInt(item_id, item_type_auto);
			
			char tmp[255], tmp2[255], tmp3[255];
			rp_GetItemData(item_id, item_type_name, tmp3, sizeof(tmp3));
			
			// Setup menu
			Handle hGiveMenu = rp_CreateSellingMenu();			
			
			SetMenuTitle(hGiveMenu, "Sélectionner combien en acheter:");
			int amount = 0;
			for(int i = 1; i <= 100; i++) {
				
				if( (rp_GetClientInt(client, i_Money)+rp_GetClientInt(client, i_Bank)) <= (price*i) )
					break;
				if( i > 1 && auto )
					continue;
				
				amount++;
				
				
				Format(tmp2, sizeof(tmp2), "%s - %d [%d$]", tmp3, i, price * i );
				Format(tmp, sizeof(tmp), "%d_%d_%s_%s_%s_%s", item_id, i, data[1], data[2], data[3], data[4]); // id,amount,itemTYPE=0,param,ClientFromMenu,reduction

				AddMenuItem(hGiveMenu, tmp, tmp2);
			}
			
			if( amount == 0 ) {
				CloseHandle(hGiveMenu);
				return;
			}
			
			SetMenuExitButton(hGiveMenu, true);
			DisplayMenu(hGiveMenu, client, MENU_TIME_DURATION);
		}
	}
	else if ( p_oAction == MenuAction_End ) {
		CloseHandle(p_hItemMenu);
	}
}
public Action Cmd_ItemForward(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemForward");
	#endif
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	char tmp[64];
	int mnt = rp_GetClientItem(client, item_id);
	rp_ClientGiveItem(client, item_id, -mnt, false);
	rp_ClientGiveItem(client, item_id, mnt+1, true);
	
	rp_GetItemData(item_id, item_type_name, tmp, sizeof(tmp));
	
	if( mnt+1 == 1 )
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} %d %s a été transféré en banque.", mnt+1, tmp);
	else
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} %d %s ont été transférés en banque.", mnt+1, tmp);
	
	return;
}