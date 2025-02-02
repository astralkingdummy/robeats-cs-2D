local SPUtil = require(game.ReplicatedStorage.Shared.SPUtil)
local CurveUtil = require(game.ReplicatedStorage.Shared.CurveUtil)
local NoteBase = require(game.ReplicatedStorage.RobeatsGameCore.NoteTypes.NoteBase)
local NoteResult = require(game.ReplicatedStorage.RobeatsGameCore.Enums.NoteResult)
local SFXManager = require(game.ReplicatedStorage.RobeatsGameCore.SFXManager)
local EnvironmentSetup = require(game.ReplicatedStorage.RobeatsGameCore.EnvironmentSetup)
local HitParams = require(game.ReplicatedStorage.RobeatsGameCore.HitParams)
local HoldingNoteEffect2D = require(game.ReplicatedStorage.RobeatsGameCore.Effects.HoldingNoteEffect2D)
local TriggerNoteEffect2D = require(game.ReplicatedStorage.RobeatsGameCore.Effects.TriggerNoteEffect2D)
local RenderableHit = require(game.ReplicatedStorage.RobeatsGameCore.RenderableHit)


local SingleNote = {}
SingleNote.Type = "SingleNote"

SingleNote.State = {
	Pre = 0;
	DoRemove = 1;
}

local _outline_top_position_offset_default
local _outline_bottom_position_offset_default
local _body_adorn_default
local _outline_bottom_adorn_default
local _outline_top_adorn_default

function SingleNote:new(_game, _track_index, _slot_index, _creation_time_ms, _hit_time_ms)
	local self = NoteBase:NoteBase()
	self.ClassName = SingleNote.Type
	
	local _state = SingleNote.State.Pre
	
	--Parametric T: Goes from 0 to 1
	local _t = 0
	
	local _note_obj
	local _body, _outline_top, _outline_bottom
	local _position = Vector3.new()
	local _body_adorn, _outline_top_adorn, _outline_bottom_adorn
	local _show_trigger_fx = _game:get_hit_lighting()
	
	function self:cons()
		local gameplayframe = EnvironmentSetup:get_player_gui_root().GameplayFrame
		local tracks = gameplayframe.Tracks
		local proto = EnvironmentSetup:get_2d_skin().NoteProto

		_note_obj = _game._object_pool:depool(self.ClassName)
		if _object_pool == nil then
			_note_obj = proto:Clone()
			_note_obj.Position = UDim2.new(0.5,0,-1,0);
			_note_obj.ZIndex = 2
		end

		_body = _note_obj
		_t = 0
		self:update_visual(1)

		_note_obj.Parent = tracks["Track".._track_index]
	end
	
	function self:update_visual(dt_scale)
		_body.Position = UDim2.new(.5, 0, dt_scale, 0)
	end
	
	--[[Override--]] function self:update(dt_scale)
		if _state == SingleNote.State.Pre then
			_t = (_game._audio_manager:get_current_time_ms() - _creation_time_ms) / (_hit_time_ms - _creation_time_ms)
			
			self:update_visual(_t)
			
			if self:should_remove(_game) then
				_game._score_manager:register_hit(
					NoteResult.Miss,
					_slot_index,
					_track_index,
					HitParams:new():set_play_sfx(false):set_play_hold_effect(false):set_time_miss(true)
				)
			end
		end
	end

	--[[Override--]] function self:should_remove()
		--Remove if state is DoRemove (set on hit), or if NOTE_REMOVE_TIME past the hit time
		return _state == SingleNote.State.DoRemove or self:get_time_to_end() < _game._audio_manager:get_note_remove_time()
	end
	
	function self:get_time_to_end()
		return (_hit_time_ms - _creation_time_ms) * (1 - _t)
	end

	--[[Override--]] function self:do_remove()
		_game._object_pool:repool(self.ClassName,_note_obj)
	end

	--[[Override--]] function self:test_hit()
		local time_to_end = self:get_time_to_end()
		local did_hit, note_result = NoteResult:timedelta_to_result(time_to_end, _game)

		if did_hit then
			return did_hit, note_result, RenderableHit:new(_hit_time_ms, time_to_end, note_result)
		end

		return false, NoteResult.Miss
	end

	--[[Override--]] function self:on_hit(note_result, i_notes, renderable_hit)

		if _show_trigger_fx then
			_game._effects:add_effect(TriggerNoteEffect2D:new(
				_game,
				note_result
			))
		end

		_game._score_manager:register_hit(
			note_result,
			_slot_index,
			_track_index,
			HitParams:new():set_play_hold_effect(true, _position),
			renderable_hit
		)

		_state = SingleNote.State.DoRemove
	end

	--[[Override--]] function self:test_release()
		return false, NoteResult.Miss
	end
	
	--[[Override--]] function self:on_release(note_result,i_notes)
	end
	
	--[[Override--]] function self:get_track_index()
		return _track_index
	end

	self:cons()
	return self
end

return SingleNote
