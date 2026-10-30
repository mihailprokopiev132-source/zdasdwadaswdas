#Requires AutoHotkey v2.0

UpgradeUnits() {

    SetTotalUnits()

    if (ShouldOpenUnitManager()) {
        OpenMenu("Unit Manager")
    }

    if (PriorityUpgrade.Value) {
        UpgradeWithPriority()
    } else {
        UpgradeWithoutPriority()
    }

    return MonitorStage()
}

UpgradeWithoutPriority() {
    global successfulCoordinates

    slotOrder := [1, 2, 3, 4, 5, 6] ; or however many slots you have

    for slot in slotOrder {
        if (HasUnitsInSlot(slot, "", successfulCoordinates)) {
            ProcessUpgrades(slot, "")
            upgraded := true
        }
    }

    AddToLog("All units maxed, proceeding to monitor stage")
}

UpgradeWithPriority() {
    global successfulCoordinates
    AddToLog("Using priority upgrade system")
    slotOrder := [1, 2, 3, 4, 5, 6]
    priorityOrder := [1, 2, 3, 4, 5, 6]

    for priorityNum in priorityOrder {
        for slot in slotOrder {
            if (HasUnitsInSlot(slot, priorityNum, successfulCoordinates)) {
                AddToLog("Starting upgrades for priority " priorityNum " (slot " slot ")")
                ProcessUpgrades(slot, priorityNum)
            }
        }
    }

    AddToLog("All units maxed, proceeding to monitor stage")
    CloseMenu("Unit Manager")
}

SetAutoUpgradeForAllUnits() {
    global successfulCoordinates

    ; Sort by placementIndex to get visual order
    sorted := successfulCoordinates.Clone()

    ; Simple bubble sort by placementIndex
    Loop sorted.Length {
        for i, val in sorted {
            if (i = sorted.Length)
                continue
            if (sorted[i].placementIndex > sorted[i + 1].placementIndex) {
                temp := sorted[i]
                sorted[i] := sorted[i + 1]
                sorted[i + 1] := temp
            }
        }
    }

    ; GUI positioning constants
    baseX := 610
    baseY := 215
    colSpacing := 80
    rowSpacing := 115
    maxCols := 3
    totalCount := sorted.Length

    fullRows := Floor(totalCount / maxCols)
    lastRowUnits := Mod(totalCount, maxCols)

    ; Loop through units in visual order
    for index, unit in sorted {
        slot := unit.slot
        priority := unit.upgradePriority

        ; Calculate click position based on visual index
        placementIndex := index - 1 ; zero-based
        row := Floor(placementIndex / maxCols)
        colInRow := Mod(placementIndex, maxCols)
        isLastRow := (row = fullRows)

        if (lastRowUnits != 0 && isLastRow) {
            rowStartX := baseX + ((maxCols - lastRowUnits) * colSpacing / 2)
            clickX := rowStartX + (colInRow * colSpacing)
        } else {
            clickX := baseX + (colInRow * colSpacing)
        }

        clickY := baseY + (row * rowSpacing)

        if (priority > 4 && priority != 7) {
            priority := 4
        }

        if (priority == 7) {
            priority := 0
        }

        AddToLog("Set slot: " slot " priority to " priority)

        Loop priority {
            FixClick(clickX, clickY)
            Sleep(150)
        }
    }
}

UpgradeAllUnits() {
    FixClick(648, 123) ; Clicks upgrade all
    Sleep(1000)
}

HandleUnitManager(msg) {
    AddToLog(msg)
    CloseMenu("Unit Manager")
    return MonitorStage()
}

GetUpgradePriority(slotNum) {
    global
    priorityVar := "upgradePriority" slotNum
    return %priorityVar%.Value
}

UnitManagerUpgrade(slot) {
    if !(GetPixel(0x1643C5, 77, 357, 4, 4, 2)) {
        ClickUnit(slot)
        Sleep(500)
    }
    SendInput("R")
}

UnitManagerUpgradeWithLimit(coord, index, upgradeLimit) {
    if !(GetPixel(0x1643C5, 77, 357, 4, 4, 2)) {
        ClickUnit(coord.placementIndex)
        Sleep(500)
    }
    if (WaitForUpgradeLimitText(upgradeLimit + 1, 750)) {
        HandleMaxUpgrade(coord, index)
    } else {
        SendInput("R")
    }
}  

ProcessUpgrades(slot := false, priorityNum := false) {
    global successfulCoordinates

    ; Full upgrade loop
    while (true) {
        slotDone := true

        for index, coord in successfulCoordinates {

            if (coord.autoUpgrade) {
                continue
            }

            if ((!slot || coord.slot = slot) && (!priorityNum || coord.upgradePriority = priorityNum)) {
                slotDone := false  ; Found unit to upgrade => not done yet

                UpgradeUnitWithLimit(coord, index)

                PostUpgradeChecks(coord)

                if (MaxUpgrade()) {
                    HandleMaxUpgrade(coord, index)
                }

                PostUpgradeChecks(coord)
            }
        }

        if ((slot || priorityNum) && (slotDone || successfulCoordinates.Length = 0)) {
            AddToLog("Finished upgrades for priority " priorityNum)
            break
        }

        if (!slot && !priorityNum)
            break
    }
}

WaitForUpgradeText(timeout := 4500) {
    startTime := A_TickCount
    while (A_TickCount - startTime < timeout) {
        ; wider area + more tolerance
        if GetPixel(0x17D6FE, 20, 360, 30, 25, 15) {
            if CheckForElyssiaSummon()
                return false
            if (debugMessages)
                AddToLog("Upgrade text found in " (A_TickCount - startTime) " ms")
            return true
        }
        Sleep 50
    }
    if (debugMessages)
        AddToLog("Timed out, no upgrade text. Timeout: " timeout " ms")
    return false
}

WaitForUpgradeLimitText(upgradeCap, timeout := 4500) {
    upgradeTexts := [
        [Upgrade0],
        [Upgrade1],
        [Upgrade2],
        [Upgrade3],
        [Upgrade4],
        [Upgrade5],
        [Upgrade6],
        [Upgrade7],
        [Upgrade8],
        [Upgrade9]
    ]

    if (upgradeCap < 1 || upgradeCap > upgradeTexts.Length)
        return false

    targetTexts := upgradeTexts[upgradeCap]

    if (!IsObject(targetTexts) || targetTexts.Length = 0)
        return false

    startTime := A_TickCount

    while (A_TickCount - startTime < timeout) {
        for _, targetText in targetTexts {
            if (Trim(targetText) = "")
                continue

            if (FT(&X, &Y, 186, 351, 317, 387, 0, 0, MaxText) or (ok := FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew))) {
                AddToLog("Found Max Text " MaxText)
                return true
            }

            if (FT(&X, &Y, 166, 195, 316, 223, 0, 0, targetText)) {
                AddToLog("Found Upgrade Cap " upgradeCap)
                return true
            }
        }

        Sleep(100)
    }

    return false
}

TestUpgradeLimitTexts(resultEdit := true) {

    upgradeTexts := [
        [Upgrade0],
        [Upgrade1],
        [Upgrade2],
        [Upgrade3],
        [Upgrade4],
        [Upgrade5],
        [Upgrade6],
        [Upgrade7],
        [Upgrade8],
        [Upgrade9]
    ]

    ResultEdit.Value .= "Testing all upgrade limit texts...`n"

    foundCount := 0
    upgradeFound := false

    ; Check upgrade texts first
    for level, targetTexts in upgradeTexts {
        for variant, targetText in targetTexts {
            if (Trim(targetText) = "")
                continue

            if (FT(&X, &Y, 166, 195, 316, 223, 0, 0, targetText)) {
                ResultEdit.Value .= "Found Upgrade" (level - 1) " variant " variant " at X: " X ", Y: " Y "`n"

                foundCount++
                upgradeFound := true
            }
        }
    }

    ; Only check MaxText if no upgrade text was found
    if (!upgradeFound) {
        if (FT(&X, &Y, 189, 351, 310, 387, 0, 0, MaxText)
        || FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew)) {

            ResultEdit.Value .= "Found Max Text (upgrade limit detected).`n"
            foundCount++
        }
    }

    ResultEdit.Value .= "Found " foundCount " matching pattern(s).`n`n"
}

UpgradeUnitWithLimit(coord, index) {
    slot := coord.slot
    placementIndex := coord.placementIndex
    x := coord.x
    y := coord.y

    isLimitDisabled := !IsUpgradeLimitEnabled(slot) || unitUpgradeLimitDisabled
    isManagerDisabled := unitManagerDisabled
    useUnitManager := !isManagerDisabled && UnitManagerUpgradeSystem.Value

    if isLimitDisabled {
        if useUnitManager {
            UnitManagerUpgrade(placementIndex)
        } else {
            UpgradeUnit(x, y)
        }
        return
    }

    limit := GetUpgradeLimit(slot)
    if useUnitManager {
        UnitManagerUpgradeWithLimit(coord, index, limit)
    } else {
        UpgradeUnitLimit(coord, index, limit)
    }
}

UpgradeUnitLimit(coord, index, upgradeLimit) {
    FixClick(coord.x, coord.y)
    if (WaitForUpgradeLimitText(upgradeLimit + 1, 1500)) {
        HandleMaxUpgrade(coord, index)
    } else {
        SendInput("R")
    }
}

IsUpgradeLimitEnabled(slotNum) {
    setting := "upgradeLimitEnabled" slotNum
    return %setting%.Value
}

GetUpgradeLimit(slotNum) {
    setting := "upgradeLimit" slotNum
    return %setting%.Text
}

HandleMaxUpgrade(coord, index) {
    global successfulCoordinates, maxedCoordinates

    AddToLog("Max upgrade reached for Unit: " coord.slot)
    maxedCoordinates.Push(coord)
    if (index >= 1 && index <= successfulCoordinates.Length) {
        successfulCoordinates.RemoveAt(index)
    }
}

PostUpgradeChecks(coord) {

    if (CheckForXP()) {
        return HandleStageEnd()
    }
    
    if (coord.hasAbility) {
        HandleAutoAbility()
    }

    if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text)) {
        CheckForCardSelection()
    }

    if (StageEndedDuringUpgrades()) {
        return HandleStageEnd()
    }

    Reconnect()
}

StageEndedDuringUpgrades() {
    if (CheckForXP())
        return true

    if (EndButtonsVisible()) {
        return true
    }
    return false
}

IsUpgradeEnabled(slotNum) {
    setting := "upgradeEnabled" slotNum
    return %setting%.Value
}

TestAllUpgradeFindTexts() {
    foundCount := 0
    notFoundCount := 0

    Loop 15 {
        upgradeCap := A_Index  ; Now 1–15, aligns with AHK v2 arrays
        result := WaitForUpgradeLimitText(upgradeCap, 500)

        if (result) {
            AddToLog("Found Upgrade Level: " upgradeCap - 1)
            foundCount++
        } else {
            AddToLog("Did NOT Find Upgrade Level: " upgradeCap - 1)
            notFoundCount++
        }
    }

    AddToLog("Found: " foundCount " | Not Found: " notFoundCount)
}

ShouldOpenUnitManager() {
    if (UnitManagerUpgradeSystem.Value && !unitManagerDisabled) {
        return true
    }
}

HasUnitsInSlot(slot, priorityNum, coordinates) {
    for coord in coordinates {
        if (coord.slot = slot && !coord.autoUpgrade) {
            if (priorityNum = false || priorityNum = "") {
                return true   ; ignore priority requirement
            }
            if (coord.upgradePriority = priorityNum) {
                return true
            }
        }
    }
    return false
}

SetAutoUpgradeForSingleUnit(unitIndex := 1) {
    global successfulCoordinates

    ; Clone and sort by placementIndex
    sorted := successfulCoordinates.Clone()
    loop sorted.Length {
        for i, val in sorted {
            if (i = sorted.Length)
                continue
            if (sorted[i].placementIndex > sorted[i + 1].placementIndex) {
                temp := sorted[i]
                sorted[i] := sorted[i + 1]
                sorted[i + 1] := temp
            }
        }
    }

    ; GUI positioning constants
    baseX := 610
    baseY := 225
    colSpacing := 80
    rowSpacing := 115
    maxCols := 3
    totalCount := sorted.Length

    if (unitIndex < 1 || unitIndex > totalCount) {
        return
    }

    fullRows := Floor(totalCount / maxCols)
    lastRowUnits := Mod(totalCount, maxCols)

    unit := sorted[unitIndex]
    slot := unit.slot
    priority := unit.upgradePriority

    placementIndex := unitIndex - 1
    row := Floor(placementIndex / maxCols)
    colInRow := Mod(placementIndex, maxCols)
    isLastRow := (row = fullRows)

    if (lastRowUnits != 0 && isLastRow) {
        rowStartX := baseX + ((maxCols - lastRowUnits) * colSpacing / 2)
        clickX := rowStartX + (colInRow * colSpacing)
    } else {
        clickX := baseX + (colInRow * colSpacing)
    }

    clickY := baseY + (row * rowSpacing)

    ; Normalize priority values
    if (priority > 4 && priority != 7)
        priority := 4
    if (priority == 7)
        priority := 0

    if (priority = 0) {
        return
    }

    ; Perform upgrade clicks
    loop priority {
        FixClick(clickX, clickY)
        Sleep(150)
    }
}

SetTotalUnits() {
    global totalUnits, successfulCoordinates

    for coord in successfulCoordinates {
        totalUnits[coord.slot] := (totalUnits.Has(coord.slot) ? totalUnits[coord.slot] + 1 : 1)
    }
}

MaxUpgrade() {
    Sleep 500
    ; Check for max text
        if (FT(&X, &Y, 189, 351, 310, 387, 0, 0, MaxText)
            || FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew)) {
        if (CheckForElyssiaSummon()) {
            return false
        }
        return true
    }
    return false
}

CheckForElyssiaSummon() {
    if FT(&X, &Y, 16, 195, 131, 216, 0, 0, ElyssiaSummons) {
        AddToLog("Clicked on Elyssia Eel, ignoring...")
        return true
    }
}

UpgradeUnit(x, y) {
    FixClick(x, y)
    SendInput("{R}")
}

TestUpgrade(index) {
    global successfulCoordinates

    ; --- Create dummy test data so the main function works ---
    successfulCoordinates := [{ placementIndex: 1, slot: 1, upgradePriority: 1 }, { placementIndex: 2, slot: 2,
        upgradePriority: 2 }, { placementIndex: 3, slot: 3, upgradePriority: 3 }, { placementIndex: 4, slot: 4,
            upgradePriority: 4 }, { placementIndex: 5, slot: 5, upgradePriority: 1 }, { placementIndex: 6, slot: 6,
                upgradePriority: 2 }
    ]

    AddToLog("Testing upgrade on index: " index)

    ; --- Call your real method using the number you want ---
    SetAutoUpgradeForSingleUnit(index)
}
