--$Name: Cubic_panos$
--$Name(ru): Кубические панорамы$
--$Version: 0.0.8.3.1$
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
global 'pixls_viewport_scale' (1) -- масштабирование исходного массива пикселей вьюпорта
global 'sprite_output_scale' (2) -- масштабирование вьюпорта после рендера
global 'smooth' (5) -- сглаживание при масштабировании после рендера
global 'nodes_path' ('res')
global 'fov' (0)         -- Поле зрения в градусах
global 'yaw' (0)        -- Рысканье (горизонталь)
global 'pitch' (0)      -- Тангаж (вертикаль)
global 'roll' (0)        -- Крен (вертикаль)

declare {
	cubicPointer = false,
	side = false,
	u = false,
	v = false,
	cam_canvas = pixels.new(200, 160, pixls_viewport_scale),
	CANVAS_WIDTH = 200,
	CANVAS_HEIGHT = 160,
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
	patches = {
		--front = {
			--[1] = {texture = pixels.new('pics/4/kam/010_pvd.jpg'),
			--x = 614,
			--y = 444,
			--width = 176,
			--height = 336
			--depth = 0, -- глубина патча для порядка отрисовки
		--},
	},  -- таблица для хранения патчей
	hotspots = {},  -- таблица для хранения горячих точек
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
local cor_res = CANVAS_WIDTH/CANVAS_HEIGHT -- компенсация искажения

function click:filter(press, btn, x, y, px, py)
	setPoint = press
	pointX, pointY = px, py
--	dprint(press, btn, x, y, px, py)
	return press and px -- ловим только нажатия на картинку
end

-- Преобразование экранных координат в направляющий луч
function screenToRay(x, y)
    local nx = ((x / CANVAS_WIDTH) * 2 - 1) * mtan(fov * 0.5) * cor_res
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

    local nam, dir, u, v
    if maxAxis == 'x' then
        dir = (ray.x > 0) and right or left
        nam = (ray.x > 0) and "right" or "left"
        u = -ray.z / absX
        v = ray.y / absX
    elseif maxAxis == 'y' then
        dir = (ray.y > 0) and bottom or top
        nam = (ray.y > 0) and "bottom" or "top"
        u = ray.x / absY
        v = ray.z / absY
    else
        dir = (ray.z > 0) and front or back
        nam = (ray.z > 0) and "front" or "back"
        u = ray.x / absZ
        v = ray.y / absZ
    end

    local texture = dir
    local name = nam
    if not texture then return nil end

    -- Преобразуем u,v в пиксельные координаты
    local texW, texH = texture:size()
    local px = mfloor((u + 1) * 0.5 * texW)
    local py = mfloor((v + 1) * 0.5 * texH)

    if px >= 0 and px < texW and py >= 0 and py < texH then
        return {name = name, texture = texture, px = px, py = py }
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
                
                -- Отображаем патчи только на нужной стороне
                local use_patch = false
                for _, patch in ipairs(patches) do
                  if patch.side == hit.name and  -- проверяем сторону куба
                  px >= patch.pos_x and px < patch.pos_x + patch.width and
                  py >= patch.pos_y and py < patch.pos_y + patch.height then
										local r, g, b, a
										if patch.animation then
											local frame_width = patch.width -- ширина фрейма равна ширине патча
											local frame_x = (patch.frame - 1) * frame_width
											local tx = px - patch.pos_x + frame_x
											r, g, b, a = patch.texture:val(tx, py - patch.pos_y)
										--	if a > 254 then
										--		cam_canvas:val(x, y, patch.texture:val(tx, py - patch.pos_y))
										--	end
										else
											r, g, b, a = patch.texture:val(px - patch.pos_x, py - patch.pos_y)
										--	if a > 254 then
										--		cam_canvas:val(x, y, patch.texture:val(px - patch.pos_x, py - patch.pos_y))
										--	end
										end
										if  a > 254 then
											cam_canvas:val(x, y, r, g, b)
											use_patch = true
											break  -- прерываем цикл, если нашли подходящий патч
										end
                  end
                end
                 
                if not use_patch then
                  cam_canvas:val(x, y, tex:val(px, py))
                end
            else
                cam_canvas:val(x, y, 0, 0, 0)
            end
        end
    end
    for _, spot in ipairs(hotspots) do
        local side = spot.side
        local texture = _G[side]
        if texture then
            local tx = spot.x
            local ty = spot.y
            local tw = spot.width
            local th = spot.height
            -- рисуем рамку вокруг горячей точки
            texture:line(tx-1, ty-1, tx+tw+1, ty-1, 255, 0, 0)
            texture:line(tx-1, ty-1, tx-1, ty+th+1, 255, 0, 0)
            texture:line(tx+tw+1, ty-1, tx+tw+1, ty+th+1, 255, 0, 0)
            texture:line(tx-1, ty+th+1, tx+tw+1, ty+th+1, 255, 0, 0)
            texture:line(tx-2, ty-2, tx+tw+2, ty-2, 255, 0, 0)
            texture:line(tx-2, ty-2, tx-2, ty+th+2, 255, 0, 0)
            texture:line(tx+tw+2, ty-2, tx+tw+2, ty+th+2, 255, 0, 0)
            texture:line(tx-2, ty+th+2, tx+tw+2, ty+th+2, 255, 0, 0)
        end
    end
    if setPoint and pointX and pointY then
			cubicPointer:blend(cam_canvas, (pointX / pixls_viewport_scale / sprite_output_scale) - (4 / pixls_viewport_scale / sprite_output_scale) or 0, (pointY / pixls_viewport_scale / sprite_output_scale)-(3 /pixls_viewport_scale / sprite_output_scale) or 0)
    end -- добавить масштабирование
end

function game:timer()
	animation_patches()
	if setPoint and pointX and pointY then
		local panX,panY = instead.mouse_pos();
		panX = panX - offsetX
		panY = panY - offsetY
		if panX > 0 and panX < CANVAS_WIDTH*pixls_viewport_scale*sprite_output_scale and panY > 0 and -- добавить масштабирование
		 panY < CANVAS_HEIGHT*pixls_viewport_scale*sprite_output_scale then -- добавить масштабирование
			yaw = (yaw - 0.5 * (pointX - panX)*0.05) % 720;
			pitch = pitch - 0.5 * (pointY - panY)*0.05;
			pitch = mmin(89,mmax(-89,pitch));
		else
			setPoint = false
--			timer:stop()
		end
	else
--		timer:stop()
	end
	std.nop()
end

-- Функция сортировки патчей по глубине
function sortPatchesByDepth()
    table.sort(patches, function(a, b) 
        return a.depth < b.depth 
    end)
end

function add_patch(name, side, texture, pos_x, pos_y, width, height, depth,  active, run, animation )
    table.insert(patches, {
        name = name or 'none',       -- имя патча
        side = side,       -- сторона куба (например, 'front', 'back', etc.)
        texture = pixels.new (texture), -- путь к картинке патча
        pos_x = pos_x,
        pos_y = pos_y,
        width = width,
        height = height,
        depth = depth or 0,
        animation = animation or false, -- таблица с параметрами анимации
        active = active or true,        -- текущий кадр
        frame = 1,
        run = run or false -- флаг проигрывания анимации
    })
    -- Вызываем сортировку после добавления нового патча
    sortPatchesByDepth()
end

function add_hotspot(name, side, x, y, width, height, action)
    table.insert(hotspots, {
        name = name,
        side = side,
        x = x,
        y = y,
        width = width,
        height = height,
        action = action
    })
end

function hotspot_check (press,px, py)
	-- проверяем попадание в горячие точки
	if press and px and py then
		local hit = intersectCube(screenToRay(pointX / pixls_viewport_scale / sprite_output_scale, pointY / pixls_viewport_scale / sprite_output_scale))
		if hit then
			for _, spot in ipairs(hotspots) do
				if spot.side == hit.name then
					local tx = hit.px - spot.x
					local ty = hit.py - spot.y
					if tx >= 0 and tx < spot.width and ty >= 0 and ty < spot.height then
						--print (tx, ty)
						spot.action()
						break
					end
				end
			end
		end
	end
end

function load_resources()
	cubicPointer =  pixels.new ("res/cursors"..pixls_viewport_scale.."/cursor_dot.png")
end

--Параметры анимации
--frames - количество кадров
--frame_width - ширина фрейма
--loop - флаг цикличности анимации
--direction - направление (1 - вперед, -1 - назад)


function animation_patches()  -- Обновление анимации патчей
--	local current_time = timer:get_time()
	for i, patch in ipairs(patches) do
		if patch.animation then
--			local elapsed = current_time - patch.frame_time
			if patch.run then
				patch.frame = patch.frame + patch.animation.direction
				if patch.frame > patch.animation.frames then
					if patch.animation.loop then
						patch.frame = 1
					else
						patch.frame = patch.animation.frames
					end
				elseif patch.frame < 1 then
					if patch.animation.loop then
						patch.frame = patch.animation.frames
					else
						patch.frame = 1
					end
				end
--				patch.frame_time = current_time
			end
		end
	end
end

function load_patches()
	patches = {} -- очищаем таблицу патчей
	collectgarbage("collect") -- дёргаем сборщик мусора
	if here().node_patches then
		for _,patch in pairs(here().node_patches) do
			add_patch(patch.name, patch.side, patch.texture, patch.pos_x,
			patch.pos_y, patch.width, patch.height, patch.depth, patch.active, patch.run,
			patch.animation)
		end
	end
	-- Сортируем все патчи после загрузки
		sortPatchesByDepth()
end

function load_hotspots()
	hotspots = {} -- очищаем таблицу патчей
	collectgarbage("collect") -- дёргаем сборщик мусора
	if here().node_hotspots then
		for _,hotspot in pairs(here().node_hotspots) do
			add_hotspot(hotspot.name, hotspot.side, hotspot.x, hotspot.y,
			hotspot.width, hotspot.height, hotspot.action)
		end
	end
	-- Сортируем все патчи после загрузки
		--sortPatchesByDepth()
end

function cubic_clean()
	front = false
	back = false
	left = false
	right = false
	top = false
	bottom = false
end

function cubic_load(node_name)
	cubic_clean()
	collectgarbage("collect")
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
	fov = mrad(75)
	cubic_load(node)
	load_resources()
	load_patches()
	load_hotspots()
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
		timer:set(50)
	end;
	pic = function()
		render()
		--return cam_canvas:sprite()
		return cam_canvas:scale(sprite_output_scale, sprite_output_scale, smooth):sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
	end;
	way = {'main', 'mount', 'castle', 'laboratory', 'greed'};
}

room {
	nam = 'mount';
	disp = "Гора";
	onenter = function()
		nodes_path = 'pics'
		node = '1'
		cubic_load(node)
		timer:set(50)
	end;
	pic = function()
		render()
		--return cam_canvas:sprite()
		return cam_canvas:scale(sprite_output_scale, sprite_output_scale, smooth):sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
	end;
	way = {'main', 'mount', 'castle', 'laboratory', 'greed'};
}

room {
	nam = 'castle';
	disp = "Замок";
	onenter = function()
		nodes_path = 'pics'
		node = '3'
		cubic_load(node)
		timer:set(50)
	end;
	pic = function()
		render()
		--return cam_canvas:sprite()
		return cam_canvas:scale(sprite_output_scale, sprite_output_scale, smooth):sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
	end;
	way = {'main', 'mount', 'castle', 'laboratory', 'greed'};
}

room {
	nam = 'laboratory';
	disp = "Лаборатория";
	node_patches = {
			kamin_anim = {name = 'kamin_anim', side = 'front', texture = 'pics/4/kam/kamin.png',
			pos_x = 614, pos_y = 444, width = 176, height = 336, depth = 0, active = true, run = true, animation = {
				frames = 43,          -- кадров в анимации
				loop = true,         -- анимация цикличная
				direction = -1        -- направление проигрывания анимации
			}
		},
		torch3_anim = {name = 'torch3_anim', side = 'right', texture = 'pics/4/flame3/torch3.png',
		pos_x = 760, pos_y = 397, width = 48, height = 80, depth = 0, active = true, run = true, animation = {
			frames = 43,          -- кадров в анимации
			loop = true,         -- анимация цикличная
			direction = -1        -- направление проигрывания анимации
			}
		},
		{name = 'torch2_anim', side = 'right', texture = 'pics/4/flame2/torch2.png',
		pos_x = 334, pos_y = 391, width = 72, height = 88, depth = 0, active = true, run = true, animation = {
			frames = 43,          -- кадров в анимации
			loop = true,         -- анимация цикличная
			direction = -1        -- направление проигрывания анимации
			}
		},
		{name = 'torch1_anim', side = 'left', texture = 'pics/4/flame1/torch1.png',
		pos_x = 424, pos_y = 30, width = 248, height = 288, depth = 0, active = true, run = true, animation = {
			frames = 48,          -- кадров в анимации
			loop = true,         -- анимация цикличная
			direction = 1        -- направление проигрывания анимации
			}
		},
		{name = 'xtd_anim', side = 'right', texture = 'pics/4/xtd/xtd.png',
		pos_x = 384, pos_y = 548, width = 32, height = 32, depth = 0, active = true, run = true, animation = {
			frames = 60,          -- 8 кадров в анимации
			loop = true,         -- анимация цикличная
			direction = -1        -- направление проигрывания анимации
			}
		},
		{name = 'reduktor_anim', side = 'right', texture = 'pics/4/reduktor/reduktor.png',
		pos_x = 310, pos_y = 531, width = 16, height = 16, depth = 0, active = true, run = true, animation = {
			frames = 40,          -- 8 кадров в анимации
			loop = true,         -- анимация цикличная
			direction = -1        -- направление проигрывания анимации
			}
		},
		{name = 'patrubok_anim', side = 'right', texture = 'pics/4/patrubok/patrubok.png',
		pos_x = 332, pos_y = 549, width = 48, height = 32, depth = 0, active = true, run = true, animation = {
			frames = 40,          -- 8 кадров в анимации
			loop = true,         -- анимация цикличная
			direction = -1        -- направление проигрывания анимации
			}
		}
	};
	onenter = function()
		nodes_path = 'pics'
		node = '4/scene'
		cubic_load(node)
		timer:set(50)
	end;
	enter = function()
		load_patches()
	end;
	pic = function()
		render()
--		return cam_canvas:sprite()
		return cam_canvas:scale(sprite_output_scale, sprite_output_scale, smooth):sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
	end;
	onexit = function()
		patches = {}
		hotspots = {}
	end;
	way = {'main', 'mount', 'castle', 'laboratory', 'greed'};
}


room {
	nam = 'greed';
	disp = "Клетка";
	decor = function()
		return [[На полу я вижу {выдвигатель|выдвигатель}, {переставлятель|переставлятель} и {задвигатель|задвигатель}.]]
	end;
	dsc = "";
	node_patches = {
		torch1 = {name = 'torch1',side = 'front', texture = 'pics/5/torch4.png', pos_x = 801, pos_y = 397, width = 226, height = 394, depth = -1, action = true},
		door = {name = 'door',side = 'front', texture = 'pics/5/door.png', pos_x = 224, pos_y = 444, width = 356, height = 406, depth = 2, action = true},
		torch = {name = 'torch',side = 'right', texture = 'pics/5/torch3.png', pos_x = 761, pos_y = 397, width = 226, height = 394, depth = 0, action = true},
		torch2 ={name = 'torch2',side = 'front', texture = 'pics/5/torch4.png', pos_x = 761, pos_y = 397, width = 226, height = 394, depth = 7,  action = true},
	};
	{
		node_hotspots = {
			first_spot = {name = 'first_spot', side = 'front', x = 223, y = 443, width = 357, height = 401,
				action = function() _'ерундовина'.ecran = _'ерундовина'.ecran.."^ngfhgfhf" pn "Гибралтар" end},
			way_spot = {name = 'way_spot', side = 'right', x = 760, y = 396, width = 227, height = 395,
				action = function() walk 'laboratory'; setPoint = press; end},
		};
	}; -- нет смысла сохранять хотспоты в сейв; после walk гасим указатель принудительно.
	onenter = function()
		nodes_path = 'pics'
		node = '5'
		cubic_load(node)
		timer:set(50)
	end;
	enter = function()
		print (pixls_viewport_scale)
		load_patches()
		load_hotspots()
	end;
	pic = function()
		render()
		return cam_canvas:scale(sprite_output_scale, sprite_output_scale, smooth):sprite()
	end;
	onclick = function(s, press, btn, x, y, px, py)
		offsetX = x - px
		offsetY = y - py
--		timer:set(50)
	hotspot_check (press,px, py)
	end;
	onexit = function()
		patches = {}
		hotspots = {}
	end;
	way = {'main', 'mount', 'castle', 'laboratory', 'greed'};
}:with {
	obj {
		nam = 'задвигатель';
		act = function(s)
			pn [[Тяжелый!]];
			for _, patch in ipairs(patches) do
				if patch.name == 'door' then
					patch.pos_x = patch.pos_x + 10
					here().node_patches.door.pos_x = patch.pos_x
					pn (patch.pos_x)
				end
			end
		end;
	};
	obj {
		nam = 'переставлятель';
		act = function(s)
			pn [[Тяжелый!]];
			local a, b
			for _, patch in ipairs(patches) do
				if patch.name == 'torch1' then a = patch.depth end;
				if patch.name == 'torch2' then b = patch.depth end;
			end
			for _, patch in ipairs(patches) do
				if patch.name == 'torch1' then patch.depth = b end;
				if patch.name == 'torch2' then patch.depth = a end;
			end
			here().node_patches.torch1.depth = b
			here().node_patches.torch2.depth = a
			sortPatchesByDepth()
		end;
	};
		obj {
		nam = 'выдвигатель';
		act = function(s)
			pn [[Тяжелый!]];
			for _, patch in ipairs(patches) do
				if patch.name == 'door' then
					patch.pos_x = patch.pos_x - 10
					here().node_patches.door.pos_x = patch.pos_x
					pn (patch.pos_x)
				end
			end
		end;
	};
	obj {
		nam = 'ерундовина';
		ecran = [[]];
		display = function(s) return s.ecran..[[ggjhg]] end;
	};
};
