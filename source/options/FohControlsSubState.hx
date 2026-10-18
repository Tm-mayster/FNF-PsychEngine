package options;

import backend.InputFormatter;
import flixel.input.keyboard.FlxKey;
import states.MainMenuState;

/**
 * Field of Hopes — key binding screen (keyboard), in Russian.
 * Each action has two keys. LEFT/RIGHT picks the slot, ENTER rebinds,
 * ESC cancels a rebind, BACKSPACE clears the slot.
 */
class FohControlsSubState extends MusicBeatSubstate
{
	// [header] or [label, save key]
	var options:Array<Array<String>> = [
		['НОТЫ'],
		['Влево', 'note_left'], ['Вниз', 'note_down'], ['Вверх', 'note_up'], ['Вправо', 'note_right'],
		['МЕНЮ'],
		['Влево', 'ui_left'], ['Вниз', 'ui_down'], ['Вверх', 'ui_up'], ['Вправо', 'ui_right'],
		['Выбрать', 'accept'], ['Назад', 'back'], ['Пауза', 'pause'], ['Перезапуск', 'reset'],
		['ГРОМКОСТЬ'],
		['Без звука', 'volume_mute'], ['Громче', 'volume_up'], ['Тише', 'volume_down'],
		['ПРОЧЕЕ'],
		['Сбросить всё по умолчанию', '#reset']
	];

	var rows:Array<FlxText> = [];
	var keyA:Array<FlxText> = [];
	var keyB:Array<FlxText> = [];
	var cursor:FlxText;
	var hint:FlxText;
	var curSelected:Int = 1;
	var slot:Int = 0;
	var binding:Bool = false;
	var bindTimer:Float = 0;
	var overlay:FlxSprite;
	var overlayText:FlxText;
	var scrollTop:Int = 0;
	var lastKey:FlxText;
	static inline var VISIBLE:Int = 12;
	static inline var TOP:Float = 130;
	static inline var ROW:Float = 34;

	public function new()
	{
		super();
		var font = MainMenuState.menuFont();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF07041A);
		bg.alpha = 0.92;
		add(bg);

		var title = new FlxText(40, 36, 0, 'КЛАВИШИ', 32);
		title.setFormat(font, 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		var colA = new FlxText(700, 98, 220, 'Клавиша 1', 12);
		colA.setFormat(font, 12, 0xFFA99FD0, CENTER);
		add(colA);
		var colB = new FlxText(940, 98, 220, 'Клавиша 2', 12);
		colB.setFormat(font, 12, 0xFFA99FD0, CENTER);
		add(colB);

		for (o in options)
		{
			var header = o.length == 1;
			var t = new FlxText(90, 0, 600, o[0], 14);
			t.setFormat(font, 14, header ? 0xFFFFCF5A : 0xFFCFC6F2, LEFT);
			rows.push(t); add(t);
			var a = new FlxText(700, 0, 220, '', 14);
			a.setFormat(font, 14, FlxColor.WHITE, CENTER);
			keyA.push(a); add(a);
			var b = new FlxText(940, 0, 220, '', 14);
			b.setFormat(font, 14, FlxColor.WHITE, CENTER);
			keyB.push(b); add(b);
		}

		cursor = new FlxText(58, 0, 0, '>', 14);
		cursor.setFormat(font, 14, 0xFFFFCF5A, LEFT);
		add(cursor);

		hint = new FlxText(40, FlxG.height - 92, FlxG.width - 80,
			'ВВЕРХ/ВНИЗ — действие   ВЛЕВО/ВПРАВО — клавиша 1/2\nENTER — назначить   DELETE — очистить   ESC — назад', 12);
		hint.setFormat(font, 12, 0xFFCFC6F2, LEFT);
		add(hint);

		lastKey = new FlxText(40, FlxG.height - 130, FlxG.width - 80, 'Проверка: нажмите любую клавишу', 12);
		lastKey.setFormat(font, 12, 0xFF7DF9B0, LEFT);
		add(lastKey);

		overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		overlay.alpha = 0.75;
		overlay.visible = false;
		add(overlay);
		overlayText = new FlxText(0, 300, FlxG.width, '', 20);
		overlayText.setFormat(font, 20, FlxColor.WHITE, CENTER);
		overlayText.visible = false;
		add(overlayText);

		refresh();
	}

	inline function isHeader(i:Int) return options[i].length == 1;

	// always exactly two slots, NONE = empty (the engine's cleanup shrinks arrays, which shifted slots)
	function getKeys(id:String):Array<FlxKey>
	{
		var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(id);
		if (keys == null) { keys = [NONE, NONE]; ClientPrefs.keyBinds.set(id, keys); }
		while (keys.length < 2) keys.push(NONE);
		return keys;
	}

	function keyName(k:Null<FlxKey>):String
	{
		if (k == null || k == NONE) return '---';
		return InputFormatter.getKeyName(k);
	}

	function refresh()
	{
		if (curSelected < scrollTop + 1) scrollTop = Std.int(Math.max(0, curSelected - 1));
		if (curSelected >= scrollTop + VISIBLE) scrollTop = curSelected - VISIBLE + 1;
		for (i in 0...options.length)
		{
			var y = TOP + (i - scrollTop) * ROW;
			var vis = i >= scrollTop && i < scrollTop + VISIBLE;
			rows[i].y = keyA[i].y = keyB[i].y = y;
			rows[i].visible = keyA[i].visible = keyB[i].visible = vis;
			if (isHeader(i)) continue;
			var sel = i == curSelected;
			rows[i].color = sel ? 0xFFFFCF5A : 0xFFCFC6F2;
			var id = options[i][1];
			if (id == '#reset') { keyA[i].text = keyB[i].text = ''; continue; }
			var keys:Array<FlxKey> = getKeys(id);
			keyA[i].text = keyName(keys[0]);
			keyB[i].text = keyName(keys[1]);
			keyA[i].color = (sel && slot == 0) ? 0xFFFFCF5A : 0xFFFFFFFF;
			keyB[i].color = (sel && slot == 1) ? 0xFFFFCF5A : 0xFFFFFFFF;
			if (sel) { if (slot == 0) keyA[i].text = '[ ' + keyA[i].text + ' ]'; else keyB[i].text = '[ ' + keyB[i].text + ' ]'; }
		}
		cursor.y = rows[curSelected].y;
	}

	function move(dir:Int)
	{
		var i = curSelected;
		do { i = FlxMath.wrap(i + dir, 0, options.length - 1); } while (isHeader(i));
		curSelected = i;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		cursor.x = 58 + Math.sin(FlxG.game.ticks / 160) * 4;
		var probe:Int = FlxG.keys.firstJustPressed();
		if (probe > -1) lastKey.text = 'Проверка: игра видит клавишу «' + keyName(probe) + '» (код ' + probe + ')';

		if (binding)
		{
			bindTimer += elapsed;
			if (bindTimer < 0.15) return; // ignore the ENTER that started binding
			var pressed:Int = FlxG.keys.firstJustPressed();
			if (pressed > -1)
			{
				var id = options[curSelected][1];
				var keys:Array<FlxKey> = getKeys(id);
				if (pressed == FlxKey.ESCAPE) {}
				else if (pressed == FlxKey.DELETE) keys[slot] = NONE;
				else
				{
					keys[slot] = pressed;
					if (keys[1 - slot] == keys[slot]) keys[1 - slot] = NONE;
				}
				ClientPrefs.saveSettings();
				binding = false;
				overlay.visible = overlayText.visible = false;
				ClientPrefs.reloadVolumeKeys();
				FlxG.sound.play(Paths.sound(pressed == FlxKey.ESCAPE ? 'cancelMenu' : 'confirmMenu'), 0.6);
				refresh();
			}
			return;
		}

		if (controls.UI_UP_P) move(-1);
		if (controls.UI_DOWN_P) move(1);
		if (FlxG.mouse.wheel != 0) move(-FlxG.mouse.wheel);
		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			slot = 1 - slot;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			refresh();
		}
		if ((FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) && options[curSelected][1] != '#reset')
		{
			var keys:Array<FlxKey> = getKeys(options[curSelected][1]);
			keys[slot] = NONE;
			ClientPrefs.saveSettings();
			refresh();
		}
		if (controls.ACCEPT)
		{
			var id = options[curSelected][1];
			if (id == '#reset')
			{
				ClientPrefs.resetKeys(false);
				ClientPrefs.reloadVolumeKeys();
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				refresh();
			}
			else
			{
				binding = true;
				bindTimer = 0;
				ClientPrefs.toggleVolumeKeys(false);
				overlay.visible = overlayText.visible = true;
				overlayText.text = 'Нажмите клавишу для «' + options[curSelected][0] + '»\n\nESC — отмена   DELETE — очистить';
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			ClientPrefs.saveSettings();
			ClientPrefs.reloadVolumeKeys();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
}
