--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local BadgeService = game:GetService("BadgeService")

--// Variables
local module = {} :: BadgeManager

local RateQueue = require(script:WaitForChild("RateQueue"))
local AwardQueue = RateQueue.new("AwardQueue", 50)
local HasBadgeQueue = RateQueue.new("HasBadgeQueue", 50)

--// Types
export type BadgeManager = {
    AwardBadge: (self: any, Player: Player, BadgeId: number, Retry: number?) -> (boolean, string?);
    UserHasBadge: (self: any, Player: Player, BadgeId: number, Retry: number?) -> (boolean, string?);
    GetBadgeInfo: (self: any, BadgeId: number, Retry: number?) -> BadgeInfo;

    AwardBadgeAsync: (self: any, Player: Player, BadgeId: number, Retry: number?) -> RateQueue.Process;
    UserHasBadgeAsync: (self: any, Player: Player, BadgeId: number, Retry: number?) -> RateQueue.Process;
    GetBadgeInfoAsync: (self: any, BadgeId: number, Retry: number?) -> RateQueue.Process;

}

type BadgeInfo = {
    Name: string;
    Description: string;
    IconImageId: number;
    IsEnabled: boolean;
}

--// Functions
local function GetBadgeInfoInternal(BadgeId: number, Retry: number)
    local Success, BadgeInfo, Try = nil, nil, 0

    repeat
        Success, BadgeInfo = pcall(BadgeService.GetBadgeInfoAsync, BadgeService, BadgeId)

        if not Success or Try + 1 > Retry then
            Try += 1
            task.wait(Try)
        end
    until Success

    return Success and BadgeInfo or nil
end

local function AwardBadgeInternal(UserId: number, BadgeId: number, Retry: number)
    local BadgeInfo = module:GetBadgeInfo(BadgeId)

    if BadgeInfo.IsEnabled then
        local Process, Try = nil, 0
        
        repeat
            Process = AwardQueue:insert(BadgeService.AwardBadge, BadgeService, UserId, BadgeId):await()
            
            if not Process.success then
                Try += 1

                if Try > Retry then
                    break
                end
            end
        until Process.success

        if Process.success then
            return Process:getResults()
        else
            return false, Process:hasError()
        end
    else
        return false, "Badge is not enabled."
    end
end

local function UserHasBadgeInternal(UserId: number, BadgeId: number, Retry: number)
    local Process, Try = nil, 0

    repeat
        Process = HasBadgeQueue:insert(BadgeService.UserHasBadgeAsync, BadgeService, UserId, BadgeId):await()

        if not Process.success then
            Try += 1

            if Try > Retry then
                break
            end
        end
    until Process.success

    if Process.success then
        return Process:getResults()
    else
        return false, Process:hasError()
    end
end

local function UpdateRate()
    local PlayerCount = #Players:GetPlayers()

    AwardQueue.ratePerMinute = 50 + 35 * PlayerCount
    HasBadgeQueue.ratePerMinute = 50 + 35 * PlayerCount
end

function module:GetBadgeInfoAsync(BadgeId: number, Retry: number?)
    return RateQueue.Process(GetBadgeInfoInternal, BadgeId, Retry or 3):execute()
end

function module:AwardBadgeAsync(UserId: number, BadgeId: number, Retry: number?)
    return RateQueue.Process(AwardBadgeInternal, UserId, BadgeId, Retry or 3):execute()
end

function module:UserHasBadgeAsync(UserId: number, BadgeId: number, Retry: number?)
    return RateQueue.Process(UserHasBadgeInternal, UserId, BadgeId, Retry or 3):execute()
end

function module:GetBadgeInfo(BadgeId: number, Retry: number?)
    return self:GetBadgeInfoAsync(BadgeId, Retry):await():getResults()
end

function module:AwardBadge(UserId: number, BadgeId: number, Retry: number?)
    return self:AwardBadgeAsync(UserId, BadgeId, Retry):await():getResults()
end

function module:UserHasBadge(UserId: number, BadgeId: number, Retry: number?)
    return self:UserHasBadgeAsync(UserId, BadgeId, Retry):await():getResults()
end

--// Initialize
Players.PlayerAdded:Connect(UpdateRate)
Players.PlayerRemoving:Connect(UpdateRate)

return module