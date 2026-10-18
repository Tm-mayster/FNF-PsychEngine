package states;

/**
 * Field of Hopes — offset calibration with a real song.
 * Ember plays (120 BPM, beats every 500 ms from the start of the file);
 * the player taps any key to the beat, the median of the tap errors becomes the note offset.
 */
class FohCalibrationState extends MusicBeatState
{
	public static var returnToOptions:Bool = false;

	static inline var BEAT_MS:Float = 500;
	static inline var WARMUP:Int = 4;
	static inline var KEEP:Int = 32;

	var taps:Array<Float> = [];
	var count:Int = 0;
	var info:FlxText;
	var result:FlxText;
	var lamp:FlxSprite;
	var glow:FlxSprite;
	var bars:Array<FlxSprite> = [];
	var lastBeat:Int = -1;

	override function create()
	{
		super.create();
		var font = MainMenuState.menuFont();

		var bg = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = false;
		bg.setGraphicSize(FlxG.width + 8);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		var shade = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF07041A);
		shade.alpha = 0.6;
		add(shade);

		var title = new FlxText(40, 36, 0, Lang.t('КАЛИБРОВКА ПО ПЕСНЕ'), 28);
		title.setFormat(font, 28, FlxColor.WHITE, LEFT, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		var how = new FlxText(40, 100, FlxG.width - 80,
			Lang.t('Играет «Ember». Нажимайте любую клавишу ровно в такт ударам музыки — слушайте звук, а не смотрите на фонарь.\n')
			+ Lang.t('Первые ') + WARMUP + Lang.t(' нажатия не считаются. Нужно хотя бы 16.'), 14);
		how.setFormat(font, 14, 0xFFCFC6F2, LEFT);
		MainMenuState.leading(how, 7);
		add(how);

		glow = new FlxSprite().makeGraphic(160, 160, 0xFFFFCF5A);
		glow.screenCenter();
		glow.y += 10;
		glow.alpha = 0;
		add(glow);
		lamp = new FlxSprite().makeGraphic(120, 120, 0xFF3A3550);
		lamp.screenCenter();
		lamp.y += 10;
		add(lamp);

		// tap history: one bar per tap, height = error
		for (i in 0...KEEP)
		{
			var b = new FlxSprite(FlxG.width / 2 - KEEP * 7 + i * 14, 560).makeGraphic(10, 2, 0xFFFFFFFF);
			b.visible = false;
			bars.push(b);
			add(b);
		}
		var zero = new FlxSprite(FlxG.width / 2 - KEEP * 7 - 10, 560).makeGraphic(KEEP * 14 + 20, 2, 0xFF7A5CC4);
		add(zero);

		info = new FlxText(40, 470, FlxG.width - 80, '', 16);
		info.setFormat(font, 16, FlxColor.WHITE, CENTER);
		MainMenuState.leading(info, 7);
		add(info);

		result = new FlxText(40, FlxG.height - 92, FlxG.width - 80,
			Lang.t('ENTER — сохранить   R — начать заново   ESC — выйти без сохранения'), 12);
		result.setFormat(font, 12, 0xFFCFC6F2, CENTER);
		add(result);

		FlxG.sound.playMusic(Paths.inst('ember'), 1, true);
		refresh();
	}

	function median():Float
	{
		if (taps.length == 0) return 0;
		var s = taps.copy();
		s.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		var m = s.length >> 1;
		return (s.length % 2 == 1) ? s[m] : (s[m - 1] + s[m]) / 2;
	}

	function spread():Float
	{
		if (taps.length < 2) return 0;
		var med = median();
		var sum = 0.0;
		for (t in taps) sum += Math.abs(t - med);
		return sum / taps.length;
	}

	function refresh()
	{
		var med = Math.round(median());
		var sign = med > 0 ? '+' : '';
		if (taps.length == 0)
			info.text = Lang.t('Нажатий: ') + count + Lang.t('\nТекущая задержка: ') + ClientPrefs.data.noteOffset + Lang.t(' мс');
		else
			info.text = Lang.t('Нажатий: ') + taps.length + Lang.t('   Вы попадаете: ') + sign + med + Lang.t(' мс (разброс ±') + Math.round(spread()) + ')\n'
				+ (taps.length < 16 ? Lang.t('Продолжайте...') : Lang.t('Готово! ENTER — сохранить задержку ') + sign + med + Lang.t(' мс'));
		for (i in 0...KEEP)
		{
			var b = bars[i];
			if (i < taps.length)
			{
				var e = taps[taps.length - 1 - i];
				var h = Std.int(Math.min(80, Math.abs(e) * 0.8)) + 2;
				b.makeGraphic(10, h, Math.abs(e) < 25 ? 0xFF7DF9B0 : Math.abs(e) < 60 ? 0xFFFFE27A : 0xFFFF5A6E);
				b.y = e > 0 ? 560 - h : 562;
				b.visible = true;
			}
			else b.visible = false;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.sound.music == null) return;
		var t:Float = FlxG.sound.music.time;

		// visual pulse on each beat
		var beat = Std.int(t / BEAT_MS);
		if (beat != lastBeat)
		{
			lastBeat = beat;
			glow.alpha = 0.8;
			lamp.color = 0xFFFFE9A8;
		}
		glow.alpha = Math.max(0, glow.alpha - elapsed * 3);
		lamp.color = FlxColor.interpolate(lamp.color, 0xFF3A3550, Math.min(1, elapsed * 6));

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			leave();
			return;
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			if (taps.length >= 8)
			{
				ClientPrefs.data.noteOffset = Std.int(Math.round(median()));
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				leave();
			}
			return;
		}
		if (FlxG.keys.justPressed.R)
		{
			taps = []; count = 0;
			refresh();
			return;
		}
		if (FlxG.keys.justPressed.ANY)
		{
			count++;
			// error relative to the nearest beat (positive = you hear it later than it plays)
			var err = t - Math.round(t / BEAT_MS) * BEAT_MS;
			if (count > WARMUP)
			{
				taps.push(err);
				if (taps.length > KEEP) taps.shift();
			}
			refresh();
		}
	}

	function leave()
	{
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		if (returnToOptions)
		{
			returnToOptions = false;
			MusicBeatState.switchState(new options.OptionsState());
		}
		else MusicBeatState.switchState(new MainMenuState());
	}
}
