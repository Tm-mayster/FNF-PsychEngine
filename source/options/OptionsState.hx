package options;

import states.MainMenuState;
import backend.StageData;

/**
 * Field of Hopes — settings screen.
 * One scrollable list grouped by category, in Russian, styled like the main menu.
 * LEFT/RIGHT change a value, ENTER toggles or opens, ESC goes back.
 */
typedef FohSetting = {
	var kind:String;      // 'header' | 'bool' | 'num' | 'list' | 'open' | 'scroll' | 'scrolltype'
	var label:String;
	@:optional var desc:String;
	@:optional var field:String;      // ClientPrefs.data field
	@:optional var min:Float;
	@:optional var max:Float;
	@:optional var step:Float;
	@:optional var decimals:Int;
	@:optional var suffix:String;
	@:optional var values:Array<String>;
	@:optional var names:Array<String>;
	@:optional var target:String;     // for 'open'
	@:optional var after:Void->Void;
}

class OptionsState extends MusicBeatState
{
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	static var curSelected:Int = 0;

	var items:Array<FohSetting> = [];
	var rows:Array<FlxText> = [];
	var vals:Array<FlxText> = [];
	var listGroup:FlxSpriteGroup;
	var descText:FlxText;
	var cursor:FlxText;
	var holdTime:Float = 0;
	var listTop:Float = 140;
	var rowH:Float = 40;
	var visibleRows:Int = 11;
	var scrollTop:Int = 0;

	function font():String
		return MainMenuState.menuFont();

	function build()
	{
		items = [
			{kind: 'lang', label: 'Язык / Language', desc: Lang.t('Язык игры. Новые языки добавляются файлом lang/<код>.txt в папке мода — без программирования.')},
			{kind: 'header', label: Lang.t('ИГРА')},
			{kind: 'scrolltype', label: Lang.t('Режим скролла'), desc: Lang.t('osu!mania: скорость 1–40, как в osu! (время ноты на экране = 11485 / скорость мс).\nC-mod (Etterna): постоянная скорость C100–C2000.\nМножитель x: старый режим FNF, умножает скорость песни.')},
			{kind: 'scroll', label: Lang.t('Скорость скролла'), desc: Lang.t('ВЛЕВО/ВПРАВО — изменить. В osu!mania шаг 1, в C-mod шаг 10, в множителе 0.05. Скорость одинакова во всех песнях (кроме режима x).')},
			{kind: 'bool', label: Lang.t('Ноты сверху вниз'), field: 'downScroll', desc: Lang.t('Стрелки внизу экрана, ноты падают сверху.')},
			{kind: 'bool', label: Lang.t('Стрелки по центру'), field: 'middleScroll', desc: Lang.t('Ваши стрелки посередине экрана.')},
			{kind: 'bool', label: Lang.t('Стрелки противника'), field: 'opponentStrums', desc: Lang.t('Показывать ноты противника.')},
			{kind: 'bool', label: Lang.t('Свободные нажатия'), field: 'ghostTapping', desc: Lang.t('Нажатие без ноты не считается промахом.')},
			{kind: 'bool', label: Lang.t('Отключить сброс (R)'), field: 'noReset', desc: Lang.t('Клавиша сброса не перезапускает песню.')},
			{kind: 'num', label: Lang.t('Громкость щелчка'), field: 'hitsoundVolume', min: 0, max: 1, step: 0.1, decimals: 1, desc: Lang.t('Звук при попадании по ноте. 0 — выключен.'),
				after: function() { FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume); }},
			{kind: 'list', label: Lang.t('Строгость попаданий'), field: 'hitPreset', values: ['fnf', 'soft', 'strict'], names: [Lang.t('Как в FNF'), Lang.t('Мягкая'), Lang.t('Строгая')],
				desc: Lang.t('Как в FNF — обычные окна Friday Night Funkin\' и Psych-модов (Sick ±45 мс, Good ±90, Bad ±135).\nМягкая — для новичков. Строгая — для тех, кто играет в osu!mania / Etterna.'),
				after: function() { ClientPrefs.applyOD(); }},

			{kind: 'header', label: Lang.t('ЗВУК И ЗАДЕРЖКА')},
			{kind: 'open', label: Lang.t('Калибровка задержки'), target: 'offset', desc: Lang.t('Играет песня — нажимайте в такт, и игра сама подберёт задержку.')},
			{kind: 'num', label: Lang.t('Задержка нот'), field: 'noteOffset', min: -500, max: 500, step: 1, decimals: 0, suffix: Lang.t(' мс'), desc: Lang.t('Сдвиг всех нот. Плюс — ноты позже, минус — раньше.')},
			{kind: 'bool', label: Lang.t('Пауза при сворачивании'), field: 'autoPause', desc: Lang.t('Игра останавливается, когда окно не активно.'),
				after: function() { FlxG.autoPause = ClientPrefs.data.autoPause; }},

			{kind: 'header', label: Lang.t('УПРАВЛЕНИЕ')},
			{kind: 'open', label: Lang.t('Клавиши'), target: 'controls', desc: Lang.t('Назначить клавиши. Работают и при русской раскладке: , . ; [ ] и буквы — по месту на клавиатуре.')},
			{kind: 'bool', label: Lang.t('Геймпад'), field: 'gamepadEnabled', desc: Lang.t('Принимать ввод с геймпада. Выключено по умолчанию: подключённый или виртуальный контроллер (Steam, драйверы) может сам «нажимать» кнопки и отключать клавиатуру в игре.')},
			{kind: 'list', label: Lang.t('Вид нот'), field: 'noteSkin', values: ['Default', 'Circles', 'Diamonds', 'Bars'],
				names: [Lang.t('Стрелки'), Lang.t('Круги'), Lang.t('Ромбы'), Lang.t('Полосы')], desc: Lang.t('Форма нот: классические стрелки FNF, круги, ромбы или полосы как в osu!mania / Etterna. Цвета настраиваются ниже.')},
			{kind: 'open', label: Lang.t('Цвета нот'), target: 'colors', desc: Lang.t('Настроить цвета стрелок (экран редактора на английском).')},

			{kind: 'header', label: Lang.t('ЭКРАН')},
			{kind: 'bool', label: Lang.t('Счётчик FPS'), field: 'showFPS', desc: Lang.t('Показывать частоту кадров в углу.'),
				after: function() { if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.data.showFPS; }},
			{kind: 'fps', label: Lang.t('Частота кадров'), field: 'framerate', desc: Lang.t('Ограничение FPS. 240–360 — минимальная задержка без нагрузки. «Без ограничений» грузит процессор и может вызывать заикание звука.')},
			{kind: 'bool', label: Lang.t('Вспышки'), field: 'flashing', desc: Lang.t('Мигающие эффекты. Выключите, если они мешают.')},
			{kind: 'bool', label: Lang.t('Приближение камеры'), field: 'camZooms', desc: Lang.t('Камера пульсирует в такт.')},
			{kind: 'bool', label: Lang.t('Скрыть интерфейс'), field: 'hideHud', desc: Lang.t('Убрать полоску здоровья, счёт и прочее.')},
			{kind: 'list', label: Lang.t('Таймер песни'), field: 'timeBarType', values: ['Time Left', 'Time Elapsed', 'Song Name', 'Disabled'],
				names: [Lang.t('Осталось'), Lang.t('Прошло'), Lang.t('Название'), Lang.t('Выключен')], desc: Lang.t('Что показывать на полоске времени.')},
			{kind: 'num', label: Lang.t('Прозрачность здоровья'), field: 'healthBarAlpha', min: 0, max: 1, step: 0.1, decimals: 1, desc: Lang.t('Видимость полоски здоровья.')},
			{kind: 'num', label: Lang.t('Брызги нот'), field: 'splashAlpha', min: 0, max: 1, step: 0.1, decimals: 1, desc: Lang.t('Яркость эффекта при точном попадании. 0 — выключены.')},
			{kind: 'bool', label: Lang.t('Счёт пульсирует'), field: 'scoreZoom', desc: Lang.t('Текст счёта увеличивается при попадании.')},
			{kind: 'bool', label: Lang.t('Комбо стопкой'), field: 'comboStacking', desc: Lang.t('Оценки складываются друг на друга.')},
			{kind: 'bool', label: Lang.t('Низкое качество'), field: 'lowQuality', desc: Lang.t('Меньше деталей фона, быстрее на слабых ПК.')},
			{kind: 'bool', label: Lang.t('Шейдеры'), field: 'shaders', desc: Lang.t('Визуальные эффекты. Выключите на слабых ПК.')},
			{kind: 'bool', label: Lang.t('Сглаживание'), field: 'antialiasing', desc: Lang.t('Сглаживание обычной графики (пиксель-арт мода не размывается).')},
		];
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		build();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = false;
		bg.setGraphicSize(FlxG.width + 8);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		menuBG = bg;

		var shade = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF07041A);
		shade.alpha = 0.45;
		add(shade);

		var listBG = new FlxSprite(40, 120).makeGraphic(760, 470, 0xFF0B0614);
		listBG.alpha = 0.78;
		add(listBG);
		var descBG = new FlxSprite(820, 120).makeGraphic(420, 470, 0xFF0B0614);
		descBG.alpha = 0.78;
		add(descBG);

		var title = new FlxText(40, 36, 0, Lang.t('НАСТРОЙКИ'), 32);
		title.setFormat(font(), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		listGroup = new FlxSpriteGroup();
		add(listGroup);
		for (i in 0...items.length)
		{
			var it = items[i];
			var t = new FlxText(90, 0, 420, it.label, it.kind == 'header' ? 14 : 14);
			t.setFormat(font(), 14, it.kind == 'header' ? 0xFFFFCF5A : 0xFFCFC6F2, LEFT);
			rows.push(t);
			listGroup.add(t);
			var v = new FlxText(440, 0, 340, '', 14);
			v.setFormat(font(), 14, 0xFFFFFFFF, RIGHT);
			vals.push(v);
			listGroup.add(v);
		}

		cursor = new FlxText(58, 0, 0, '>', 14);
		cursor.setFormat(font(), 14, 0xFFFFCF5A, LEFT);
		add(cursor);

		descText = new FlxText(840, 140, 380, '', 14);
		descText.setFormat(font(), 14, FlxColor.WHITE, LEFT);
		MainMenuState.leading(descText, 7);
		descText.wordWrap = true;
		add(descText);

		var hint = new FlxText(40, FlxG.height - 92, FlxG.width - 80,
			Lang.t('ВВЕРХ/ВНИЗ — выбор   ВЛЕВО/ВПРАВО — изменить\nENTER — переключить/открыть   ESC — назад'), 12);
		hint.setFormat(font(), 12, 0xFFCFC6F2, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		add(hint);

		if (curSelected >= items.length || items[curSelected].kind == 'header') curSelected = 0;
		refresh();
		ClientPrefs.saveSettings();
		super.create();
	}

	function valueText(it:FohSetting):String
	{
		switch (it.kind)
		{
			case 'bool':
				return Reflect.getProperty(ClientPrefs.data, it.field) == true ? Lang.t('ВКЛ') : Lang.t('ВЫКЛ');
			case 'num':
				var v:Float = Reflect.getProperty(ClientPrefs.data, it.field);
				var p = Math.pow(10, it.decimals);
				var s = Std.string(Math.round(v * p) / p);
				return '< ' + s + (it.suffix != null ? it.suffix : '') + ' >';
			case 'list':
				var cur:String = Reflect.getProperty(ClientPrefs.data, it.field);
				var idx = it.values.indexOf(cur);
				return '< ' + (idx >= 0 ? it.names[idx] : cur) + ' >';
			case 'lang':
				return '< ' + Lang.nameOf(Lang.current) + ' >';
			case 'scroll':
				return '< ' + ScrollUtil.valueText() + ' >';
			case 'scrolltype':
				return '< ' + ScrollUtil.typeName() + ' >';
			case 'open':
				return Lang.t('ОТКРЫТЬ');
			case 'fps':
				var f:Int = ClientPrefs.data.framerate;
				return '< ' + (f >= 1000 ? Lang.t('БЕЗ ОГРАНИЧ.') : Std.string(f)) + ' >';
		}
		return '';
	}

	function refresh()
	{
		// keep the selected row inside the visible window
		if (curSelected < scrollTop + 1) scrollTop = Std.int(Math.max(0, curSelected - 1));
		if (curSelected >= scrollTop + visibleRows) scrollTop = curSelected - visibleRows + 1;
		for (i in 0...items.length)
		{
			var y = listTop + (i - scrollTop) * rowH;
			var vis = i >= scrollTop && i < scrollTop + visibleRows;
			rows[i].y = y; vals[i].y = y;
			rows[i].visible = vals[i].visible = vis;
			vals[i].text = valueText(items[i]);
			if (items[i].kind != 'header')
			{
				rows[i].color = (i == curSelected) ? 0xFFFFCF5A : 0xFFCFC6F2;
				vals[i].color = (i == curSelected) ? 0xFFFFFFFF : 0xFFA99FD0;
			}
		}
		cursor.y = rows[curSelected].y;
		var it = items[curSelected];
		descText.text = it.label.toUpperCase() + '\n\n' + (it.desc != null ? it.desc : '')
			+ (it.field == 'hitPreset' ? Lang.t('\n\nСейчас: ') + ClientPrefs.odWindowsText() : '');
	}

	function move(dir:Int)
	{
		var i = curSelected;
		do { i = FlxMath.wrap(i + dir, 0, items.length - 1); } while (items[i].kind == 'header');
		curSelected = i;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	function change(dir:Int)
	{
		var it = items[curSelected];
		switch (it.kind)
		{
			case 'num':
				var v:Float = Reflect.getProperty(ClientPrefs.data, it.field);
				v = FlxMath.bound(v + dir * it.step, it.min, it.max);
				var p = Math.pow(10, it.decimals);
				v = Math.round(v * p) / p;
				if (it.field == 'noteOffset' || it.field == 'framerate') Reflect.setProperty(ClientPrefs.data, it.field, Std.int(v));
				else Reflect.setProperty(ClientPrefs.data, it.field, v);
			case 'list':
				var cur:String = Reflect.getProperty(ClientPrefs.data, it.field);
				var idx = FlxMath.wrap(it.values.indexOf(cur) + dir, 0, it.values.length - 1);
				Reflect.setProperty(ClientPrefs.data, it.field, it.values[idx]);
			case 'bool':
				Reflect.setProperty(ClientPrefs.data, it.field, !(Reflect.getProperty(ClientPrefs.data, it.field) == true));
			case 'lang':
				var langs = Lang.list();
				var idx = 0;
				for (i in 0...langs.length) if (langs[i][0] == Lang.current) idx = i;
				idx = FlxMath.wrap(idx + dir, 0, langs.length - 1);
				ClientPrefs.data.fohLang = langs[idx][0];
				Lang.load(ClientPrefs.data.fohLang);
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
				// rebuild the screen in the new language
				MusicBeatState.switchState(new OptionsState());
				return;
			case 'scroll':
				ScrollUtil.change(dir);
			case 'fps':
				var steps = [60, 75, 120, 144, 165, 240, 360, 500, 1000];
				var cur:Int = ClientPrefs.data.framerate;
				var i = 0;
				while (i < steps.length - 1 && steps[i] < cur) i++;
				if (steps[i] == cur) i += dir;
				else if (dir < 0) i -= 1;
				i = Std.int(FlxMath.bound(i, 0, steps.length - 1));
				ClientPrefs.data.framerate = steps[i];
				applyFramerate();
			case 'scrolltype':
				ScrollUtil.cycleType(dir);
			default:
				return;
		}
		if (it.after != null) it.after();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	public static function applyFramerate()
	{
		var f:Int = ClientPrefs.data.framerate;
		if (f > FlxG.drawFramerate) { FlxG.updateFramerate = f; FlxG.drawFramerate = f; }
		else { FlxG.drawFramerate = f; FlxG.updateFramerate = f; }
	}

	function accept()
	{
		var it = items[curSelected];
		switch (it.kind)
		{
			case 'bool', 'scrolltype':
				change(1);
			case 'open':
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
				switch (it.target)
				{
					case 'controls': openSubState(new options.FohControlsSubState());
					case 'colors': openSubState(new options.NotesColorSubState());
					case 'offset':
						ClientPrefs.saveSettings();
						states.FohCalibrationState.returnToOptions = true;
						MusicBeatState.switchState(new states.FohCalibrationState());
				}
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		refresh();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (subState != null) return;

		if (controls.UI_UP_P) move(-1);
		if (controls.UI_DOWN_P) move(1);
		if (FlxG.mouse.wheel != 0) move(-FlxG.mouse.wheel);

		var it = items[curSelected];
		var holdable = it.kind == 'num' || it.kind == 'scroll';
		if (controls.UI_LEFT_P) { change(-1); holdTime = 0; }
		if (controls.UI_RIGHT_P) { change(1); holdTime = 0; }
		if (holdable && (controls.UI_LEFT || controls.UI_RIGHT))
		{
			var before = Math.floor((holdTime - 0.4) * 14);
			holdTime += elapsed;
			var after = Math.floor((holdTime - 0.4) * 14);
			if (holdTime > 0.4 && after > before) change(controls.UI_LEFT ? -1 : 1);
		}

		if (controls.ACCEPT) accept();

		if (controls.BACK)
		{
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if (onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else MusicBeatState.switchState(new MainMenuState());
		}
		cursor.x = 58 + Math.sin(FlxG.game.ticks / 160) * 4;
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
