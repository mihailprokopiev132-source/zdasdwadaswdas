#Requires AutoHotkey v2.0

FindMatch() {
    global ModeDropdown

    ; Modes allowed to use walking recovery
    walkModes := [
        "Event",
        "Infinity Castle"
    ]

    canWalk := false
    for mode in walkModes {
        if (ModeDropdown.Text = mode) {
            canWalk := true
            break
        }
    }

    loop {
        promptStart := A_TickCount
        promptFound := false

        ; Wait for matchmaking prompt
        while (A_TickCount - promptStart < 10000) {
            if (CheckForMatchmakingPrompt()) {
                promptFound := true
                break
            }

            FixClick(400, 435)  ; Play Here or Find Match

            Sleep(250)
        }

        ; Prompt didn't appear
        if (!promptFound) {
            AddToLog("Matchmaking prompt not detected.")
            FixClick(585, 190)  ; Close UI

            if (canWalk) {
                AddToLog("Walking recovery: moving right, then left...")
                Walk("D", 500)
                Walk("A", 1500)
                continue
            }

            AddToLog("Walking recovery disabled for this mode. Restarting mode...")
            return StartSelectedMode()
        }

        FixClick(400, 435)  ; Play Here or Find Match
        Sleep(300)
        FixClick(460, 330)  ; Click Find Match
        Sleep(300)

        ; Check captcha
        if (!CaptchaDetect(235, 262, 569, 309, 400, 335)) {
            AddToLog("Captcha not detected.")
            FixClick(585, 190)  ; Close UI

            if (canWalk) {
                AddToLog("Walking recovery: moving right, then left...")
                Walk("D", 500)
                Walk("A", 1500)
                continue
            }

            AddToLog("Walking recovery disabled for this mode. Restarting mode...")
            return StartSelectedMode()
        }

        ; Captcha detected
        FixClick(300, 385)
        Sleep(2000)

        ; Wait for matchmaking success
        startTime := A_TickCount

        if (WaitUntilNotInLobby()) {
            AddToLog("Matchmaking successful.")
            return true
        }

        AddToLog("Matchmaking timeout. Restarting mode...")
        FixClick(400, 520)
        Sleep(500)
        return StartSelectedMode()
    }
}

HasMatchmaking(ModeName) {
    if (ModeName = "Portal" && !PortalLobby.Value)
        return false

    return true
}

CheckForMatchmakingPrompt() {
    return FT(&X, &Y, 230, 219, 562, 267, 0, 0, JoinMatchmaking)
}

WaitUntilNotInLobby() {
    startTime := A_TickCount

    while (ok := FT(&X, &Y, 11, 557, 45, 591, 0, 0, LobbySettings)) {
        if (A_TickCount - startTime >= 120000) {
            AddToLog("Still in lobby after 2 minutes, restarting mode...")
            return StartSelectedMode()
        }
        Sleep(500)
    }
    return true
}

CheckForLobbySettings() {
    return FT(&X, &Y, 0, 540, 100, 610, 0.10, 0.10, LobbySettings)
}

CheckForAreas() {
    return FT(&X, &Y, 744, 483, 787, 497, 0, 0, AreaText)
}