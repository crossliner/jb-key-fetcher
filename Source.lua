local fetcher = { marked = { } }; do 
    function fetcher.markFunction(func, keyName) 
        fetcher.marked[func] = { name = keyName };
    end;
end;

local Players = game:GetService("Players");
local HttpService = game:GetService("HttpService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");

local RBX = {
    NetworkKeys = {};
    ScriptHash = getscripthash(Players.LocalPlayer.PlayerScripts.LocalScript);
    ItemSystem = require(ReplicatedStorage.Game.ItemSystem.ItemSystem);
    TeamChooseUI = require(ReplicatedStorage.Game.TeamChooseUI);
};

do 
    RBX.Network = getupvalue(RBX.ItemSystem.Init, 1);
end;

do -- scanning
    local gc = getgc(); 

    for i = 1, #gc do 
        local v = gc[i];

        if typeof(v) == "function" and not is_synapse_function(v) and islclosure(v) then 
            local constants = getconstants(v);

            if table.find(constants, "Punch") and table.find(constants, "Play") then 
                RBX.Action = v;
            end;

            if table.find(constants, "FailedPcall") then
                RBX.AntiCheatRunner = v;
            end;
            
            if table.find(constants, "Eject") and table.find(constants, "MouseButton1Down") then 
                RBX.CarKick = v;
            end;

            if table.find(constants, "ShouldEject") and table.find(constants, "Vehicle") then 
                RBX.Eject = v;
            end;
        end;

        if RBX.Action and RBX.AntiCheatRunner and RBX.CarKick and RBX.Eject then break end;
    end;
end;

local oldFireServer = getupvalue(RBX.Network.FireServer, 1);

do -- network hook 
    setupvalue(RBX.Network.FireServer, 1, function(Key, ...) 
        local protoMeta = getinfo(2, "f");
        
        if protoMeta.func == RBX.Network.FireServer then protoMeta = getinfo(3, "f") end; --// for some stuff (can be improved)

        if protoMeta and fetcher.marked[protoMeta.func] and checkcaller() then 
            local markInfo = fetcher.marked[protoMeta.func];

            RBX.NetworkKeys[markInfo.name] = Key;
            fetcher.marked[protoMeta.func] = nil;
            return;
        end;

        return oldFireServer(Key, ...);
    end);
end;

do -- key fetching
    do  -- punch
        fetcher.markFunction(RBX.Action, "Punch");

        setconstant(RBX.Action, 66, "Stop");
        RBX.Action({ Name = "Punch" }, true);
        setconstant(RBX.Action, 66, "Play");
    end;

    do -- Kick
        fetcher.markFunction(RBX.AntiCheatRunner, "Kick");
    
        local oldEnv = getfenv(RBX.AntiCheatRunner);
        setfenv(RBX.AntiCheatRunner, {
            pcall = function() return false end;
        });
    
        RBX.AntiCheatRunner();
    
        setfenv(RBX.AntiCheatRunner, oldEnv);
    end;
    
    do -- CarKick
        local proto = getproto(RBX.CarKick, 1);

        setupvalue(proto, 1, {
            FireServer = function(self, Key) RBX.NetworkKeys.CarKick = Key end;
        });

        proto();
    end;

    do -- Eject
        local eject = getupvalue(RBX.Eject, 2);

        fetcher.markFunction(eject, "Eject");

        eject();
    end;

    do -- ChangeTeam
        local proto = getproto(RBX.TeamChooseUI.Show, 6);

        setupvalue(proto, 2, { 
            FireServer = function(self, Key) RBX.NetworkKeys.ChangeTeam = Key end;
        });

        proto();
    end;
end;

setupvalue(RBX.Network.FireServer, 1, oldFireServer);

do -- saving
    local name = syn.crypto.base64.encode(syn.crypto.random(12));

    writefile("key_dump_" .. name .. ".json", HttpService:JSONEncode({
        script_hash = RBX.ScriptHash,
        keys = RBX.NetworkKeys
    }));

    messagebox("Saved the dump in your workspace file: " .. "key_dump_" .. name .. ".json", "JB Key Dumper", 0x00)    
end;
