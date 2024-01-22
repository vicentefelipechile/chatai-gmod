--[[----------------------------------------------------------------------------
                                  Core Chat AI
----------------------------------------------------------------------------]]--

include("enum_color.lua")

ChatAI = ChatAI or { __cfg = {} }

--[[------------------------
       Main Functions
------------------------]]--

-- Localize functions
local print = print
local EmptyFunc = function() end

local isfunction = isfunction
local isentity = isentity
local isstring = isstring
local isnumber = isnumber
local isangle = isangle
local istable = istable
local isbool = isbool

function ChatAI:GeneratePrint(cfg)
    if not istable(cfg) then return print end

    cfg.prefix = cfg.prefix or "[AI] "
    cfg.prefix_clr = cfg.prefix_clr or color_white
    cfg.color = cfg.color or color_white
    cfg.func = cfg.func or EmptyFunc

    return function(...)
        local args = {...}
        local str = ""

        for _, arg in ipairs(args) do
            str = str .. tostring(arg) .. " "
        end

        local response = cfg.func(args)
        if ( response == false ) then return end

        MsgC(cfg.prefix_clr, cfg.prefix, cfg.color, str .. "\n")
    end
end


local LocalPrint = ChatAI:GeneratePrint({color = COLOR_STATE})
ChatAI.Print = function(self, ...)
    LocalPrint(...)
end

    -- Usar expresiones regulares para detectar el nombre de la funcion de donde fue llamada en la linea
    -- Los posibles llamados son:
    -- ChatAI:NombreDeFuncion(...)      -> ChatAI.NombreDeFuncion
    -- Variable.NombreDeFuncion(...)    -> Variable.NombreDeFuncion
    -- NombreDeFuncion(...)             -> NombreDeFuncion
    -- self:NombreDeFuncion(...)        -> self.NombreDeFuncion
local FuncMatchRegEx = {
    "ChatAI:(.*)%(",
    "(.*)%.(.*)%(",
    "(.*)%(",
    "self:(.*)%("
}

function ChatAI:Error(Message, Value, Expected)
    local Data = debug.getinfo(3)

    local FilePath = ( Data["source"] == "@lua_run" ) and "Console" or "lua/" .. string.match(Data["source"], "lua/(.*)")
    local File = ( FilePath == "Console" ) and "Console" or file.Read(FilePath, "GAME")
    local Line = string.Trim( string.Explode("\n", File)[Data["currentline"]] )

    local ErrorLine = "\t\t" .. Data["currentline"]
    local ErrorPath = "\t" .. FilePath
    local ErrorFunc = ""
    local ErrorArg = "\t" .. tostring(Value) .. " (" .. type(Value) .. ")"

    for _, regex in ipairs(FuncMatchRegEx) do
        ErrorFunc = string.match(Line, regex)
        if ErrorFunc then break end
    end

    ErrorFunc = "\t" .. (ErrorFunc or "Unknown") .. "(...)"
    Expected = "\t" .. Expected

    error("\n" .. string.format([[
========  ChatAI ThrowError  ========
- Error found in: %s
- In the line: %s
- In the function: %s

- Argument: %s
- Expected: %s

- Error Message: %s
  
========  ChatAI ThrowError  ========]], ErrorPath, ErrorLine, ErrorFunc, ErrorArg, Expected, Message))
end

function ChatAI:AddConfig(Name, Category, Verification, Default)
    if not isstring(Name) then
        self:Error([[The first argument of ChatAI:AddConfig() must be a string.]], Name, "string")
    end

    if ( Name == "" ) then
        self:Error([[The first argument of ChatAI:AddConfig() must not be empty.]], Name, "string")
    end

    if not isstring(Category) then
        self:Error([[The second argument of ChatAI:AddConfig() must be a string.]], Category, "string")
    end

    if ( Category == "" ) then
        self:Error([[The second argument of ChatAI:AddConfig() must not be empty.]], Category, "string")
    end

    if not isfunction(Verification) then
        self:Error([[The third argument of ChatAI:AddConfig() must be a function.]], Verification, "function")
    end

    if not Verification(Default) then
        self:Error([[The fourth argument of ChatAI:AddConfig() must be the same type as the return of the third argument.]], Default, "any")
    end

    self.__cfg[Category] = self.__cfg[Category] or {}
    self.__cfg[Category][Name] = {Default, Verification}
end

function ChatAI:GetConfig(Name, Category)
    if not isstring(Name) then
        self:Error([[The first argument of ChatAI:GetConfig() must be a string.]], Name, "string")
    end

    if ( Name == "" ) then
        self:Error([[The first argument of ChatAI:GetConfig() must not be empty.]], Name, "string")
    end

    if ( Category == nil ) then
        Category = self.__cfg["General"]["DefaultCategory"][1]
    else
        if not isstring(Category) then
            self:Error([[The second argument of ChatAI:GetConfig() must be a string.]], Category, "string")
        end

        if ( Category == "" ) then
            self:Error([[The second argument of ChatAI:GetConfig() must not be empty.]], Category, "string")
        end
    end

    if not self.__cfg[Category] then
        self:Error([[The category does not exist.]], Category, "string")
    end

    if not self.__cfg[Category][Name] then
        self:Error([[The config does not exist.]], Name, "string")
    end

    return self.__cfg[Category][Name][1]
end

function ChatAI:SetConfig(Name, Value, Category)
    if not isstring(Name) then
        self:Error([[The first argument of ChatAI:SetConfig() must be a string.]], Name, "string")
    end

    if ( Name == "" ) then
        self:Error([[The first argument of ChatAI:SetConfig() must not be empty.]], Name, "string")
    end

    if ( Category == nil ) then
        Category = self.__cfg["General"]["DefaultCategory"]
    else
        if not isstring(Category) then
            self:Error([[The second argument of ChatAI:SetConfig() must be a string.]], Category, "string")
        end

        if ( Category == "" ) then
            self:Error([[The second argument of ChatAI:SetConfig() must not be empty.]], Category, "string")
        end
    end

    if not self.__cfg[Category] then
        self:Error([[The category does not exist.]], Category, "string")
    end

    if not self.__cfg[Category][Name] then
        self:Error([[The config does not exist.]], Name, "string")
    end

    if not self.__cfg[Category][Name][2](Value) then
        self:Error([[The value does not match the verification function.]], Value, "any")
    end

    self.__cfg[Category][Name][1] = Value
end


function ChatAI:PreInit()
    local Print = ChatAI:GeneratePrint({prefix = ""})

    Print("==[[==================================")
    Print("            Loading Chat AI")
    Print("==================================]]==")

    self:Print("Generating Default Config " .. (SERVER and "[CL]" or "[SV]"))

    self.VERIFICATION_TYPE = {
        ["function"] = isfunction,
        ["entity"] = isentity,
        ["string"] = isstring,
        ["number"] = isnumber,
        ["angle"] = isangle,
        ["table"] = istable,
        ["bool"] = isbool
    }

    self:AddConfig("Enabled", "General", self.VERIFICATION_TYPE.bool, true)
    self:AddConfig("DefaultCategory", "General", self.VERIFICATION_TYPE.string, "General")

    hook.Run("ChatAI.PreInit")
end


function ChatAI:Init()
    hook.Run("ChatAI.Init")
end


function ChatAI:PostInit()
    hook.Run("ChatAI.PostInit")
end


ChatAI:PreInit()
hook.Add("ChatAI.PreInit", "ChatAI.PreInit_TO_Init", ChatAI.Init)
hook.Add("ChatAI.Init", "ChatAI.Init_TO_PostInit", ChatAI.PostInit)
