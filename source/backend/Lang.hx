package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Field of Hopes — simple localisation.
 * The game is written in Russian; every visible string goes through Lang.t("русский текст").
 * A language file maps the Russian text to a translation, one pair per line:
 *
 *     #name=English
 *     Свободная игра => Freeplay
 *     Первая строка\nвторая => First line\nsecond
 *
 * Files are looked up in assets/shared/data/lang/<code>.txt and in mods/<any mod>/lang/<code>.txt,
 * so a new language is just a new text file — no code changes needed.
 */
class Lang
{
	public static var current(default, null):String = 'ru';
	static var map:Map<String, String> = new Map();
	static var loaded:Bool = false;

	public static function t(s:String):String
	{
		if (!loaded || current == 'ru' || s == null) return s;
		var v = map.get(s);
		return v != null ? v : s;
	}

	/** available languages: [code, display name], Russian first */
	public static function list():Array<Array<String>>
	{
		var out:Array<Array<String>> = [['ru', 'Русский']];
		#if sys
		for (dir in folders())
		{
			for (f in FileSystem.readDirectory(dir))
			{
				if (!f.endsWith('.txt') || f.startsWith('_')) continue;
				var code = f.substr(0, f.length - 4);
				if (code == 'ru' || out.filter(function(e) return e[0] == code).length > 0) continue;
				out.push([code, readName(dir + '/' + f, code)]);
			}
		}
		#end
		return out;
	}

	public static function nameOf(code:String):String
	{
		for (e in list()) if (e[0] == code) return e[1];
		return code;
	}

	public static function load(code:String)
	{
		loaded = true;
		map = new Map();
		current = (code == null || code.length == 0) ? 'ru' : code;
		if (current == 'ru') return;
		#if sys
		var found = false;
		for (dir in folders())
		{
			var p = dir + '/' + current + '.txt';
			if (!FileSystem.exists(p)) continue;
			found = true;
			for (line in File.getContent(p).split('\n'))
			{
				var l = line.replace('\r', '');
				if (l.length == 0 || l.startsWith('#')) continue;
				var i = l.indexOf(' => ');
				if (i < 0) continue;
				map.set(unescape(l.substr(0, i)), unescape(l.substr(i + 4)));
			}
		}
		if (!found) current = 'ru';
		#end
	}

	/** first start: Russian for Russian-speaking systems, English for everyone else */
	public static function detectDefault():String
	{
		var sys:String = 'en';
		try sys = openfl.system.Capabilities.language catch (e:Dynamic) {}
		if (sys == null) sys = 'en';
		sys = sys.toLowerCase();
		if (sys.startsWith('ru') || sys.startsWith('uk') || sys.startsWith('be') || sys.startsWith('kk')) return 'ru';
		for (e in list()) if (sys.startsWith(e[0])) return e[0];
		return 'en';
	}

	static function unescape(s:String):String
		return s.replace('\\n', '\n').replace('\\t', '\t');

	#if sys
	static function folders():Array<String>
	{
		var out:Array<String> = [];
		var base = 'assets/shared/data/lang';
		if (FileSystem.exists(base)) out.push(base);
		#if MODS_ALLOWED
		var root = Paths.mods('lang');
		if (FileSystem.exists(root)) out.push(root);
		for (m in Mods.getModDirectories())
		{
			var d = Paths.mods(m + '/lang');
			if (FileSystem.exists(d) && !out.contains(d)) out.push(d);
		}
		#end
		return out;
	}

	static function readName(path:String, code:String):String
	{
		try
		{
			for (line in File.getContent(path).split('\n'))
			{
				var l = line.replace('\r', '').trim();
				if (l.startsWith('#name=')) return l.substr(6);
			}
		}
		catch (e:Dynamic) {}
		return code;
	}
	#end
}
