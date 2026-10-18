package states;

import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import openfl.utils.AssetType;

/**
 * Field of Hopes — custom main menu.
 * Vertical list on the left, description panel on the right,
 * scroll speed adjustable right inside the list, calibration one click away.
 */
typedef FohMenuEntry = {
	var id:String;
	var label:String;
	var desc:String;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	public static var modVersion:String = '0.3';
	public static var curSelected:Int = 0;

	public static inline var MENU_FONT:String = 'PressStart2P.ttf';

	var entries:Array<FohMenuEntry> = [];
	var labels:Array<FlxText> = [];
	var cursor:FlxText;
	var descText:FlxText;
	var hintText:FlxText;
	var panel:FlxSprite;
	var mascot:FlxSprite;
	var selectedSomethin:Bool = false;
	var allowMouse:Bool = true;
	var timeNotMoving:Float = 0;
	var holdTime:Float = 0;

	static var showOutdatedWarning:Bool = true;
	var updateMarked:Bool = false;

	public static function menuFont():String
		return Paths.font(MENU_FONT);

	/** extra space between lines: the pixel font is very tight by default */
	public static function leading(t:FlxText, px:Int = 6):FlxText
	{
		@:privateAccess
		{
			t._defaultFormat.leading = px;
			t.updateDefaultFormat();
		}
		return t;
	}

	function buildEntries()
	{
		entries = [
			{id: 'story_mode', label: 'Сюжет', desc: 'Пройти недели по порядку: песни идут одна за другой, счёт суммируется.'},
			{id: 'freeplay', label: 'Свободная игра', desc: 'Любая песня и любая сложность. Видно звёзды, NPS и ваш лучший результат.\n\nПрогресс игры: ' + (FlxG.save.data.fohProgress != null ? FlxG.save.data.fohProgress : 0) + '%\n100% = все песни пройдены на Hard или выше (точность любая).'},
			{id: 'coop', label: 'Вдвоём (2 игрока)', desc: 'Двое на одной клавиатуре, без настроек.\n\nИгрок 2 (слева, за противника): Z X C V\nИгрок 1 (справа, за Люмена): стрелки\n\nПолоска здоровья — перетягивание каната, в конце показывается победитель. Выбор песни — как в свободной игре.'},
			{id: 'scroll', label: '', desc: 'ВЛЕВО/ВПРАВО — изменить скорость.\nСкорость одинаковая во всех песнях.\nENTER — сменить режим:\n• osu!mania 1–40 (как в osu!; больше = быстрее);\n• C-mod как в Etterna.'},
			{id: 'calibrate', label: 'Калибровка задержки', desc: 'Играет песня — нажимайте в такт, и игра сама вычислит задержку вашего звука и клавиатуры.'},
			{id: 'options', label: 'Настройки', desc: 'Управление, графика, звук и игровые параметры.'},
			#if ACHIEVEMENTS_ALLOWED {id: 'achievements', label: 'Достижения', desc: 'Награды за пройденные песни и особые условия.'}, #end
			#if windows {id: 'update', label: 'Обновление', desc: 'Скачать новую версию игры прямо отсюда — загружаются только изменённые файлы.'}, #end
			{id: 'credits', label: 'Титры', desc: 'Авторы мода, движка и музыки.'}
		];
	}

	function scrollLabel():String
		return 'Скролл: < ' + ScrollUtil.label() + ' >';

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;
		buildEntries();
		if (curSelected >= entries.length) curSelected = 0;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = false;
		bg.setGraphicSize(FlxG.width + 8);
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		var shade:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF07041A);
		shade.alpha = 0.35;
		add(shade);

		var listBG:FlxSprite = new FlxSprite(40, 150).makeGraphic(560, 470, 0xFF0B0614);
		listBG.alpha = 0.72;
		add(listBG);

		panel = new FlxSprite(640, 150).makeGraphic(600, 300, 0xFF0B0614);
		panel.alpha = 0.72;
		add(panel);

		var title:FlxText = new FlxText(40, 40, 0, 'FIELD OF HOPES', 32);
		title.setFormat(menuFont(), 32, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		var sub:FlxText = new FlxText(42, 90, 0, 'Лумен против Сэра Перо', 14);
		sub.setFormat(menuFont(), 14, 0xFFFFCF5A, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		add(sub);

		for (i in 0...entries.length)
		{
			var t:FlxText = new FlxText(90, 160 + i * 42, 0, '', 18);
			t.setFormat(menuFont(), 18, 0xFFCFC6F2, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
			t.borderSize = 2;
			labels.push(t);
			add(t);
		}

		cursor = new FlxText(56, 0, 0, '>', 18);
		cursor.setFormat(menuFont(), 18, 0xFFFFCF5A, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		add(cursor);

		descText = new FlxText(664, 172, 552, '', 14);
		descText.setFormat(menuFont(), 14, 0xFFFFFFFF, LEFT);
		leading(descText, 7);
		descText.wordWrap = true;
		add(descText);

		// mascot from the mod (optional — only if the mod is installed)
		if (Paths.fileExists('images/characters/lumen.png', IMAGE) && Paths.fileExists('images/characters/lumen.xml', TEXT))
		{
			mascot = new FlxSprite(1020, 420);
			mascot.frames = Paths.getSparrowAtlas('characters/lumen');
			mascot.animation.addByPrefix('idle', 'lumen idle', 4, true);
			mascot.animation.play('idle');
			mascot.antialiasing = false;
			mascot.scale.set(0.7, 0.7);
			mascot.updateHitbox();
			mascot.y = FlxG.height - mascot.height - 30;
			add(mascot);
		}

		hintText = new FlxText(40, FlxG.height - 58, FlxG.width - 80,
			'ВВЕРХ/ВНИЗ — выбор   ENTER — открыть   ESC — назад\nМышь: наведите и щёлкните, колесо — листать', 12);
		hintText.setFormat(menuFont(), 12, 0xFFCFC6F2, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		hintText.visible = false; // Field of Hopes: no control hints on screen, the menu explains itself

		var ver:FlxText = new FlxText(0, 8, FlxG.width - 12,
			'v' + modVersion, 12);
		ver.setFormat(menuFont(), 10, 0xFFCFC6F2, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		ver.alpha = 0.5;
		add(ver);

		refresh();

		#if ACHIEVEMENTS_ALLOWED
		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if windows
		if (!backend.FohUpdater.checkedThisSession) backend.FohUpdater.check();
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end
	}

	function refresh()
	{
		for (i in 0...entries.length)
		{
			var e = entries[i];
			var t = labels[i];
			t.text = (e.id == 'scroll') ? scrollLabel() : e.label;
			t.color = (i == curSelected) ? 0xFFFFCF5A : 0xFFCFC6F2;
			t.x = (i == curSelected) ? 100 : 90;
		}
		cursor.y = labels[curSelected].y;
		var e = entries[curSelected];
		var extra:String = '';
		if (e.id == 'scroll')
			extra = '\n\nСейчас: ' + ScrollUtil.typeName() + ', ' + ScrollUtil.valueText();
		if (e.id == 'calibrate')
			extra = '\n\nТекущая задержка: ' + ClientPrefs.data.noteOffset + ' мс';
		descText.text = e.label.length > 0 ? e.label.toUpperCase() + '\n\n' + e.desc + extra : e.desc + extra;
	}

	function changeItem(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, entries.length - 1);
		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
		refresh();
	}

	function changeScroll(dir:Int)
	{
		ScrollUtil.change(dir);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	function toggleScrollType()
	{
		// only the constant-speed modes here (same speed in every song); the old FNF multiplier lives in the settings
		ClientPrefs.data.gameplaySettings.set('scrolltype', ScrollUtil.type() == 'osu' ? 'cmod' : 'osu');
		ClientPrefs.saveSettings();
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
		refresh();
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P) changeItem(-1);
			if (controls.UI_DOWN_P) changeItem(1);
			if (FlxG.mouse.wheel != 0) changeItem(-FlxG.mouse.wheel);

			var isScroll:Bool = entries[curSelected].id == 'scroll';
			if (isScroll)
			{
				if (controls.UI_LEFT_P) { changeScroll(-1); holdTime = 0; }
				if (controls.UI_RIGHT_P) { changeScroll(1); holdTime = 0; }
				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					var before:Int = Math.floor((holdTime - 0.4) * 12);
					holdTime += elapsed;
					var after:Int = Math.floor((holdTime - 0.4) * 12);
					if (holdTime > 0.4 && after > before) changeScroll(controls.UI_LEFT ? -1 : 1);
				}
			}

			// mouse hover + click
			if (allowMouse && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed))
			{
				FlxG.mouse.visible = true;
				timeNotMoving = 0;
				for (i in 0...labels.length)
				{
					var t = labels[i];
					if (FlxG.mouse.screenY >= t.y - 10 && FlxG.mouse.screenY <= t.y + t.height + 10
						&& FlxG.mouse.screenX >= 40 && FlxG.mouse.screenX <= 600)
					{
						if (i != curSelected) { curSelected = i; changeItem(); FlxG.sound.play(Paths.sound('scrollMenu'), 0.4); }
						if (FlxG.mouse.justPressed) accept();
						break;
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if (timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT) accept();

			#if desktop
			if (!selectedSomethin && controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		#if windows
		if (!updateMarked && backend.FohUpdater.state == 'available')
		{
			updateMarked = true;
			for (e in entries) if (e.id == 'update')
			{
				e.label = 'Обновление ★';
				e.desc = 'Вышла новая версия игры (сборка ' + backend.FohUpdater.remoteBuild + '). ENTER — скачать прямо из игры, только изменённые файлы.';
			}
			refresh();
		}
		#end
		cursor.x = 56 + Math.sin(FlxG.game.ticks / 160) * 4;
		super.update(elapsed);
	}

	function accept()
	{
		if (selectedSomethin) return;
		var option:String = entries[curSelected].id;
		if (option == 'scroll')
		{
			toggleScrollType();
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		selectedSomethin = true;
		FlxG.mouse.visible = false;

		var item:FlxText = labels[curSelected];
		for (i in 0...labels.length)
			if (i != curSelected) FlxTween.tween(labels[i], {alpha: 0.25}, 0.4, {ease: FlxEase.quadOut});

		FlxFlicker.flicker(item, 0.8, 0.06, true, false, function(flick:FlxFlicker)
		{
			switch (option)
			{
				case 'story_mode':
					MusicBeatState.switchState(new StoryMenuState());
				case 'freeplay':
					PlayState.coopMode = false;
					MusicBeatState.switchState(new FreeplayState());
				case 'coop':
					PlayState.coopMode = true;
					MusicBeatState.switchState(new FreeplayState());
				case 'calibrate':
					FohCalibrationState.returnToOptions = false;
					MusicBeatState.switchState(new FohCalibrationState());
				#if MODS_ALLOWED
				case 'mods':
					MusicBeatState.switchState(new ModsMenuState());
				#end
				#if ACHIEVEMENTS_ALLOWED
				case 'achievements':
					MusicBeatState.switchState(new AchievementsMenuState());
				#end
				case 'credits':
					MusicBeatState.switchState(new CreditsState());
				case 'update':
					MusicBeatState.switchState(new FohUpdateState());
				case 'options':
					MusicBeatState.switchState(new OptionsState());
					OptionsState.onPlayState = false;
					if (PlayState.SONG != null)
					{
						PlayState.SONG.arrowSkin = null;
						PlayState.SONG.splashSkin = null;
						PlayState.stageUI = 'normal';
					}
				default:
					selectedSomethin = false;
			}
		});
	}
}
