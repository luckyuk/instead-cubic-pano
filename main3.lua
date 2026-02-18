--$Name: Cubic_panos$
--$Name(ru): Кубические панорамы$
--$Version: 0.0.5$
--$Author: Lucky Ook$
--$Author(ru): Lucky Ook$

require "fmt"
require "dbg"
require "sprite"
require "timer"
require "click"
--todo
-- Добавить действия для колдовать, искать и нападать
-- добавить предметы -- пали, блины, прочее
--todo

game.act = 'Не работает.';
game.use = 'Это не поможет.';
game.inv = 'Зачем мне это?';

global 'node' ('other')
global 'scale_factor' (1)
global 'nodes_path' ('res')
global 'fov' (0)         -- Поле зрения в градусах
global 'yaw' (0)        -- Рысканье (горизонталь)
global 'pitch' (0)      -- Тангаж (вертикаль)
global 'roll' (0)        -- Крен (вертикаль)

declare {
	cubicPointer = pixels.new ("res/cursors/cursor_dot.png"),
	side = false,
	u = false,
	v = false,
	cam_canvas = pixels.new(400, 320, scale_factor),
	CANVAS_WIDTH = 400,
	CANVAS_HEIGHT = 320,
	setPoint = false,
	pointX = 0,
	pointY = 0,
	offsetX = 0,
	offsetY = 0,
	front = false,
	back = false,
	left = false,
	right = false,
	top = false,
	bottom = false,
}

local mpi = math.pi
local msin = math.sin
local mcos = math.cos
local mtan = math.tan
local matan2 = math.atan2
local mmax = math.max
local mmin = math.min
local macos = math.acos
local mfloor = math.floor
local mabs = math.abs
local mrad = math.rad

function click:filter(press, btn, x, y, px, py)
	setPoint = press
	pointX, pointY = px, py
--	dprint(press, btn, x, y, px, py)
	return press and px -- ловим только нажатия на картинку
end

-- Преобразование экранных координат в направляющий луч
function screenToRay(x, y)
    local nx = ((x / CANVAS_WIDTH) * 2 - 1) * mtan(fov * 0.5)
    local ny = ((y / CANVAS_HEIGHT) * 2 - 1) * mtan(fov * 0.5)

    local f = 1 / mtan(fov * 0.5)
    local z = -f
    local xDir = nx
    local yDir = ny
    -- Добавляем преобразование для крена, рыскания и тангажа
    local cosRoll = mcos(mrad(roll))
    local sinRoll = msin(mrad(roll))
    local cosYaw = mcos(mrad(yaw))
    local sinYaw = msin(mrad(yaw))
    local cosPitch = mcos(mrad(pitch))
    local sinPitch = msin(mrad(pitch))
    
    -- Сначала применяем крен (roll)
    local rx1 = xDir * cosRoll - yDir * sinRoll
    local ry1 = xDir * sinRoll + yDir * cosRoll
    local rz1 = z

 -- Затем применяем тангаж (pitch)
    local rx2 = rx1
    local ry2 = ry1 * cosPitch - rz1 * sinPitch
    local rz2 = ry1 * sinPitch + rz1 * cosPitch

    -- И наконец рыскание (yaw)
    local rx = rx2 * cosYaw - rz2 * sinYaw
    local ry = ry2
    local rz = rx2 * sinYaw + rz2 * cosYaw

    return { x = rx, y = ry, z = rz }
end

-- Пересечение луча с кубом
function intersectCube(ray)
    local absX = mabs(ray.x)
    local absY = mabs(ray.y)
    local absZ = mabs(ray.z)

    local maxAxis = 'x'
    local maxVal = absX
    if absY > maxVal then maxAxis = 'y'; maxVal = absY end
    if absZ > maxVal then maxAxis = 'z'; maxVal = absZ end

    local dir, u, v
    if maxAxis == 'x' then
--        dir = (ray.x > 0) and left or right
        dir = (ray.x > 0) and right or left
        u = -ray.z / absX
        v = ray.y / absX
    elseif maxAxis == 'y' then
        dir = (ray.y > 0) and bottom or top
        u = ray.x / absY
        v = ray.z / absY
    else  -- z
        dir = (ray.z > 0) and front or back
--        dir = (ray.z > 0) and back or front
        u = ray.x / absZ
        v = ray.y / absZ
    end

    local texture = dir
    if not texture then return nil end

    -- Преобразуем u,v в пиксельные координаты
    local texW, texH = texture:size()
    local px = mfloor((u + 1) * 0.5 * texW)
    local py = mfloor((v + 1) * 0.5 * texH)

    if px >= 0 and px < texW and py >= 0 and py < texH then
        return { texture = texture, px = px, py = py }
    end
    return nil
end

-- Основной рендер
function render()
	cam_canvas:clear(0,0,0)
    for y = 0, CANVAS_HEIGHT - 1 do
        for x = 0, CANVAS_WIDTH - 1 do
            local ray = screenToRay(x, y)
            local hit = intersectCube(ray)

            if hit then
                local tex = hit.texture
                local px, py = hit.px, hit.py
                cam_canvas:val(x, y, tex:val(px, py))
            else
                cam_canvas:val(x, y, 0, 0, 0)
            end
        end
    end
    if setPoint and pointX and pointY then
			cubicPointer:blend(cam_canvas, pointX-4 or 0, pointY-3 or 0)
    end
end

function game:timer()
	if setPoint and pointX and pointY then
		local panX,panY = instead.mouse_pos();
		panX = panX - offsetX
		panY = panY - offsetY
		if panX > 0 and panX < CANVAS_WIDTH*scale_factor and panY > 0 and panY < CANVAS_HEIGHT*scale_factor then
			yaw = (yaw - 0.5 * (pointX - panX)*0.05) % 720;
			pitch = pitch - 0.5 * (pointY - panY)*0.05;
			pitch = mmin(89,mmax(-89,pitch));
		else
			setPoint = false
			timer:stop()
		end
	else
		timer:stop()
	end
	std.nop()
end

function cubic_load(node_name)
	local node = node_name
		if not front then
			front = pixels.new (nodes_path..'/'..node..'/'.."negz.jpg")
		else
			local lfront = pixels.new (nodes_path..'/'..node..'/'.."negz.jpg")
			lfront:copy(front, 0, 0)
		end
		if not back then
			back = pixels.new (nodes_path..'/'..node..'/'.."posz.jpg")
		else
			local lback = pixels.new (nodes_path..'/'..node..'/'.."posz.jpg")
			lback:copy(back, 0, 0)
		end
		if not left then
			left = pixels.new (nodes_path..'/'..node..'/'.."negx.jpg")
		else
			local lleft = pixels.new (nodes_path..'/'..node..'/'.."negx.jpg")
			lleft:copy(left, 0, 0)
		end
		if not right then
			right = pixels.new (nodes_path..'/'..node..'/'.."posx.jpg")
		else
			local lright = pixels.new (nodes_path..'/'..node..'/'.."posx.jpg")
			lright:copy(right, 0, 0)
		end
		if not top then
			top = pixels.new (nodes_path..'/'..node..'/'.."posy.jpg")
		else
			local ltop = pixels.new (nodes_path..'/'..node..'/'.."posy.jpg")
			ltop:copy(top, 0, 0)
		end
		if not bottom then
			bottom = pixels.new (nodes_path..'/'..node..'/'.."negy.jpg")
		else
			local lbottom = pixels.new (nodes_path..'/'..node..'/'.."negy.jpg")
			lbottom:copy(bottom, 0, 0)
		end
end

function start(load)
	fov = mrad(60)
	cubic_load(node)
	print (nodes_path, node)
	place("zoom_in", me());
	place("zoom_out", me());
	place("roll_left", me());
	place("roll_right", me());
end

menu {
	nam = "zoom_in",
	disp = "Приблизить",
	dsc = "{Приблизить}",
	act = function()
		fov = fov - mrad(5);
	end,
};

menu {
	nam = "zoom_out",
	disp = "Отдалить",
	dsc = "{Отдалить}",
	act = function()
		fov = fov + mrad(5);
	end,
};

menu {
	nam = "roll_left",
	disp = "Крен влево",
	dsc = "{Крен влево}",
	act = function()
		roll = roll + mrad(30);
	end,
};

menu {
	nam = "roll_right",
	disp = "Крен вправо",
	dsc = "{Крен вправо}",
	act = function()
		roll = roll - mrad(30);
	end,
};

room {
	nam = 'main';
	disp = 'Лес';
	onenter = function()
		nodes_path = 'pics'
		node = '2'
		cubic_load(node)
	end;
	pic = function()
		render()
		return cam_canvas:sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
		timer:set(50)
	end;
	way = {'main', 'mount', 'castle'};
}

room {
	nam = 'mount';
	disp = "Гора";
	onenter = function()
		nodes_path = 'pics'
		node = '1'
		cubic_load(node)
	end;
	pic = function()
		render()
		return cam_canvas:sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
		timer:set(50)
	end;
	way = {'main', 'mount', 'castle'};
}

room {
	nam = 'castle';
	disp = "Замок";
	onenter = function()
		nodes_path = 'pics'
		node = '3'
		cubic_load(node)
	end;
	pic = function()
		render()
		return cam_canvas:sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
		timer:set(50)
	end;
	way = {'main', 'mount', 'castle'};
}
