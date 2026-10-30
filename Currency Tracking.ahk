#Requires AutoHotkey v2.0

RefreshCurrency(x1 := 452, y1 := 507, x2 := 497, y2 := 532, clientRel := true, resultEdit := false) {

    x := Min(x1, x2), y := Min(y1, y2)
    w := Abs(x2 - x1), h := Abs(y2 - y1)

    ; Send messages to ResultEdit when requested
    LogResult(message) {
        if resultEdit
            ResultEdit.Value .= message "`n"
        else
            AddToLog(message)
    }

    if clientRel {
        WinGetClientPos(&rX, &rY, , , rblxID)
        x += rX, y += rY
    }

    ;ShowRegion(x, y, w, h)

    LogResult("Checking for numbers...")
    lastError := ""

    loop 10 {
        try {
            result := OCR.FromRect(x, y, w, h, {
                grayscale: true,
                scale: 2.0,
                monochrome: 128,
                invertcolors: false
            })

            text := result ? Trim(result.Text, " `t`r`n") : ""

            if (text != "") {
                LogResult("Captcha text: [" text "]")
                firstLine := StrSplit(text, "`n", "`r")[1]

                ; Correct common OCR confusion between O and 0
                firstLine := StrReplace(StrReplace(firstLine, "O", "0"), "o", "0")
                number := RegExReplace(firstLine, "[^\d]")

                if (StrLen(number) >= 1 && StrLen(number) <= 7) {
                    LogResult("Detected currency: " number)
                    return true
                }
            }
        } catch as e {
            if (e.Message != lastError) {
                LogResult("OCR error: " e.Message)
                lastError := e.Message
            }
        }

        Sleep(200)
    }

    LogResult("Could not detect valid captcha after 10 attempts.")
    return false
}