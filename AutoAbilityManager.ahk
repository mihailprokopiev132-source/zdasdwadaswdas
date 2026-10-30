#Requires AutoHotkey v2.0

ActiveAbilityEnabled() {
    if (!autoAbilityDisabled) {
        return true
    }
    return false
}

HandleAutoAbility() {
    if (!ActiveAbilityEnabled()) {
        AddToLog("Auto Ability Disabled")
        return
    }

    wiggle()

    foundAbility := false

    if (ok := FT(&X, &Y, 369, 223, 401, 249, 0.10, 0.10, AutoOff)) {
        FixClick(X, Y)  ; Turn ability on
        AddToLog("Auto Ability Enabled")
        foundAbility := true
    }

    return foundAbility
}

HandleAutoAbilityUnitManager() {
    wiggle()

    ; Grid configuration
    baseX := 675            ; Left column starting X
    xOffset := 95             ; Distance between columns
    baseY := 130            ; Top row starting Y
    yStep := 60             ; Vertical gap between rows
    numRows := 8              ; Total rows to scan
    numCols := 2              ; Columns per row
    color := 0xC22725       ; Target pixel color

    ; Scan grid
    loop numRows {
        rowIndex := A_Index - 1
        rowY := baseY + rowIndex * yStep

        loop numCols {
            colIndex := A_Index - 1
            colX := baseX + colIndex * xOffset

            if GetPixel(color, colX, rowY, 4, 4, 20) {
                FixClick(colX, rowY)
                Sleep(100)
            }
        }
    }
}