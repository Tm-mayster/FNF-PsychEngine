package options;

import backend.FohPads;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import states.MainMenuState;

/**
 * Field of Hopes — gamepads, guitars and drums.
 * Pick a device for each player and bind 3 buttons per lane for each of them.
 * Works with the keyboard and with the gamepad itself (D-pad / A / B), even if
 * "gamepad in menus" is off.
 */
class FohPadSubState extends MusicBeatSubstate
{
	// kind: dev | menu | header | lane | reset
	var options:Array<Dynamic> = [];
	var rows:Array<FlxText> = [];
	var cols:Array<Array<FlxText>> = [];
	var cursor:FlxText;
	var info:FlxText;
	var probe:FlxText;
	var desc:FlxText;
	var curSelected:Int = 0;
	var slot:Int = 0;
	var binding:Bool = false;
	var bindTimer:Float = 0;
	var overlay:FlxSprite;
	var overlayText:FlxText;
	var scrollTop:Int = 0;
	var infoTimer:Float = 0;

	static inline var VISIBLE:Int = 13;
	static inline var TOP:Float = 112;
	static inline var ROW:Float = 30;
	static var COL_X:Array<Float> = [620, 830, 1040];

	public function new()
	{
		super();
		var font = MainMenuState.menuFont();
		var laneNames = [Lang.t('Влево'), Lang.t('Вниз'), Lang.t('Вверх'), Lang.t('Вправо')];

		options.push({kind: 'dev', player: 1, label: Lang.t('Игрок 1 (справа / одиночная игра)')});
		options.push({kind: 'dev', player: 2, label: Lang.t('Игрок 2 (слева, игра вдвоём)')});
		options.push({kind: 'menu', label: Lang.t('Геймпад в меню')});
		for (p in 1...3)
		{
			options.push({kind: 'header', label: p == 1 ? Lang.t('КНОПКИ — ИГРОК 1') : Lang.t('КНОПКИ — ИГРОК 2')});
			for (l in 0...4) options.push({kind: 'lane', player: p, lane: l, label: laneNames[l]});
		}
		options.push({kind: 'header', label: Lang.t('ПРОЧЕЕ')});
		options.push({kind: 'reset', label: Lang.t('Сбросить кнопки геймпада')});

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF07041A);
		bg.alpha = 0.94;
		add(bg);

		var title = new FlxText(40, 30, 0, Lang.t('ГЕЙМПАДЫ И КОНТРОЛЛЕРЫ'), 30);
		title.setFormat(font, 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		for (c in 0...3)
		{
			var h = new FlxText(COL_X[c], 86, 200, Lang.t('Кнопка ') + (c + 1), 12);
			h.setFormat(font, 12, 0xFFA99FD0, CENTER);
			add(h);
		}

		for (o in options)
		{
			var header = o.kind == 'header';
			var t = new FlxText(90, 0, 520, o.label, 14);
			t.setFormat(font, 14, header ? 0xFFFFCF5A : 0xFFCFC6F2, LEFT);
			rows.push(t); add(t);
			var line:Array<FlxText> = [];
			for (c in 0...3)
			{
				var v = new FlxText(COL_X[c], 0, 200, '', 14);
				v.setFormat(font, 14, FlxColor.WHITE, CENTER);
				line.push(v); add(v);
			}
			cols.push(line);
		}

		cursor = new FlxText(58, 0, 0, '>', 14);
		cursor.setFormat(font, 14, 0xFFFFCF5A, LEFT);
		add(cursor);

		info = new FlxText(40, FlxG.height - 200, FlxG.width - 80, '', 12);
		info.setFormat(font, 12, 0xFF7DF9FF, LEFT);
		add(info);

		probe = new FlxText(40, FlxG.height - 128, FlxG.width - 80, Lang.t('Проверка: нажмите кнопку на контроллере'), 12);
		probe.setFormat(font, 12, 0xFF7DF9B0, LEFT);
		add(probe);

		desc = new FlxText(40, FlxG.height - 100, FlxG.width - 80,
			Lang.t('Клавиатура работает всегда — геймпад добавляется к ней. Гитары и барабаны (Guitar Hero, Rock Band) работают, если Windows видит их как геймпад: назначьте лады или пэды на дорожки.\nВВЕРХ/ВНИЗ — выбор   ВЛЕВО/ВПРАВО — значение / кнопка 1-3   ENTER (A) — назначить   DELETE — очистить   ESC (B) — назад'), 12);
		desc.setFormat(font, 12, 0xFFCFC6F2, LEFT);
		add(desc);

		overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		overlay.alpha = 0.78;
		overlay.visible = false;
		add(overlay);
		overlayText = new FlxText(0, 290, FlxG.width, '', 20);
		overlayText.setFormat(font, 20, FlxColor.WHITE, CENTER);
		overlayText.visible = false;
		add(overlayText);

		updateInfo();
		refresh();
	}

	inline function isHeader(i:Int):Bool return options[i].kind == 'header';

	function laneCodes(o:Dynamic):Array<Int>
		return FohPads.binds(o.player)[o.lane];

	function refresh()
	{
		if (curSelected < scrollTop + 1) scrollTop = Std.int(Math.max(0, curSelected - 1));
		if (curSelected >= scrollTop + VISIBLE) scrollTop = curSelected - VISIBLE + 1;
		for (i in 0...options.length)
		{
			var o = options[i];
			var y = TOP + (i - scrollTop) * ROW;
			var vis = i >= scrollTop && i < scrollTop + VISIBLE;
			rows[i].y = y;
			rows[i].visible = vis;
			for (c in 0...3) { cols[i][c].y = y; cols[i][c].visible = vis; cols[i][c].text = ''; cols[i][c].color = FlxColor.WHITE; }
			if (o.kind == 'header') continue;
			var sel = i == curSelected;
			rows[i].color = sel ? 0xFFFFCF5A : 0xFFCFC6F2;
			switch ((o.kind:String))
			{
				case 'dev':
					var t = FohPads.deviceName(FohPads.device(o.player));
					cols[i][1].text = sel ? '< ' + t + ' >' : t;
					if (sel) cols[i][1].color = 0xFFFFCF5A;
				case 'menu':
					var t = ClientPrefs.data.gamepadEnabled ? Lang.t('Вкл') : Lang.t('Выкл');
					cols[i][1].text = sel ? '< ' + t + ' >' : t;
					if (sel) cols[i][1].color = 0xFFFFCF5A;
				case 'lane':
					var codes = laneCodes(o);
					for (c in 0...3)
					{
						var t = FohPads.codeName(c < codes.length ? codes[c] : -1);
						if (sel && slot == c) { t = '[ ' + t + ' ]'; cols[i][c].color = 0xFFFFCF5A; }
						cols[i][c].text = t;
					}
			}
		}
		cursor.y = rows[curSelected].y;
	}

	function updateInfo()
	{
		var pads = FohPads.activePads();
		if (pads.length == 0)
		{
			info.text = Lang.t('Контроллеры не найдены. Подключите геймпад — он появится здесь.');
			return;
		}
		var lines:Array<String> = [];
		var p1solo = FohPads.padsFor(1, false), p1 = FohPads.padsFor(1, true), p2 = FohPads.padsFor(2, true);
		for (i in 0...pads.length)
		{
			var who:Array<String> = [];
			if (p1solo.contains(pads[i])) who.push(Lang.t('один игрок'));
			if (p1.contains(pads[i])) who.push(Lang.t('вдвоём: игрок 1'));
			if (p2.contains(pads[i])) who.push(Lang.t('вдвоём: игрок 2'));
			lines.push(Lang.t('Геймпад ') + (i + 1) + ': ' + FohPads.padLabel(pads[i]) + '  →  ' + (who.length > 0 ? who.join(', ') : Lang.t('не используется')));
		}
		info.text = lines.join('\n');
	}

	function move(dir:Int)
	{
		var i = curSelected;
		do { i = FlxMath.wrap(i + dir, 0, options.length - 1); } while (isHeader(i));
		curSelected = i;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	function side(dir:Int)
	{
		var o = options[curSelected];
		switch ((o.kind:String))
		{
			case 'dev':
				var list = FohPads.DEVICES;
				var n = list[FlxMath.wrap(list.indexOf(FohPads.device(o.player)) + dir, 0, list.length - 1)];
				if (o.player == 2) ClientPrefs.data.padDevP2 = n; else ClientPrefs.data.padDevP1 = n;
				updateInfo();
			case 'menu':
				ClientPrefs.data.gamepadEnabled = !ClientPrefs.data.gamepadEnabled;
			case 'lane':
				slot = FlxMath.wrap(slot + dir, 0, FohPads.SLOTS - 1);
			default:
				return;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		refresh();
	}

	function setCode(o:Dynamic, code:Int)
	{
		var codes = laneCodes(o);
		var at = codes.indexOf(code);
		if (at > -1) codes.splice(at, 1);
		if (slot < codes.length) codes[slot] = code;
		else codes.push(code);
	}

	function clearCode(o:Dynamic)
	{
		var codes = laneCodes(o);
		if (slot < codes.length) codes.splice(slot, 1);
	}

	function padPressed(id:FlxGamepadInputID):Bool
	{
		if (ClientPrefs.data.gamepadEnabled) return false; // menus already read the pad through Controls
		for (p in FohPads.activePads()) if (p.checkStatus(id, JUST_PRESSED)) return true;
		return false;
	}

	function anyPadCode():Int
	{
		for (p in FohPads.activePads())
		{
			var c = FohPads.justPressedCode(p);
			if (c >= 0) return c;
		}
		return -1;
	}

	function finishBinding(sound:String)
	{
		binding = false;
		overlay.visible = overlayText.visible = false;
		ClientPrefs.saveSettings();
		FlxG.sound.play(Paths.sound(sound), 0.6);
		refresh();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		cursor.x = 58 + Math.sin(FlxG.game.ticks / 160) * 4;

		infoTimer += elapsed;
		if (infoTimer > 0.5) { infoTimer = 0; updateInfo(); }

		var pads = FohPads.activePads();
		for (i in 0...pads.length)
		{
			var c = FohPads.justPressedCode(pads[i]);
			if (c >= 0) probe.text = Lang.t('Проверка: геймпад ') + (i + 1) + Lang.t(' — нажата «') + FohPads.codeName(c) + '»';
		}

		if (binding)
		{
			bindTimer += elapsed;
			if (bindTimer < 0.2) return; // ignore the press that started binding
			var o = options[curSelected];
			if (FlxG.keys.justPressed.ESCAPE || bindTimer > 8) { finishBinding('cancelMenu'); return; }
			if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) { clearCode(o); finishBinding('confirmMenu'); return; }
			var code = anyPadCode();
			if (code >= 0) { setCode(o, code); finishBinding('confirmMenu'); }
			return;
		}

		var up = controls.UI_UP_P || padPressed(DPAD_UP);
		var down = controls.UI_DOWN_P || padPressed(DPAD_DOWN);
		var left = controls.UI_LEFT_P || padPressed(DPAD_LEFT);
		var right = controls.UI_RIGHT_P || padPressed(DPAD_RIGHT);
		var accept = controls.ACCEPT || padPressed(A);
		var back = FlxG.keys.justPressed.ESCAPE || FlxG.gamepads.anyJustPressed(B);

		if (up) move(-1);
		if (down) move(1);
		if (FlxG.mouse.wheel != 0) move(-FlxG.mouse.wheel);
		if (left) side(-1);
		if (right) side(1);

		var o = options[curSelected];
		if ((FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) && o.kind == 'lane')
		{
			clearCode(o);
			ClientPrefs.saveSettings();
			refresh();
		}
		if (accept)
		{
			switch ((o.kind:String))
			{
				case 'lane':
					binding = true;
					bindTimer = 0;
					overlay.visible = overlayText.visible = true;
					overlayText.text = Lang.t('Нажмите кнопку на контроллере для «') + o.label + Lang.t('», игрок ') + o.player
						+ Lang.t('\n(лад гитары, пэд барабана, любая кнопка)\n\nESC — отмена   DELETE — очистить');
					FlxG.sound.play(Paths.sound('scrollMenu'));
				case 'reset':
					ClientPrefs.data.padBindsP1 = FohPads.defaultBinds();
					ClientPrefs.data.padBindsP2 = FohPads.defaultBinds();
					ClientPrefs.data.padDevP1 = 'auto';
					ClientPrefs.data.padDevP2 = 'auto';
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound('cancelMenu'));
					updateInfo();
					refresh();
				case 'dev', 'menu':
					side(1);
			}
		}
		if (back)
		{
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
}
