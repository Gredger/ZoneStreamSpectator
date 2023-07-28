function main()
	repeat wait(0) until isSampAvailable()
	sampRegisterChatCommand('sc', function(p)
		state = not state
		if state then 
			printStringNow('~b~[SPEC]~g~~h~~h~~h~ enabled', 3000)
			start_x, start_y, start_z = getCharCoordinates(PLAYER_PED)
		else
			printStringNow('~b~[SPEC]~r~ disabled', 3000) 
		end
		if not p:match('%d+') then 
			state = false
			return printStringNow('~b~[SPEC] ~w~type: ~r~/sc id', 3000) 
		end
		local _, ped = sampGetCharHandleBySampPlayerId(p)
		if not _ then 
			state = false
			return printStringNow('~b~[SPEC] ~r~undefined id', 3000) 
		else
			pointCameraAtChar(ped, 0, 2)
		end
		lua_thread.create(function()
			while state do wait(0)
				if isCharDead(PLAYER_PED) or isCharDead(ped) then
					state = false
					return printStringNow('~r~[ERROR] ~b~You or victim wasted', 3000) 
				end
				local _, ped = sampGetCharHandleBySampPlayerId(p)
				if not _ then
					state = false
					return printStringNow('~r~[ERROR]: ~b~Victim is out of zone stream', 3000)
				else
					local x2, y2, z2 = getCharCoordinates(ped)
					setCharCoordinates(PLAYER_PED, x2, y2, z2 - 10)
					boolean = true
				end		
				if state == false then
					boolean = false
					sampSetSpecialAction(0)
					restoreCameraJumpcut()
					setCharCoordinates(PLAYER_PED, start_x, start_y, start_z)
				end
			end
		end)
	end)
	wait(-1)
end

require("samp.events").onSendPlayerSync = function(data)
	if state and boolean then
		local bsdata = samp_create_sync_data("spectator", false)
		bsdata.position.x, bsdata.position.y, bsdata.position.z = data.position.x, data.position.y, data.position.z + 10
		bsdata.send()
		return false
	end
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'
    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
        trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData},
        unoccupied = {'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil},
        bullet = {'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil},
        spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil}
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({send = func_send}, mt)
end