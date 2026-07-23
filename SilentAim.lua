-- ============================================================
-- 子弹追踪 v27 — 新游戏 104841616983113
-- 方法论：顶层源头劫持（最高级最有效）
--   改底层 → 服务器检测不一致 → 拒绝
--   改最顶层源头 → 服务器看到的就是"正确"数据 → 通过
-- 射击链：ScreenPointToRay → bulletSpread(唯一调用!) → raycastVisible → FireServer
-- 劫持目标：Algorithms.bulletSpread（射击方向源头，只被调用1次）
-- 反检测：全部 task 异步，延迟初始化，随机延迟
-- ============================================================

-- ==================== 全部 task 异步 ====================
task.spawn(function()
	-- 随机延迟，反检测
	task.wait(math.random(30, 60) / 10)

	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local ENABLED = true
	local SCREEN_DOT = 0.2

	-- ==================== 屏幕中心优先 + 全图回退 ====================
	local function findTarget()
    if not ENABLED then return nil end
    local camCFrame = Camera.CFrame
    local camPos = camCFrame.Position
    local camForward = camCFrame.LookVector

    -- 屏幕中心优先
    local best, bestDot = nil, -1
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then   -- 删除了 Team 检查
            local head = p.Character:FindFirstChild("Head")
            if head then
                local dot = camForward:Dot((head.Position - camPos).Unit)
                if dot > SCREEN_DOT and dot > bestDot then
                    best, bestDot = head, dot
                end
            end
        end
    end
    if best then return best end

    -- 全图回退
    local mapBest, mapBestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then   -- 删除了 Team 检查
            local head = p.Character:FindFirstChild("Head")
            if head then
                local d = (head.Position - camPos).Magnitude
                if d < mapBestDist then
                    mapBest, mapBestDist = head, d
                end
            end
        end
    end
    return mapBest
end

	-- ==================== 劫持 Algorithms.bulletSpread（顶层源头） ====================
	-- 方法论步骤：
	-- 1. require(路径) 获取模块
	-- 2. 保存原函数引用
	-- 3. 替换原函数，在调用原函数之前修改关键数据
	-- 4. 原函数用修改后的数据执行，服务器验证通过
	--
	-- 为什么 bulletSpread 是真正的源头：
	--   Inventory源码第861行是 bulletSpread 唯一调用点
	--   ScreenPointToRay(860) → bulletSpread(861) → raycastVisible(862) → FireServer(882)
	--   bulletSpread 是射击链中第一个可访问函数，比 raycastVisible 更上游

	task.defer(function()
		local Algorithms = require(ReplicatedStorage.Modules.Algorithms)
		if not Algorithms then
			task.spawn(function() warn("v27: 无法找到 Algorithms 模块") end)
			return
		end

		local oldBulletSpread = Algorithms.bulletSpread
		if not oldBulletSpread then
			task.spawn(function() warn("v27: Algorithms.bulletSpread 不存在") end)
			return
		end

		Algorithms.bulletSpread = function(direction, spread)
			
			if ENABLED then
				local target = findTarget()
				if target then
					local camPos = Camera.CFrame.Position
					direction = (target.Position - camPos).Unit
				end
			end
			return oldBulletSpread(direction, spread)
		end

		task.spawn(function()
			print("v27 已加载 | 钩 Algorithms.bulletSpread（顶层源头）")
			print("  屏幕中心优先(Dot>" .. SCREEN_DOT .. ") + 全图回退")
			print("  全部 task 异步 + 随机延迟 + 反检测")
		end)
	end)

	-- ==================== 开关 ====================
	_G.ToggleBulletTrack = function(state)
		if state == nil then
			ENABLED = not ENABLED
		else
			ENABLED = state
		end
		task.spawn(function()
			print("子弹追踪:", ENABLED and "开启" or "关闭")
		end)
	end
end)