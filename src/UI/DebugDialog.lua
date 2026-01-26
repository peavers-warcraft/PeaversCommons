local PeaversCommons = _G.PeaversCommons
PeaversCommons.DebugDialog = PeaversCommons.DebugDialog or {}
local DebugDialog = PeaversCommons.DebugDialog

local DIALOG_WIDTH = 600
local DIALOG_HEIGHT = 400
local TITLE_BAR_HEIGHT = 24
local BUTTON_BAR_HEIGHT = 30
local PADDING = 8

local function CreateCopyPopup(parent)
    local popup = CreateFrame("Frame", "PeaversDebugCopyPopup", UIParent, "BackdropTemplate")
    popup:SetSize(500, 350)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Copy Debug Log (Ctrl+C)")

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -36, 50)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetScript("OnEscapePressed", function()
        popup:Hide()
    end)

    scrollFrame:SetScrollChild(editBox)
    popup.editBox = editBox

    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOM", 0, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        popup:Hide()
    end)

    popup:SetScript("OnShow", function(self)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end)

    popup:Hide()
    return popup
end

local function CreateTitleBar(parent)
    local titleBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    titleBar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cFF3ABDF7Peavers|r Debug Log")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function()
        parent:Hide()
    end)

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
    end)

    return titleBar
end

local function CreateButtonBar(parent)
    local buttonBar = CreateFrame("Frame", nil, parent)
    buttonBar:SetHeight(BUTTON_BAR_HEIGHT)
    buttonBar:SetPoint("TOPLEFT", 0, -TITLE_BAR_HEIGHT)
    buttonBar:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT)

    local clearBtn = CreateFrame("Button", nil, buttonBar, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 22)
    clearBtn:SetPoint("LEFT", PADDING, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PeaversCommons.Debug:Clear()
    end)

    local copyBtn = CreateFrame("Button", nil, buttonBar, "UIPanelButtonTemplate")
    copyBtn:SetSize(70, 22)
    copyBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
    copyBtn:SetText("Copy All")
    copyBtn:SetScript("OnClick", function()
        local text = PeaversCommons.Debug:GetEntriesAsText()
        if text == "" then
            text = "(No log entries)"
        end

        if not parent.copyPopup then
            parent.copyPopup = CreateCopyPopup(parent)
        end

        parent.copyPopup.editBox:SetText(text)
        parent.copyPopup:Show()
    end)

    buttonBar.clearBtn = clearBtn
    buttonBar.copyBtn = copyBtn

    return buttonBar
end

local function CreateMessageArea(parent)
    local messageArea = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    messageArea:SetPoint("TOPLEFT", PADDING, -(TITLE_BAR_HEIGHT + BUTTON_BAR_HEIGHT + 4))
    messageArea:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    messageArea:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    messageArea:SetBackdropColor(0, 0, 0, 0.8)
    messageArea:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local messageFrame = CreateFrame("ScrollingMessageFrame", nil, messageArea)
    messageFrame:SetPoint("TOPLEFT", 6, -6)
    messageFrame:SetPoint("BOTTOMRIGHT", -28, 6)
    messageFrame:SetFontObject(GameFontHighlightSmall)
    messageFrame:SetJustifyH("LEFT")
    messageFrame:SetFading(false)
    messageFrame:SetMaxLines(500)
    messageFrame:EnableMouseWheel(true)
    messageFrame:SetHyperlinksEnabled(false)

    messageFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    local scrollBar = CreateFrame("Slider", nil, messageArea, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", -4, -20)
    scrollBar:SetPoint("BOTTOMRIGHT", -4, 20)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetWidth(16)
    scrollBar:SetScript("OnValueChanged", function(self, value)
        messageFrame:SetScrollOffset(math.floor(value))
    end)

    messageFrame.scrollBar = scrollBar

    local function UpdateScrollBar()
        local numMessages = messageFrame:GetNumMessages()
        local numVisibleLines = messageFrame:GetNumLinesDisplayed()
        local maxScroll = math.max(0, numMessages - numVisibleLines)
        scrollBar:SetMinMaxValues(0, maxScroll)
    end

    local origAddMessage = messageFrame.AddMessage
    messageFrame.AddMessage = function(self, msg, ...)
        origAddMessage(self, msg, ...)
        UpdateScrollBar()
        scrollBar:SetValue(0)
    end

    local origClear = messageFrame.Clear
    messageFrame.Clear = function(self)
        origClear(self)
        scrollBar:SetMinMaxValues(0, 1)
        scrollBar:SetValue(0)
    end

    return messageFrame
end

function DebugDialog:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "PeaversDebugDialog", UIParent, "BackdropTemplate")
    frame:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    if frame.SetResizeBounds then
        frame:SetResizeBounds(400, 250, 1000, 800)
    elseif frame.SetMinResize then
        frame:SetMinResize(400, 250)
        frame:SetMaxResize(1000, 800)
    end

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    CreateTitleBar(frame)
    CreateButtonBar(frame)
    frame.messageFrame = CreateMessageArea(frame)

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", -6, 6)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    frame:Hide()
    self.frame = frame

    frame.AddMessage = function(self, msg)
        if self.messageFrame then
            self.messageFrame:AddMessage(msg)
        end
    end

    tinsert(UISpecialFrames, "PeaversDebugDialog")

    return frame
end

return DebugDialog
