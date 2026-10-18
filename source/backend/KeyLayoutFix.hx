package backend;

import openfl.Lib;
import openfl.events.KeyboardEvent;

/**
 * Makes keys work by their PLACE on the keyboard, not by the active layout.
 *
 * With a Russian (ЙЦУКЕН) layout, the physical keys , . ; ' [ ] ` and all the
 * letters report Cyrillic codes that Flixel does not know, so they can't be
 * bound or used in gameplay. Here every such code is translated back to the
 * code of the same physical key on a QWERTY keyboard, before Flixel sees it.
 */
class KeyLayoutFix
{
	// Cyrillic letter (lowercase codepoint) -> QWERTY key code on the same physical key
	static var map:Map<Int, Int> = [
		0x0439 => 81,  // й -> Q
		0x0446 => 87,  // ц -> W
		0x0443 => 69,  // у -> E
		0x043A => 82,  // к -> R
		0x0435 => 84,  // е -> T
		0x043D => 89,  // н -> Y
		0x0433 => 85,  // г -> U
		0x0448 => 73,  // ш -> I
		0x0449 => 79,  // щ -> O
		0x0437 => 80,  // з -> P
		0x0445 => 219, // х -> [
		0x044A => 221, // ъ -> ]
		0x0444 => 65,  // ф -> A
		0x044B => 83,  // ы -> S
		0x0432 => 68,  // в -> D
		0x0430 => 70,  // а -> F
		0x043F => 71,  // п -> G
		0x0440 => 72,  // р -> H
		0x043E => 74,  // о -> J
		0x043B => 75,  // л -> K
		0x0434 => 76,  // д -> L
		0x0436 => 186, // ж -> ;
		0x044D => 222, // э -> '
		0x044F => 90,  // я -> Z
		0x0447 => 88,  // ч -> X
		0x0441 => 67,  // с -> C
		0x043C => 86,  // м -> V
		0x0438 => 66,  // и -> B
		0x0442 => 78,  // т -> N
		0x044C => 77,  // ь -> M
		0x0431 => 188, // б -> ,
		0x044E => 190, // ю -> .
		0x0451 => 192  // ё -> `
	];

	public static function init()
	{
		var stage = Lib.current.stage;
		// capture phase + high priority: runs before Flixel's own listeners
		stage.addEventListener(KeyboardEvent.KEY_DOWN, fix, true, 10000);
		stage.addEventListener(KeyboardEvent.KEY_UP, fix, true, 10000);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, fix, false, 10000);
		stage.addEventListener(KeyboardEvent.KEY_UP, fix, false, 10000);
	}

	// USB HID scancode -> QWERTY key code (Flixel/OpenFL numbering)
	static function fromScanCode(sc:Int):Int
	{
		if (sc >= 4 && sc <= 29) return 65 + (sc - 4);          // A..Z
		if (sc >= 30 && sc <= 38) return 49 + (sc - 30);        // 1..9
		return switch (sc)
		{
			case 39: 48;   // 0
			case 45: 189;  // -
			case 46: 187;  // =
			case 47: 219;  // [
			case 48: 221;  // ]
			case 49: 220;  // \
			case 51: 186;  // ;
			case 52: 222;  // '
			case 53: 192;  // `
			case 54: 188;  // ,
			case 55: 190;  // .
			case 56: 191;  // /
			default: -1;
		}
	}

	static function fix(e:KeyboardEvent)
	{
		var code:Int = e.keyCode;
		// any code Flixel doesn't know (non-Latin layouts): ask SDL which physical key it was
		if (code > 255 && code < 0x40000000)
		{
			var mapped:Int = -1;
			#if (lime_cffi && !macro)
			try { mapped = fromScanCode(lime.ui.ScanCode.fromKeyCode(code)); } catch (_:Dynamic) {}
			#end
			if (mapped > 0) { e.keyCode = mapped; return; }
		}
		if (code < 0x0400 || code > 0x04FF) return;
		// uppercase Cyrillic (А-Я, Ё) -> lowercase
		if (code >= 0x0410 && code <= 0x042F) code += 0x20;
		else if (code == 0x0401) code = 0x0451;
		if (map.exists(code)) e.keyCode = map.get(code);
	}
}
