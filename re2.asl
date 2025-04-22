//Resident Evil 2 Remake Autosplitter
//By CursedToast 1/28/2019
//By VideoGameRoulette & DeathHound 08/26/2023
//Sigscans/Rework by TheDementedSalad
//Hunk integrattion by DeathHound
//Last updated 22 April 2025

state("re2"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.Settings.CreateFromXml("Components/RE2make.Settings.xml");
    //vars.Helper.StartFileLogger("RE2R_Log.txt");
}

init
{
    // Initialize Version
    vars.inventoryPtr = IntPtr.Zero;

    IntPtr TimelineEventManager = vars.Helper.ScanRel(3, "48 8b 15 ?? ?? ?? ?? 48 39 78 ?? 0f 85 ?? ?? ?? ?? 48 85 d2 74 ?? 48 8b cb e8 ?? ?? ?? ?? 0f b6 c8");
    IntPtr InventoryManager = vars.Helper.ScanRel(3, "48 8b 3d ?? ?? ?? ?? 48 83 78 ?? ?? 0f 85 ?? ?? ?? ?? 48 85 ff 0f 84");
    IntPtr GameClock = vars.Helper.ScanRel(3, "48 8b 05 ?? ?? ?? ?? 48 85 c0 75 ?? 45 33 c0 8d 50 ?? 48 8b cd e8 ?? ?? ?? ?? eb");
    IntPtr EnvironmentStandbyManager = vars.Helper.ScanRel(3, "48 8b 15 ?? ?? ?? ?? 48 8b cb 48 85 d2 0f 84 ?? ?? ?? ?? 41 b1 ?? c6 44 24");
    IntPtr MainFlowManager = vars.Helper.ScanRel(3, "48 8b 15 ?? ?? ?? ?? 48 8b cf 8b b3");
    IntPtr SurvivorManager = vars.Helper.ScanRel(3, "48 8b 2d ?? ?? ?? ?? 48 85 ed 75 ?? 45 33 c0 8d 55 ?? 48 8b cf");
    IntPtr FadeManager = vars.Helper.ScanRel(3, "48 8b 15 ?? ?? ?? ?? 45 33 c0 48 8b cb 48 85 d2 74 ?? f3 0f 10 1d");

    vars.Helper["EventID"] = vars.Helper.MakeString(TimelineEventManager, 0xA8, 0x20, 0x14);
    vars.Helper["EventID"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
    vars.Helper["isGame"] = vars.Helper.Make<bool>(GameClock, 0x50);
    vars.Helper["isDemo"] = vars.Helper.Make<bool>(GameClock, 0x51);
    vars.Helper["isInv"] = vars.Helper.Make<bool>(GameClock, 0x52);
    vars.Helper["isPause"] = vars.Helper.Make<bool>(GameClock, 0x53);
    vars.Helper["GameElapsedTime"] = vars.Helper.Make<long>(GameClock, 0x60, 0x18);
    vars.Helper["DemoSpendingTime"] = vars.Helper.Make<long>(GameClock, 0x60, 0x20);
    vars.Helper["PauseSpendingTime"] = vars.Helper.Make<long>(GameClock, 0x60, 0x30);
    vars.Helper["MapID"] = vars.Helper.Make<short>(EnvironmentStandbyManager, 0xA8, 0x10);
    vars.Helper["SurvivorType"] = vars.Helper.Make<byte>(SurvivorManager, 0x50, 0x54);
    vars.Helper["SoundStateValue"] = vars.Helper.Make<byte>(MainFlowManager, 0x68);
    vars.Helper["GmeStartValue"] = vars.Helper.Make<byte>(MainFlowManager, 0x54);
    vars.Helper["Scenario"] = vars.Helper.Make<byte>(MainFlowManager, 0x198, 0x1C);
    vars.Helper["Results"] = vars.Helper.Make<byte>(MainFlowManager, 0x120, 0x10);

    vars.Helper["Fade6"] = vars.Helper.Make<bool>(FadeManager, 0x50, 0x48, 0x18, 0x68);

    vars.Inv = InventoryManager;
    vars.Clock = GameClock;

    vars.completedSplits = new HashSet<string>();

    current.item = new int[20].Select((_, i)
        => new DeepPointer(vars.Inv, 0x50, 0x98, 0x10, 0x20 + (i * 8), 0x18, 0x10, 0x10).Deref<int>(game))
        .ToArray();

    current.weapon = new int[20].Select((_, i)
        => new DeepPointer(vars.Inv, 0x50, 0x98, 0x10, 0x20 + (i * 8), 0x18, 0x10, 0x14).Deref<int>(game))
        .ToArray();
}

update
{
    vars.Helper.Update();
    vars.Helper.MapPointers();

    current.item = new int[20].Select((_, i)
        => new DeepPointer(vars.Inv, 0x50, 0x98, 0x10, 0x20 + (i * 8), 0x18, 0x10, 0x10).Deref<int>(game))
        .ToArray();

    current.weapon = new int[20].Select((_, i)
        => new DeepPointer(vars.Inv, 0x50, 0x98, 0x10, 0x20 + (i * 8), 0x18, 0x10, 0x14).Deref<int>(game))
        .ToArray();

    if (!string.IsNullOrEmpty(current.EventID))
        current.Event = current.EventID.Substring(2, 3);

    if (string.IsNullOrEmpty(current.EventID))
        current.Event = "";

    if (!settings["3Dig"])
        vars.Helper.Texts.RemoveAll();

    if (settings["3Dig"])
    {
        vars.TotalTimeInSeconds = current.GameElapsedTime - current.DemoSpendingTime - current.PauseSpendingTime;
        vars.Helper.Texts["Total Time"].Right = TimeSpan.FromSeconds(vars.TotalTimeInSeconds / 1000000.0).ToString(@"hh\:mm\:ss\.fff");
    }

    if (settings["3Dig"])
    {
        if (current.Results == 1 && old.Results != 1)
            game.WriteValue<byte>(game.ReadPointer((IntPtr)vars.Clock) + 0x50, 0);
    }
}

onStart
{
    vars.completedSplits.Clear();

    if (settings["3Dig"])
    {
        vars.Helper.Texts["Total Time"].Left = "Time:";
        vars.Helper.Texts["Total Time"].Right = "00:00:00.000";
    }
}

start
{
    if (settings["DLC"])
    {
        var time = (current.GameElapsedTime - current.DemoSpendingTime - current.PauseSpendingTime) / 1000000.0;
        if (settings["Hunk"])
            return time > 0.1 && time < 0.23;
    }
    else
        return (old.Event == "001" || old.Event == "910") && current.Event != old.Event;
}

split
{
    string setting = "";

    int[] currentItem = (current.item as int[]);
    int[] oldItem = (old.item as int[]);

    int[] currentWeapon = (current.weapon as int[]);
    int[] oldWeapon = (old.weapon as int[]);

    if (!currentItem.SequenceEqual(oldItem))
    {
        int[] delta = (currentItem as int[]).Where((v, i) => v != oldItem[i]).ToArray();

        foreach (int item in delta)
        {
            if (item != 0 && current.SurvivorType != 2)
                setting = "Item_" + item;
            if ((current.Scenario == 2 || current.Scenario == 3) && item == 241)
                setting = "Item_" + item + "_B";
        }
    }

    if (!currentWeapon.SequenceEqual(oldWeapon))
    {
        int[] delta = (currentWeapon as int[]).Where((v, i) => v != oldWeapon[i]).ToArray();

        foreach (int weapon in delta)
        {
            if (weapon != 0 && weapon != -1)
                setting = "Weapon_" + weapon;
        }
    }

    if (settings["DLC"])
    {
        if (settings["Hunk"])
        {
            if((current.MapID == 332 && old.MapID == 330) && timer.CurrentSplitIndex == 0)
                return true;
            else if((current.MapID == 352 && old.MapID == 319) && timer.CurrentSplitIndex == 1)
                return true;
            else if((current.MapID == 277 && old.MapID == 353) && timer.CurrentSplitIndex == 2)
                return true;
            else if((current.MapID == 112 && old.MapID == 239) &&  timer.CurrentSplitIndex == 3)
                return true;
            else if((current.MapID == 112 && old.MapID == 249) &&  timer.CurrentSplitIndex == 4)
                return true;
            else if((current.MapID == 260 && old.MapID == 268) && timer.CurrentSplitIndex == 5)
                return true;
            else if((current.GmeStartValue == 0 && old.GmeStartValue == 1) && timer.CurrentSplitIndex == 6)
                return true;
        }
    }
    else
    {
        // Main Game
        if (current.MapID != old.MapID)
            setting = "Map_" + current.MapID;

        if ((current.MapID == 112 || current.MapID == 261) && current.MapID != old.MapID)
            setting = "Map_RPD";

        if (current.EventID != old.EventID && !string.IsNullOrEmpty(current.EventID))
            setting = "Event_" + current.Event;

        if (current.Results == 1 && old.Results != 1)
            setting = "Results";
    }

    if (settings.ContainsKey(setting) && vars.completedSplits.Add(setting))
    {
        vars.Log($"Split: {setting}");
        return settings[setting];
    }
}

gameTime
{
    return TimeSpan.FromSeconds((current.GameElapsedTime - current.DemoSpendingTime - current.PauseSpendingTime) / 1000000.0);
}

isLoading
{
    return true;
}

reset
{
    if (settings["DLC"])
    {
        if (settings["Hunk"])
            return (current.GameElapsedTime - current.DemoSpendingTime - current.PauseSpendingTime) / 1000000.0 < 0.01;
    }
    else
        // Main Game
        return (current.Event == "011" || current.Event == "910") && current.Event != old.Event;
}
