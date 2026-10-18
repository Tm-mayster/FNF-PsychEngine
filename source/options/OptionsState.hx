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
	static var curSelected:Int = 1;

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
			{kind: 'header', label: 'ИГРА'},
			{kind: 'scrolltype', label: 'Режим скролла', desc: 'osu!mania: скорость 1–40, как в osu! (время ноты на экране = 11485 / скорость мс).\nC-mod (Etterna): постоянная скорость C100–C2000.\nМножитель x: старый режим FNF, умножает скорость песни.'},
			{kind: 'scroll', label: 'Скорость скролла', desc: 'ВЛЕВО/ВПРАВО — изменить. В osu!mania шаг 1, в C-mod шаг 10, в множителе 0.05. Скорость одинакова во всех песнях (кроме режима x).'},
			{kind: 'bool', label: 'Ноты сверху вниз', field: 'downScroll', desc: 'Стрелки внизу экрана, ноты падают сверху.'},
			{kind: 'bool', label: 'Стрелки по центру', field: 'middleScroll', desc: 'Ваши стрелки посередине экрана.'},
			{kind: 'bool', label: 'Стрелки противника', field: 'opponentStrums', desc: 'Показывать ноты противника.'},
			{kind: 'bool', label: 'Свободные нажатия', field: 'ghostTapping', desc: 'Нажатие без ноты не считается промахом.'},
			{kind: 'bool', label: 'Отключить сброс (R)', field: 'noReset', desc: 'Клавиша сброса не перезапускает песню.'},
			{kind: 'num', label: 'Громкость щелчка', field: 'hitsoundVolume', min: 0, max: 1, step: 0.1, decimals: 1, desc: 'Звук при попадании по ноте. 0 — выключен.',
				after: function() { FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume); }},
			{kind: 'list', label: 'Строгость попаданий', field: 'hitPreset', values: ['fnf', 'soft', 'strict'], names: ['Как в FNF', 'Мягкая', 'Строгая'],
				desc: 'Как в FNF — обычные окна Friday Night Funkin\' и Psych-модов (Sick ±45 мс, Good ±90, Bad ±135).\nМягкая — для новичков. Строгая — для тех, кто играет в osu!mania / Etterna.',
				after: function() { ClientPrefs.applyOD(); }},

			{kind: 'header', label: 'ЗВУК И ЗАДЕРЖКА'},
			{kind: 'open', label: 'Калибровка задержки', target: 'offset', desc: 'Играет песня — нажимайте в такт, и игра сама подберёт задержку.'},
			{kind: 'bool', label: 'Автоподстройка задержки', field: 'autoOffset', desc: 'После каждой песни игра смотрит, раньше или позже вы нажимаете, и сама подправляет задержку. Калибровка не нужна.'},
			{kind: 'num', label: 'Задержка нот', field: 'noteOffset', min: -500, max: 500, step: 1, decimals: 0, suffix: ' мс', desc: 'Сдвиг всех нот. Плюс — ноты позже, минус — раньше.'},
			{kind: 'bool', label: 'Пауза при сворачивании', field: 'autoPause', desc: 'Игра останавливается, когда окно не активно.',
				after: function() { FlxG.autoPause = ClientPrefs.data.autoPause; }},

			{kind: 'header', label: 'УПРАВЛЕНИЕ'},
			{kind: 'open', label: 'Клавиши', target: 'controls', desc: 'Назначить клавиши. Работают и при русской раскладке: , . ; [ ] и буквы — по месту на клавиатуре.'},
			{kind: 'bool', label: 'Геймпад', field: 'gamepadEnabled', desc: 'Принимать ввод с геймпада. Выключено по умолчанию: подключённый или виртуальный контроллер (Steam, драйверы) может сам «нажимать» кнопки и отключать клавиатуру в игре.'},
			{kind: 'list', label: 'Вид нот', field: 'noteSkin', values: ['Default', 'Circles', 'Diamonds', 'Bars'],
				names: ['Стрелки', 'Круги', 'Ромбы', 'Полосы'], desc: 'Форма нот: классические стрелки FNF, круги, ромбы или полосы как в osu!mania / Etterna. Цвета настраиваются ниже.'},
			{kind: 'open', label: 'Цвета нот', target: 'colors', desc: 'Настроить цвета стрелок (экран редактора на английском).'},

			{kind: 'header', label: 'ЭКРАН'},
			{kind: 'bool', label: 'Счётчик FPS', field: 'showFPS', desc: 'Показывать частоту кадров в углу.',
				after: function() { if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.data.showFPS; }},
			{kind: 'fps', label: 'Частота кадров', field: 'framerate', desc: 'Ограничение FPS. 240–360 — минимальная задержка без нагрузки. «Без ограничений» грузит процессор и может вызывать заикание звука.'},
			{kind: 'bool', label: 'Вспышки', field: 'flashing', desc: 'Мигающие эффекты. Выключите, если они мешают.'},
			{kind: 'bool', label: 'Приближение камеры', field: 'camZooms', desc: 'Камера пульсирует в такт.'},
			{kind: 'bool', label: 'Скрыть интерфейс', field: 'hideHud', desc: 'Убрать полоску здоровья, счёт и прочее.'},
			{kind: 'list', label: 'Таймер песни', field: 'timeBarType', values: ['Time Left', 'Time Elapsed', 'Song Name', 'Disabled'],
				names: ['Осталось', 'Прошло', 'Название', 'Выключен'], desc: 'Что показывать на полоске времени.'},
			{kind: 'num', label: 'Прозрачность здоровья', field: 'healthBarAlpha', min: 0, max: 1, step: 0.1, decimals: 1, desc: 'Видимость полоски здоровья.'},
			{kind: 'num', label: 'Брызги нот', field: 'splashAlpha', min: 0, max: 1, step: 0.1, decimals: 1, desc: 'Яркость эффекта при точном попадании. 0 — выключены.'},
			{kind: 'bool', label: 'Счёт пульсирует', field: 'scoreZoom', desc: 'Текст счёта увеличивается при попадании.'},
			{kind: 'bool', label: 'Комбо стопкой', field: 'comboStacking', desc: 'Оценки складываются друг на друга.'},
			{kind: 'bool', label: 'Низкое качество', field: 'lowQuality', desc: 'Меньше деталей фона, быстрее на слабых ПК.'},
			{kind: 'bool', label: 'Шейдеры', field: 'shaders', desc: 'Визуальные эффекты. Выключите на слабых ПК.'},
			{kind: 'bool', label: 'Сглаживание', field: 'antialiasing', desc: 'Сглаживание обычной графики (пиксель-арт мода не размывается).'},
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

		var title = new FlxText(40, 36, 0, 'НАСТРОЙКИ', 32);
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
		descText.wordWrap = true;
		add(descText);

		var hint = new FlxText(40, FlxG.height - 92, FlxG.width - 80,
			'ВВЕРХ/ВНИЗ — выбор   ВЛЕВО/ВПРАВО — изменить\nENTER — переключить/открыть   ESC — назад', 12);
		hint.setFormat(font(), 12, 0xFFCFC6F2, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		add(hint);

		if (curSelected >= items.length || items[curSelected].kind == 'header') curSelected = 1;
		refresh();
		ClientPrefs.saveSettings();
		super.create();
	}

	function valueText(it:FohSetting):String
	{
		switch (it.kind)
		{
			case 'bool':
				return Reflect.getProperty(ClientPrefs.data, it.field) == true ? 'ВКЛ' : 'ВЫКЛ';
			case 'num':
				var v:Float = Reflect.getProperty(ClientPrefs.data, it.field);
				var p = Math.pow(10, it.decimals);
				var s = Std.string(Math.round(v * p) / p);
				return '< ' + s + (it.suffix != null ? it.suffix : '') + ' >';
			case 'list':
				var cur:String = Reflect.getProperty(ClientPrefs.data, it.field);
				var idx = it.values.indexOf(cur);
				return '< ' + (idx >= 0 ? it.names[idx] : cur) + ' >';
			case 'scroll':
				return '< ' + ScrollUtil.valueText() + ' >';
			case 'scrolltype':
				return '< ' + ScrollUtil.typeName() + ' >';
			case 'open':
				return 'ОТКРЫТЬ';
			case 'fps':
				var f:Int = ClientPrefs.data.framerate;
				return '< ' + (f >= 1000 ? 'БЕЗ ОГРАНИЧ.' : Std.string(f)) + ' >';
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
			+ (it.field == 'hitPreset' ? '\n\nСейчас: ' + ClientPrefs.odWindowsText() : '');
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
