#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <zriot>
//#include <zombiereloaded>

#pragma newdecls required

#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_GRENADE 2
#define SLOT_THROWABLE 3
#define SLOT_FIRE 4

char sTag[] = "[Weapon]";

enum struct Weapon_Data
{
    char data_name[64];
    char data_entity[64];
    int data_price;
    int data_slot;
    char data_command[64];
    bool data_restrict;
}

int g_iTotal;

Weapon_Data g_Weapon[64];

bool g_bBuyZoneOnly = false;
bool g_bAllowLoadout = false;

ConVar g_Cvar_BuyZoneOnly;

bool g_zombiereloaded = false;
bool g_zombieriot = false;

public Plugin myinfo = 
{
    name = "[CSGO] Gun Menu",
	author = "Oylsister",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("sm_gun", Command_GunMenu);
    RegAdminCmd("sm_restrict", Command_Restrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_unrestrict", Command_Unrestrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_slot", GetSlotCommand, ADMFLAG_GENERIC);

    g_Cvar_BuyZoneOnly = CreateConVar("sm_gunmenu_buyzoneonly", "0.0", "Only allow to purchase on buyzone only", _, true, 0.0, true, 1.0);

    AutoExecConfig();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("ZR_IsClientZombie");
    MarkNativeAsOptional("ZRiot_IsClientZombie");

    return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
    if(LibraryExists("zombiereloaded"))
    {
        g_zombiereloaded = true;
    }
    
    if(LibraryExists("zombieriot"))
    {
        g_zombieriot = true;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if(StrEqual(name, "zombiereloaded", false))
    {
        g_zombiereloaded = true;
    }
    if(StrEqual(name, "zombieriot", false))
    {
        g_zombieriot = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if(StrEqual(name, "zombiereloaded", false))
    {
        g_zombiereloaded = true;
    }
    if(StrEqual(name, "zombieriot", false))
    {
        g_zombieriot = true;
    }
}

public void OnMapStart()
{
    LoadConfig();
    g_bBuyZoneOnly = GetConVarBool(g_Cvar_BuyZoneOnly);
}

void LoadConfig()
{
    KeyValues kv;
    char sConfigPath[PLATFORM_MAX_PATH];
    char sTemp[64];

    BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/gun_menu.txt");

    kv = CreateKeyValues("weapons");
    FileToKeyValues(kv, sConfigPath);

    if(KvGotoFirstSubKey(kv))
    {
        g_iTotal = 0;

        do
        {
            KvGetSectionName(kv, sTemp, 64);
            Format(g_Weapon[g_iTotal].data_name, 64, "%s", sTemp);

            KvGetString(kv, "entity", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_entity, 64, "%s", sTemp);

            KvGetString(kv, "price", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_price = StringToInt(sTemp);

            g_Weapon[g_iTotal].data_slot = KvGetNum(kv, "slot", -1);

            KvGetString(kv, "command", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_command, 64, "%s", sTemp);

            KvGetString(kv, "restrict", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_restrict = view_as<bool>(StringToInt(sTemp));

            g_iTotal++;
        }
        while(KvGotoNextKey(kv));
    }
}

public Action Command_Say(int client, int args)
{
    if(client < 1)
    {
        return Plugin_Continue;
    }
    if(!IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }
    if(ZRiot_IsClientZombie(client))
    {
        return Plugin_Continue;
    }

    char sBuffer[64];
    char sBuffer2[64];

    GetCmdArgString(sBuffer, sizeof(sBuffer));

    if(StrContains(sBuffer, "!") == -1 && StrContains(sBuffer, "/") == -1)
    {
        return Plugin_Continue;
    }
    
    ReplaceString(sBuffer, sizeof(sBuffer), "\"", "");
    ReplaceString(sBuffer, sizeof(sBuffer), "/", "");
    ReplaceString(sBuffer, sizeof(sBuffer), "!", "");

    if(StrContains(sBuffer, "sm_") == -1)
    {
        Format(sBuffer2, sizeof(sBuffer2), "sm_");
        StrCat(sBuffer2, sizeof(sBuffer2), sBuffer);
    }
    for (int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sBuffer, g_Weapon[i].data_command, false) || StrEqual(sBuffer2, g_Weapon[i].data_command, false))
        {
            PurchaseWeapon(client, g_Weapon[i].data_entity);
            break;
        }
    }
    return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    for(int i = 0; i < g_iTotal; i++)
    {
         if(StrEqual(command, g_Weapon[i].data_command, false))
        {
            PurchaseWeapon(client, g_Weapon[i].data_entity);
            break;
        }
    }
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be alive to purchase the weapon.", sTag);
        return Plugin_Handled;
    }

    if(g_zombieriot || g_zombiereloaded)
    {
        if(ZRiot_IsClientZombie(client))
        {
            PrintToChat(client, " \x04%s\x01 You must be Human to purchase the weapon.", sTag);
            return Plugin_Handled;
        }
    }

    for(int i = 0; i < g_iTotal; i++)
    {
        char reformat[64];
        Format(reformat, sizeof(reformat), "%s", g_Weapon[i].data_entity);
        ReplaceString(reformat, sizeof(reformat), "weapon_", "");

        if(StrEqual(weapon, reformat, false))
        {
            if(g_Weapon[i].data_restrict == true)
            {
                PrintToChat(client, " \x04%s\x01 \x04\"%s\" has been restricted.", sTag, g_Weapon[i].data_name);
                break;
            }
            int cash = GetEntProp(client, Prop_Send, "m_iAccount");

            if(g_Weapon[i].data_price > cash)
            {
                PrintToChat(client, " \x04%s\x01 You don't have enough cash to purchase this item.", sTag);
                break;
            }

            SetEntProp(client, Prop_Send, "m_iAccount", cash - g_Weapon[i].data_price);
            GivePlayerItem(client, g_Weapon[i].data_entity);
            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\" \x01type \x06%s \x01to purchase again.", sTag, g_Weapon[i].data_name, g_Weapon[i].data_command);
            break;
        }
    }
    return Plugin_Continue;
}

public Action Command_Restrict(int client, int args)
{
    if(args < 1)
    {
        RestrictMenu(client);
        return Plugin_Handled;
    }

    char sArg[64];
    GetCmdArg(1, sArg, sizeof(sArg));

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            RestrictWeapon(sArg);
            found = true;
            break;
        }
    }

    if(!found)
    {
        ReplyToCommand(client, " \x04%s\x01 the weapon is invaild.");
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action Command_Unrestrict(int client, int args)
{
    if(args < 1)
    {
        RestrictMenu(client);
        return Plugin_Handled;
    }

    char sArg[64];
    GetCmdArg(1, sArg, sizeof(sArg));

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            UnrestrictWeapon(sArg);
            found = true;
            break;
        }
    }

    if(!found)
    {
        ReplyToCommand(client, " \x04%s\x01 the weapon is invaild.");
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public void RestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = true;
            PrintToChatAll(" \x04%s\x01 \x04\"%s\" has been restricted", sTag, g_Weapon[i].data_name);
            break;
        }
    }
}

public void UnrestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = false;
            PrintToChatAll(" \x04%s\x01 \x04\"%s\" has been unrestricted.", sTag, g_Weapon[i].data_name);
            break;
        }
    }
}

public void Toggle_RestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = !g_Weapon[i].data_restrict;

            if(g_Weapon[i].data_restrict == true)
            {
                PrintToChatAll(" \x04%s\x01 \x04\"%s\" has been restricted.", sTag, g_Weapon[i].data_name);
            }
            else
            {
                PrintToChatAll(" \x04%s\x01 \x04\"%s\" has been unrestricted.", sTag, g_Weapon[i].data_name);
            }
            break;
        }
    }
}

public Action GetSlotCommand(int client, int args)
{
    if(args == 0)
    {
        ReplyToCommand(client, " \x04%s\x01 Usage: sm_slot <weaponname>", sTag);
        return Plugin_Handled;
    }

    char sArgs[64];
    GetCmdArg(1, sArgs, sizeof(sArgs));

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArgs, g_Weapon[i].data_name))
        {
            PrintToChat(client, " \x04%s\x01 %s slot is %i.", sTag, g_Weapon[i].data_name, g_Weapon[i].data_slot);
            break;
        }
    }
    return Plugin_Handled;
}

public Action Command_GunMenu(int client, int args)
{
    Menu menu = new Menu(MainMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Main Menu", sTag);
    menu.AddItem("buy", "Buy Weapon");
    menu.AddItem("loadout", "Your Loadout");
    menu.AddItem("SPACE", "---------------");
    menu.AddItem("settings", "Server Setting");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "settings"))
            {
                if(!IsClientAdmin(param1))
                {
                    return ITEMDRAW_DISABLED;
                }
            }
            else if(StrEqual(info, "SPACE"))
            {
                return ITEMDRAW_DISABLED;
            }
            else if(StrEqual(info, "loadout"))
            {
                if(!g_bAllowLoadout)
                {
                    return ITEMDRAW_DISABLED;
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            char info[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "settings"))
            {
                if(!IsClientAdmin(param1))
                {
                    Format(display, sizeof(display), "%s (Admin Only)", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "buy"))
            {
                WeaponTypeMenu(param1);
            }
            else if(StrEqual(info, "loadout"))
            {
                ClientLoadoutMenu(param1);
            }
            else if(StrEqual(info, "settings"))
            {
                ServerSettingMenu(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void WeaponTypeMenu(int client)
{
    Menu menu = new Menu(WeaponTypeMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Weapon Type Menu", sTag);
    menu.AddItem("primary", "Primary Weapon");
    menu.AddItem("secondary", "Secondary Weapon");
    menu.AddItem("grenade", "Grenade");
    menu.AddItem("throwable", "Throwable");
    menu.AddItem("fire", "Fire Grenade");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int WeaponTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            {
                if(StrEqual(info, "primary"))
                {
                    PrimaryMenu(param1);
                }
                else if(StrEqual(info, "secondary"))
                {
                    SecondaryMenu(param1);
                }
                else if(StrEqual(info, "grenade"))
                {
                    GrenadeMenu(param1);
                }
                else if(StrEqual(info, "throwable"))
                {
                    ThrowableMenu(param1);
                }
                else
                {
                    FireGrenadeMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            Command_GunMenu(param1, 0);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void PrimaryMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Primary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_PRIMARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void SecondaryMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Secondary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_SECONDARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void GrenadeMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_GRENADE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void ThrowableMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Throwable Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_THROWABLE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void FireGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Fire Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_FIRE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SelectMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    if(g_Weapon[i].data_restrict == true)
                    {
                        return ITEMDRAW_DISABLED;
                    }
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    PurchaseWeapon(param1, g_Weapon[i].data_entity);
                }
            }
        }
        case MenuAction_Cancel:
        {
            WeaponTypeMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void PurchaseWeapon(int client, const char[] entity)
{
    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be alive to purchase the weapon.", sTag);
        return;
    }

    if(g_zombieriot || g_zombiereloaded)
    {
        if(ZRiot_IsClientZombie(client))
        {
            PrintToChat(client, " \x04%s\x01 You must be Human to purchase the weapon.", sTag);
            return;
        }
    }

    if(g_bBuyZoneOnly && !IsClientInBuyZone(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be in the buyzone to purchase the weapon.", sTag);
        return;
    }

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(entity, g_Weapon[i].data_entity, false))
        {
            if(g_Weapon[i].data_restrict == true)
            {
                PrintToChat(client, " \x04%s\x01 \x04\"%s\" has been restricted.", sTag, g_Weapon[i].data_name);
                break;
            }
            int cash = GetEntProp(client, Prop_Send, "m_iAccount");

            if(g_Weapon[i].data_price > cash)
            {
                PrintToChat(client, " \x04%s\x01 You don't have enough cash to purchase this item.", sTag);
                break;
            }

            SetEntProp(client, Prop_Send, "m_iAccount", cash - g_Weapon[i].data_price);
            GivePlayerItem(client, g_Weapon[i].data_entity);
            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\" \x01type \x06%s \x01to purchase again.", sTag, g_Weapon[i].data_name, g_Weapon[i].data_command);
            break;
        }
    }
}

public void ClientLoadoutMenu(int client)
{

}

public void ServerSettingMenu(int client)
{
    Menu menu = new Menu(ServerSettingMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Setting Menu", sTag);
    menu.AddItem("buyzone", "BuyZone Only");
    menu.AddItem("restrict", "Restrict Weapon");
    menu.AddItem("loadout", "Allow Loadout");

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ServerSettingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "loadout"))
            {
                return ITEMDRAW_DISABLED;
            }
        }
        case MenuAction_DisplayItem:
        {
            char info[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "loadout"))
            {
                Format(display, sizeof(display), "%s (unavailable)", info);
                return RedrawMenuItem(display);
            }
            else if(StrEqual(info, "buyzone"))
            {
                if(!g_bBuyZoneOnly)
                {
                    Format(display, sizeof(display), "%s: False", info);
                    return RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: True", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "buyzone"))
            {
                g_bBuyZoneOnly = !g_bBuyZoneOnly;
                ServerSettingMenu(param1);
            }
            else if(StrEqual(info, "restrict"))
            {
                RestrictMenu(param1);
            }
        }
        case MenuAction_Cancel:
        {
            Command_GunMenu(param1, 0);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void RestrictMenu(int client)
{
    Menu menu = new Menu(RestrictTypeMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Restrict Weapon Menu", sTag);
    menu.AddItem("primary", "Primary Weapon");
    menu.AddItem("secondary", "Secondary Weapon");
    menu.AddItem("grenade", "Grenade");
    menu.AddItem("throwable", "Throwable");
    menu.AddItem("fire", "Fire Grenade");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int RestrictTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            {
                if(StrEqual(info, "primary"))
                {
                    RestrictPrimaryMenu(param1);
                }
                else if(StrEqual(info, "secondary"))
                {
                    RestrictSecondaryMenu(param1);
                }
                else if(StrEqual(info, "grenade"))
                {
                    RestrictGrenadeMenu(param1);
                }
                else if(StrEqual(info, "throwable"))
                {
                    RestrictThrowableMenu(param1);
                }
                else
                {
                    RestrictFireGrenadeMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            ServerSettingMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void RestrictPrimaryMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Primary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_PRIMARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
}

public void RestrictSecondaryMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Secondary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_SECONDARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
}

public void RestrictGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_GRENADE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
}

public void RestrictThrowableMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Throwable Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_THROWABLE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
}

public void RestrictFireGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Fire Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_FIRE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
}

public int SelectRestrictMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DisplayItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    if(g_Weapon[i].data_restrict == true)
                    {
                        char display[64];
                        Format(display, sizeof(display), "%s - Restricted", info);
                        RedrawMenuItem(display);
                    }
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    Toggle_RestrictWeapon(g_Weapon[i].data_name);
                }
            }
        }
        case MenuAction_Cancel:
        {
            RestrictMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
}

stock bool IsClientInBuyZone(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send,"m_bInBuyZone"));
}