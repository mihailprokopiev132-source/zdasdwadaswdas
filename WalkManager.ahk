#Requires AutoHotkey v2.0

global movementKeys := ["w", "a", "s", "d"]
global activeHotkeys := []
global firstKeyPressed := false

Walk(direction, duration) {
    key := "{" . direction . " down}"
    SendInput(key)
    Sleep(duration)
    key := "{" . direction . " up}"
    SendInput(key)
    KeyWait direction
    Sleep(1000)
}

GetMapForMode(mode) {
    switch mode {
        case "Story":
            return currentMap != "" ? currentMap : StoryDropdown.Text
        case "Legend Stages":
            return currentMap != "" ? currentMap : LegendDropDown.Text
        case "Infinity Castle":
            return currentMap != "" ? currentMap : ""
        case "Raid":
            return currentMap != "" ? currentMap : RaidDropdown.Text
        case "Portal":
            return currentMap != "" ? currentMap : PortalDropdown.Text
        case "Event":
            return currentMap != "" ? currentMap : EventDropdown.Text
        case "Custom":
            return WalkMapDropdown.Text
    }
    return WalkMapDropdown.Text
}

; === Start of new walk functions ===

StartRecordingWalk(*) {
    global recording, allWalks, keyDownTimes, lastActionTime, activeHotkeys, movementKeys, firstKeyPressed

    mapName := WalkMapDropdown.Text

    if !allWalks.Has(mapName)
        allWalks[mapName] := []
    allWalks[mapName] := [] ; clear old recording
    recording := true
    keyDownTimes := Map()
    lastActionTime := A_TickCount
    firstKeyPressed := false
    AddToLog("Starting map movement recording for: " mapName)
    AddToLog("Press LShift to stop recording")

    for key in movementKeys {
        downHK := Hotkey("~*" key, RecordKeyDown.Bind(key))
        upHK := Hotkey("~*" key " up", RecordKeyUp.Bind(key))
        activeHotkeys.Push(downHK)
        activeHotkeys.Push(upHK)
    }

    activeHotkeys.Push(Hotkey("~LShift", StopRecordingWalk))

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }
}

StopRecordingWalk(*) {
    global recording, activeHotkeys

    if !recording
        return

    recording := false
    AddToLog("Movement recording stopped, saving...")

    for hk in activeHotkeys {
        try hk.Delete
    }
    activeHotkeys := []  ; clear list
    SaveAllMovements()
    UpdateWalkListView()
}

RecordKeyDown(key, *) {
    global recording, keyDownTimes
    if !recording
        return
    if !keyDownTimes.Has(key)
        keyDownTimes[key] := A_TickCount
}

RecordKeyUp(key, *) {
    global recording, allWalks, keyDownTimes, lastActionTime, firstKeyPressed
    if !recording || !keyDownTimes.Has(key)
        return

    currentMap := WalkMapDropdown.Text
    now := A_TickCount
    pressStart := keyDownTimes[key]
    duration := now - pressStart

    if !firstKeyPressed {
        delay := 0
        firstKeyPressed := true
    } else {
        delay := pressStart - lastActionTime
    }

    lastActionTime := now
    keyDownTimes.Delete(key)
    entry := { key: key, duration: duration, delay: delay }
    allWalks[currentMap].Push(entry)
    AddToLog("Registered Key: " key " (" duration " ms, +" delay " ms delay)")
}

StartWalk(testing := false) {
    global allWalks

    currentMap := testing ? WalkMapDropdown.Text : GetMapForMode(ModeDropdown.Text)

    if !allWalks.Has(currentMap) || allWalks[currentMap].Length = 0 {
        if (debugMessages) {
            AddToLog("No recording for profile: " currentMap)
        }
        return false
    }

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }

    data := allWalks[currentMap]

    for entry in data {
        AddToLog("[Walking] Sending Key: " entry.key ", Duration: " entry.duration "ms, Delay: " entry.delay "ms")
        Sleep(entry.delay)
        Send("{" entry.key " down}")
        Sleep(entry.duration)
        Send("{" entry.key " up}")
        KeyWait entry.key
    }
    return true
}

SaveAllMovements(*) {
    global allWalks
    try {
        folder := A_ScriptDir "\Settings"
        if !DirExist(folder)
            DirCreate(folder)

        file := FileOpen(folder "\CustomMovements.txt", "w", "UTF-8")
        for mapName, actions in allWalks {
            for entry in actions {
                line := Format("{},{},{},{}`n", mapName, entry.key, entry.duration, entry.delay)
                file.Write(line)
            }
        }
        file.Close()
    } catch Error {
        AddToLog("Error saving custom movements: " Error)
    }
}

LoadAllMovements(*) {
    global allWalks
    if !FileExist(A_ScriptDir "\Settings\CustomMovements.txt") {
        FileAppend("", A_ScriptDir "\Settings\CustomMovements.txt")
        return
    }

    allWalks := Map()
    for line in StrSplit(FileRead(A_ScriptDir "\Settings\CustomMovements.txt", "UTF-8"), "`n") {
        if (Trim(line) = "")
            continue
        parts := StrSplit(line, ",")
        if (parts.Length < 4)
            continue

        mapName := parts[1]
        key := parts[2]
        duration := parts[3]
        delay := parts[4]

        if !allWalks.Has(mapName)
            allWalks[mapName] := []

        allWalks[mapName].Push({ key: key, duration: duration, delay: delay })
    }

    UpdateWalkListView()
}

ExportMovements(mapName := "") {
    global allWalks

    exportDir := A_ScriptDir "\Settings\Export"
    if !DirExist(exportDir)
        DirCreate(exportDir)

    ; Default: export all maps
    if (mapName = "") {
        filePath := exportDir "\Exported Movements - All.txt"
        AddToLog("Exporting all maps to " filePath)
        entries := allWalks
    } else if !allWalks.Has(mapName) {
        AddToLog("No recording found for map: " mapName)
        return
    } else {
        filePath := exportDir "\Exported Movements - " mapName ".txt"
        AddToLog("Exporting map '" mapName "' to " filePath)
        entries := Map()
        entries[mapName] := allWalks[mapName]
    }

    try {
        file := FileOpen(filePath, "w", "UTF-8")
        for mName, actions in entries {
            for entry in actions {
                line := Format("{},{},{},{}`n", mName, entry.key, entry.duration, entry.delay)
                file.Write(line)
            }
        }
        file.Close()
        AddToLog("✅ Export successful.")
    } catch Error {
        AddToLog("❌ Export failed: " Error)
    }
}

ImportMovements(*) {
    global allWalks

    ; Ensure allWalks exists
    if !IsObject(allWalks)
        allWalks := Map()

    MainUI.Opt("-AlwaysOnTop")
    Sleep(100)

    ; Prompt user to select file
    filePath := FileSelect("", A_ScriptDir "\Settings", "Select a movement file to import", "Text Files (*.txt)")

    MainUI.Opt("+AlwaysOnTop")

    if filePath = ""
        return

    if !FileExist(filePath) {
        return
    }

    try {
        content := FileRead(filePath, "UTF-8")
        lines := StrSplit(content, "`n")
        importedCount := 0
        replacedMaps := Map()  ; keep track of which maps are replaced

        for line in lines {
            line := Trim(line, "`r`n ") ; remove CRLF and spaces
            if (line = "")
                continue

            parts := StrSplit(line, ",")
            if (parts.Length < 4) {
                AddToLog("⚠ Skipping malformed line: " line)
                continue
            }

            mapName := parts[1]
            key := parts[2]
            duration := parts[3]
            delay := parts[4]

            ; If this is the first time we see this map in this import, clear old data
            if !replacedMaps.Has(mapName) {
                allWalks[mapName] := []  ; replace existing map
                replacedMaps[mapName] := true
            }

            allWalks[mapName].Push({ key: key, duration: duration, delay: delay })
            importedCount++
        }

        AddToLog("✅ Imported " importedCount " movement(s)")
        SaveAllMovements()
    } catch Error {
        AddToLog("❌ Import failed")
    }
}

ClearMovement(*) {
    global allWalks
    mapName := WalkMapDropdown.Text

    if !allWalks.Has(mapName) {
        AddToLog("No recording found for map: " mapName)
        return
    }

    AddToLog("Clearing movements for map: " mapName)
    allWalks.Delete(mapName)
    SaveAllMovements()
    UpdateWalkListView()
}

UpdateWalkListView(*) {
    global allWalks, WalkMapDropdown, WalkListView

    WalkListView.Delete()          ; clear current rows

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName) || allWalks[mapName].Length = 0
        return

    directionMap := Map(
        "w", "Forward",
        "a", "Left",
        "s", "Backward",
        "d", "Right"
    )

    for i, entry in allWalks[mapName] {
        dir := directionMap.Has(entry.key) ? directionMap[entry.key] : entry.key
        WalkListView.Add(, i, dir, entry.duration " ms", entry.delay " ms")
    }

    ; Auto-size columns
    loop 4
        WalkListView.ModifyCol(A_Index, "AutoHdr")
}

RemoveSelectedMovement(*) {
    global allWalks, WalkMapDropdown, WalkListView

    row := WalkListView.GetNext()          ; get selected row number
    if !row
        return

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName)
        return

    ; Remove the selected entry (ListView rows are 1-based, array is 1-based too)
    allWalks[mapName].RemoveAt(row)

    SaveAllMovements()
    UpdateWalkListView()                   ; refresh the list
    AddToLog("Removed movement #" row " from " mapName)
}

EditSelectedMovement(*) {
    global allWalks, WalkMapDropdown, WalkListView

    row := WalkListView.GetNext()
    if !row
        return

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName) || row > allWalks[mapName].Length
        return

    entry := allWalks[mapName][row]

    ; Create a small edit popup
    editGui := Gui("+AlwaysOnTop -MinimizeBox", "Edit Movement #" row)
    editGui.SetFont("s10")

    editGui.Add("Text", "x20 y20", "Direction:")
    dirDDL := editGui.Add("DropDownList", "x100 y18 w120", ["Forward", "Left", "Backward", "Right"])

    ; Set current direction
    directionMap := Map("w", "Forward", "a", "Left", "s", "Backward", "d", "Right")
    reverseMap := Map("Forward", "w", "Left", "a", "Backward", "s", "Right", "d")
    currentDir := directionMap.Has(entry.key) ? directionMap[entry.key] : "Forward"
    dirDDL.Choose(currentDir)

    editGui.Add("Text", "x20 y55", "Duration (ms):")
    durEdit := editGui.Add("Edit", "x120 y53 w100 Number", entry.duration)

    editGui.Add("Text", "x20 y90", "Delay (ms):")
    delayEdit := editGui.Add("Edit", "x120 y88 w100 Number", entry.delay)

    saveBtn := editGui.Add("Button", "x40 y130 w80", "Save")
    cancelBtn := editGui.Add("Button", "x140 y130 w80", "Cancel")

    saveBtn.OnEvent("Click", (*) => SaveEditedMovement())
    cancelBtn.OnEvent("Click", (*) => editGui.Destroy())
    editGui.OnEvent("Close", (*) => editGui.Destroy())

    editGui.Show("w260 h180")

    SaveEditedMovement() {
        newDir := dirDDL.Text
        newDur := Integer(durEdit.Value)
        newDelay := Integer(delayEdit.Value)

        if (newDur < 0 || newDelay < 0) {
            MsgBox("Duration and Delay must be 0 or higher.")
            return
        }

        ; Update the actual data
        allWalks[mapName][row].key := reverseMap[newDir]
        allWalks[mapName][row].duration := newDur
        allWalks[mapName][row].delay := newDelay

        SaveAllMovements()
        UpdateWalkListView()
        editGui.Destroy()
        AddToLog("Updated movement #" row " on map: " mapName)
    }
}