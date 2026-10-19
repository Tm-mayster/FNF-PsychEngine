package backend;

import backend.InputFormatter;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;

/**
 * Field of Hopes — gamepads, guitars and drums for the 4 note lanes.
 *
 * Every player has an input device (auto / keyboard only / gamepad 1-4) and their own
 * 4 lanes x 3 buttons. Keyboard keys always keep working, so any mix is possible:
 * keyboard + keyboard, keyboard + gamepad, gamepad + gamepad.
 *
 * A bound button is stored as an Int:
 *   0..999   — a named gamepad button (FlxGamepadInputID: DPAD_LEFT, A, LB...)
 *   1000+n   — raw button n, for controllers Flixel doesn't know (guitar frets, drum pads...)
 */
class FohPads
{
	public static inline var RAW:Int = 1000;
	public static inline var SLOTS:Int = 3;

	public static var DEVICES:Array<String> = ['auto', 'keyboard', 'pad1', 'pad2', 'pad3', 'pad4'];

	public static function defaultBinds():Array<Array<Int>>
	{
		return [
			[(FlxGamepadInputID.DPAD_LEFT:Int), (FlxGamepadInputID.X:Int)],
			[(FlxGamepadInputID.DPAD_DOWN:Int), (FlxGamepadInputID.A:Int)],
			[(FlxGamepadInputID.DPAD_UP:Int), (FlxGamepadInputID.Y:Int)],
			[(FlxGamepadInputID.DPAD_RIGHT:Int), (FlxGamepadInputID.B:Int)]
		];
	}

	public static function binds(player:Int):Array<Array<Int>>
	{
		var b:Array<Array<Int>> = player == 2 ? ClientPrefs.data.padBindsP2 : ClientPrefs.data.padBindsP1;
		if (b == null || b.length != 4)
		{
			b = defaultBinds();
			if (player == 2) ClientPrefs.data.padBindsP2 = b; else ClientPrefs.data.padBindsP1 = b;
		}
		return b;
	}

	public static function device(player:Int):String
	{
		var d = player == 2 ? ClientPrefs.data.padDevP2 : ClientPrefs.data.padDevP1;
		return DEVICES.contains(d) ? d : 'auto';
	}

	public static function activePads():Array<FlxGamepad>
	{
		var list:Array<FlxGamepad> = [];
		for (p in FlxG.gamepads.getActiveGamepads()) if (p != null && p.connected) list.push(p);
		list.sort(function(a, b) return a.id - b.id);
		return list;
	}

	/**
	 * Which pads this player reads.
	 * Auto: solo — every pad; co-op with one pad — it belongs to player 2 (player 1 keeps K L ; '),
	 * co-op with two or more — pad 1 is player 2's, pad 2 is player 1's.
	 */
	public static function padsFor(player:Int, coop:Bool):Array<FlxGamepad>
	{
		var pads = activePads();
		var d = device(player);
		if (d == 'keyboard') return [];
		if (d.startsWith('pad'))
		{
			var i = Std.parseInt(d.substr(3)) - 1;
			return i < pads.length ? [pads[i]] : [];
		}
		if (!coop) return pads;
		// auto in co-op: skip pads the other player picked by hand
		var other = device(player == 2 ? 1 : 2);
		if (other.startsWith('pad'))
		{
			var taken = Std.parseInt(other.substr(3)) - 1;
			var free = [for (i in 0...pads.length) if (i != taken) pads[i]];
			return free.length > 0 ? [free[0]] : [];
		}
		if (other == 'keyboard') return pads.length > 0 ? [pads[0]] : [];
		if (pads.length == 0) return [];
		if (player == 2) return [pads[0]];
		return pads.length > 1 ? [pads[1]] : [];
	}

	public static inline function check(pad:FlxGamepad, code:Int, status:FlxInputState):Bool
	{
		if (code < 0) return false;
		return code >= RAW ? pad.checkStatusRaw(code - RAW, status) : pad.checkStatus(code, status);
	}

	public static function lane(pads:Array<FlxGamepad>, player:Int, laneId:Int, status:FlxInputState):Bool
	{
		if (pads.length == 0) return false;
		var codes = binds(player)[laneId];
		if (codes == null) return false;
		for (pad in pads) for (c in codes) if (check(pad, c, status)) return true;
		return false;
	}

	public static function pauseButton(pads:Array<FlxGamepad>, status:FlxInputState):Bool
	{
		for (pad in pads) if (pad.checkStatus(FlxGamepadInputID.START, status)) return true;
		return false;
	}

	/** the button that was just pressed on this pad, encoded for the binds (named if possible, raw otherwise) */
	public static function justPressedCode(pad:FlxGamepad):Int
	{
		var id:Int = pad.firstJustPressedID();
		if (id >= 0) return id;
		var raw:Int = pad.firstJustPressedRawID();
		if (raw >= 0) return RAW + raw;
		return -1;
	}

	public static function codeName(code:Int):String
	{
		if (code < 0) return '---';
		if (code >= RAW) return Lang.t('Кнопка ') + (code - RAW);
		var n:String = InputFormatter.getGamepadName(code);
		if (n == null || n.length == 0) n = FlxGamepadInputID.toStringMap.get(code);
		return n != null ? n : '#' + code;
	}

	public static function deviceName(d:String):String
	{
		return switch (d)
		{
			case 'keyboard': Lang.t('Только клавиатура');
			case 'auto': Lang.t('Авто');
			default: Lang.t('Геймпад ') + d.substr(3);
		}
	}

	public static function padLabel(pad:FlxGamepad):String
	{
		var n:String = null;
		try n = pad.name catch (e:Dynamic) {}
		if (n == null || n.length == 0) n = Std.string(pad.detectedModel);
		return n;
	}
}
