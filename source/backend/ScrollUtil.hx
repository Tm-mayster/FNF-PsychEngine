package backend;

/**
 * Field of Hopes — scroll speed modes.
 *  - osu:  osu!mania scroll speed 1..40  (time on screen = 11485.6 / speed ms, like osu!lazer)
 *  - cmod: Etterna / StepMania C-mod   (C100..C2000, constant regardless of the song)
 *  - multiplicative: classic FNF "x1.0" (multiplies the chart's own speed)
 */
class ScrollUtil
{
	public static inline var OSU_MAX_TIME:Float = 11485.6;
	public static inline var TRAVEL_PX:Float = 640;     // receptor -> edge of screen
	public static inline var PX_PER_MS:Float = 0.45;    // Psych: y = 0.45 * ms * speed

	public static function type():String
	{
		var t:String = ClientPrefs.getGameplaySetting('scrolltype');
		if (t == 'constant') t = 'cmod';
		if (t != 'osu' && t != 'cmod' && t != 'multiplicative') t = 'osu';
		return t;
	}

	public static function isConstant():Bool
		return type() != 'multiplicative';

	static function getF(name:String, def:Float):Float
	{
		var v:Dynamic = ClientPrefs.data.gameplaySettings.get(name);
		return v == null ? def : v;
	}

	public static function osuSpeed():Int return Std.int(getF('osuspeed', 24));
	public static function cmodSpeed():Int return Std.int(getF('cmodspeed', 700));
	public static function xSpeed():Float return getF('scrollspeed', 1);

	/** speed value the engine uses for a chart with its own `chartSpeed` */
	public static function songSpeed(chartSpeed:Float):Float
	{
		return switch (type())
		{
			case 'osu':
				var ms = OSU_MAX_TIME / Math.max(1, osuSpeed());
				TRAVEL_PX / (PX_PER_MS * ms);
			case 'cmod':
				// StepMania: 1x = 64 px per beat at 480p -> scale to 720p
				cmodSpeed() * 64 / 60 * 1.5 / (PX_PER_MS * 1000);
			default:
				chartSpeed * xSpeed();
		}
	}

	public static function typeName():String
	{
		return switch (type()) { case 'osu': 'osu!mania'; case 'cmod': 'C-mod (Etterna)'; default: 'Множитель x'; }
	}

	public static function valueText():String
	{
		return switch (type())
		{
			case 'osu': Std.string(osuSpeed());
			case 'cmod': 'C' + cmodSpeed();
			default: 'x' + (Math.round(xSpeed() * 100) / 100);
		}
	}

	/** short label, e.g. "osu! 24" / "C700" / "x1.05" */
	public static function label():String
	{
		return switch (type()) { case 'osu': 'osu! ' + osuSpeed(); case 'cmod': 'C' + cmodSpeed(); default: 'x' + (Math.round(xSpeed() * 100) / 100); }
	}

	public static function change(dir:Int)
	{
		var gs = ClientPrefs.data.gameplaySettings;
		switch (type())
		{
			case 'osu': gs.set('osuspeed', Std.int(FlxMath.bound(osuSpeed() + dir, 1, 40)));
			case 'cmod': gs.set('cmodspeed', Std.int(FlxMath.bound(cmodSpeed() + dir * 10, 100, 2000)));
			default: gs.set('scrollspeed', FlxMath.bound(Math.round((xSpeed() + dir * 0.05) * 100) / 100, 0.35, 3));
		}
		ClientPrefs.saveSettings();
	}

	public static function cycleType(dir:Int = 1)
	{
		var order = ['osu', 'cmod', 'multiplicative'];
		var i = order.indexOf(type());
		i = FlxMath.wrap(i + dir, 0, order.length - 1);
		ClientPrefs.data.gameplaySettings.set('scrolltype', order[i]);
		ClientPrefs.saveSettings();
	}

	/** first run of this version: switch everyone to osu!mania scroll */
	public static function migrate()
	{
		// v2: constant speed for everyone again (the same in every song and difficulty)
		if (FlxG.save.data.fohScrollMigrated2 != true)
		{
			var gs2 = ClientPrefs.data.gameplaySettings;
			gs2.set('scrolltype', 'osu');
			gs2.set('osuspeed', 22);
			FlxG.save.data.fohScrollMigrated2 = true;
			FlxG.save.data.fohScrollMigrated = true;
		}
		if (FlxG.save.data.fohScrollMigrated != true)
		{
			var gs = ClientPrefs.data.gameplaySettings;
			gs.set('scrolltype', 'osu');
			if (!gs.exists('osuspeed')) gs.set('osuspeed', 24);
			if (!gs.exists('cmodspeed')) gs.set('cmodspeed', 700);
			FlxG.save.data.fohScrollMigrated = true;
		}
	}
}
