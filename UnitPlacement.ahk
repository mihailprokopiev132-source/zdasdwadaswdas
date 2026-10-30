#Requires AutoHotkey v2.0

StartPlacingUnits(untilSuccessful := true) {
    global successfulCoordinates, maxedCoordinates
    successfulCoordinates := []
    maxedCoordinates := []
    global placedCounts := Map()

    ; --- Check if any slot is enabled ---
    anyEnabled := false
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value
        if (enabled) {
            anyEnabled := true
            break
        }
    }

    if (!anyEnabled) {
        AddToLog("No units enabled - skipping to monitoring")
        return MonitorStage()
    }

    ; --- Placement Order Logic ---
    if (PlacementSelection.Text = "By Priority") {
        global slotPriorityList := []

        ; Build list of enabled slots and their priorities
        for slotNum in [1, 2, 3, 4, 5, 6] {
            priorityVar := "priority" slotNum
            enabledVar := "enabled" slotNum

            priority := %priorityVar%
            enabled := %enabledVar%

            if (enabled.Value) {
                slotPriorityList.Push({ slot: slotNum, priority: priority.Value })
            }
        }

        ; Manually sort the list by priority (ascending)
        loop slotPriorityList.Length {
            for i, item in slotPriorityList {
                if (i = slotPriorityList.Length)
                    continue
                if (slotPriorityList[i].priority > slotPriorityList[i + 1].priority) {
                    temp := slotPriorityList[i]
                    slotPriorityList[i] := slotPriorityList[i + 1]
                    slotPriorityList[i + 1] := temp
                }
            }
        }

        ; Extract sorted slot numbers into placementOrder
        placementOrder := []

        for item in slotPriorityList {
            placementOrder.Push(item.slot)
        }
    } else {
        placementOrder := [1, 2, 3, 4, 5, 6]
    }

    placementStrategies := Map(
        "Custom", UseCustomPoints,
        "Circle", GenerateCirclePoints,
        "Grid", GenerateGridPoints,
        "Spiral", GenerateSpiralPoints,
        "Up and Down", GenerateUpandDownPoints
    )

    ; Get the selected text
    selection := PlacementPatternDropdown.Text

    ; Call mapped function if it exists, else use fallback
    if placementStrategies.Has(selection)
        placementPoints := placementStrategies[selection].Call()
    else
        placementPoints := GenerateRandomPoints()

    if (!placementPoints) {
        AddToLog("No placement points - skipping to monitoring")
        return MonitorStage()
    }

    ; Use user-defined placement order to iterate through slots
    for slotNum in placementOrder {
        enabled := "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value

        ; Get number of placements wanted for this slot
        placements := "placement" slotNum
        placements := %placements%
        placements := Integer(placements.Text)

        ; Get upgradeEnabled value for this slot
        upgradeEnabled := "upgradeEnabled" slotNum
        upgradeEnabled := %upgradeEnabled%
        upgradeEnabled := upgradeEnabled.Value

        abilityEnabled := "abilityEnabled" slotNum
        abilityEnabled := %abilityEnabled%
        abilityEnabled := abilityEnabled.Value

        ; Initialize count if not exists
        if !placedCounts.Has(slotNum)
            placedCounts[slotNum] := 0

        ; If enabled, place all units for this slot
        if (enabled && placements > 0) {
            HandleStartButton() ; Check for start button if placement failed
            AddToLog("Placing Unit " slotNum " (0/" placements ")")

            for point in placementPoints {
                ; Skip if this coordinate was already used successfully
                alreadyUsed := false
                for coord in successfulCoordinates {
                    if (coord.x = point.x && coord.y = point.y) {
                        alreadyUsed := true
                        break
                    }
                }
                for coord in maxedCoordinates {
                    if (coord.x = point.x && coord.y = point.y) {
                        alreadyUsed := true
                        break
                    }
                }
                if (alreadyUsed)
                    continue

                ; If untilSuccessful is false, try once and move on
                if (!untilSuccessful) {
                    if (placedCounts[slotNum] < placements) {
                        if PlaceUnit(point.x, point.y, slotNum) {
                            placementIndex := successfulCoordinates.Length + 1
                            successfulCoordinates.Push({
                                x: point.x,
                                y: point.y,
                                slot: slotNum,
                                upgradePriority: GetUpgradePriority(slotNum),
                                placementIndex: placementIndex,
                                autoUpgrade: upgradeEnabled,
                                hasAbility: abilityEnabled
                            })
                            placedCounts[slotNum] += 1
                            AddToLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")
                            if (upgradeEnabled) {
                                EnableAutoUpgrade(successfulCoordinates[successfulCoordinates.Length].placementIndex)
                            }
                            if (abilityEnabled) {
                                hadAbilityOnPlacement := HandleAutoAbility()
                                if (hadAbilityOnPlacement) {
                                    successfulCoordinates[successfulCoordinates.Length].hasAbility := false
                                }
                            }
                            SendInput("Q")
                        } else {
                            PostPlacementChecks()
                        }
                    }
                }
                ; If untilSuccessful is true, keep trying the same point until it works
                else {
                    while (placedCounts[slotNum] < placements) {
                        if PlaceUnit(point.x, point.y, slotNum) {
                            placementIndex := successfulCoordinates.Length + 1
                            successfulCoordinates.Push({
                                x: point.x,
                                y: point.y,
                                slot: slotNum,
                                upgradePriority: GetUpgradePriority(slotNum),
                                placementIndex: placementIndex,
                                autoUpgrade: upgradeEnabled,
                                hasAbility: abilityEnabled
                            })
                            placedCounts[slotNum] += 1
                            AddToLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")
                            if (upgradeEnabled) {
                                AddToLog("Enabled auto-upgrade for unit " slotNum)
                                EnableAutoUpgrade(slotNum)
                            }
                            if (abilityEnabled) {
                                hadAbilityOnPlacement := HandleAutoAbility()
                                if (hadAbilityOnPlacement) {
                                    successfulCoordinates[successfulCoordinates.Length].hasAbility := false
                                }
                            }
                            SendInput("Q")
                            break ; Move to the next placement spot
                        }
                        PostPlacementChecks()
                        Sleep(500) ; Prevents spamming clicks too fast
                    }
                }

                if isMenuOpen("End Screen")
                    return MonitorStage()
            }
        }
    }

    AddToLog("All units placed to requested amounts")
    if (EnableUpgrading.Value) {
        UpgradeUnits()
    } else {
        AddToLog("Upgrading is disabled, proceeding to monitoring stage...")
    }

}

PlaceUnit(x, y, slot := 1) {
    if (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt") {
        CheckForCardSelection()
    }

    Sleep 50
    SendInput(slot)
    Sleep 50
    FixClick(x, y)
    Sleep 50
    SendInput("q")

    if UnitPlaced() {
        Sleep 15
        return true
    }
    return false
}

UnitPlaced(debug := false) {
    if (WaitForUpgradeText(debug ? 1000 : GetPlacementSpeed())) { ; Wait up to 4.5 seconds for the upgrade text to appear
        AddToLog("Unit Placed Successfully")
        return true
    }
    return false
}

GetPlacementSpeed() {
    speeds := [1000, 1500, 2000, 2500, 3000, 4000]  ; Array of sleep values
    speedIndex := PlaceSpeed.Value  ; Get the selected speed value

    if speedIndex is number  ; Ensure it's a number
        return speeds[speedIndex]  ; Use the value directly from the array
}

PostPlacementChecks() {
    HandleStartButton()

    if (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt") {
        CheckForFoolBuffs()
    }

    if (CheckForAreas()) {
        AddToLog("Found in lobby, restarting mode if possible")
        return CheckLobby()
    }

    if (StageEndedDuringUpgrades()) {
        AddToLog("Stage ended during placement")
        return MonitorStage()
    }

    if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text)) {
        CheckForCardSelection()
    }

    Reconnect()

}

ResetPlacementTracking() {
    global successfulCoordinates, maxedCoordinates
    successfulCoordinates := []
    maxedCoordinates := []
}

EnableAutoUpgrade(slotNum) {
    global successfulCoordinates
    slotNum := successfulCoordinates[successfulCoordinates.Length].placementIndex
    OpenMenu("Unit Manager")
    Sleep(150)
    SetAutoUpgradeForSingleUnit(slotNum)
    CloseMenu("Unit Manager")
}