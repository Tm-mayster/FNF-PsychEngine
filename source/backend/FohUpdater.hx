package backend;

#if (sys && windows)
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.crypto.Sha1;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
#end

/**
 * Field of Hopes — in-game updater.
 * Every Windows build is pushed by CI to the `dist-windows` branch together with `update.json`
 * (build number + sha1/size of every file). The game compares it with its own `update.json`
 * and downloads only the files that changed, straight from raw.githubusercontent.com (no login needed).
 */
class FohUpdater
{
	public static inline var BASE:String = 'https://raw.githubusercontent.com/Tm-mayster/FNF-PsychEngine/dist-windows/';

	/** idle, checking, none, available, error, scanning, ready, downloading, done */
	public static var state:String = 'idle';
	public static var error:String = '';
	public static var localBuild:Int = 0;
	public static var remoteBuild:Int = 0;
	public static var totalBytes:Float = 0;
	public static var doneBytes:Float = 0;
	public static var fileCount:Int = 0;
	public static var filesDone:Int = 0;
	public static var current:String = '';
	public static var restartNeeded:Bool = false;
	public static var checkedThisSession:Bool = false;

	#if (sys && windows)
	static var remote:Dynamic = null;
	static var todo:Array<Dynamic> = [];

	public static function gameDir():String
		return Path.directory(Sys.programPath());

	static function local(p:String):String
		return Path.join([gameDir(), p]);

	static function encodePath(p:String):String
		return [for (seg in p.split('/')) StringTools.urlEncode(seg)].join('/');

	static function fetch(url:String):Bytes
	{
		var result:Bytes = null;
		var err:String = null;
		var h = new haxe.Http(url);
		h.setHeader('User-Agent', 'FieldOfHopes-Updater');
		h.onBytes = function(b:Bytes) result = b;
		h.onError = function(e:String) err = e;
		h.request(false);
		if (result == null) throw (err != null ? err : 'no data');
		return result;
	}

	static function readLocalManifest():Dynamic
	{
		try
		{
			var p = local('update.json');
			if (FileSystem.exists(p)) return Json.parse(File.getContent(p));
		}
		catch (e:Dynamic) {}
		return null;
	}

	/** run once on startup: finish an update that could not overwrite files in use, remove the old exe */
	public static function startupCleanup()
	{
		try
		{
			var old = Sys.programPath() + '.old';
			if (FileSystem.exists(old)) FileSystem.deleteFile(old);
		}
		catch (e:Dynamic) {}
		try
		{
			var pend = local('update_pending.txt');
			if (FileSystem.exists(pend))
			{
				for (line in File.getContent(pend).split('\n'))
				{
					var p = line.trim();
					if (p.length == 0) continue;
					var target = local(p);
					if (FileSystem.exists(target + '.new'))
					{
						try
						{
							if (FileSystem.exists(target)) FileSystem.deleteFile(target);
							FileSystem.rename(target + '.new', target);
						}
						catch (e:Dynamic) {}
					}
				}
				FileSystem.deleteFile(pend);
			}
		}
		catch (e:Dynamic) {}
	}

	/** background check: is there a newer build? */
	public static function check()
	{
		if (state == 'checking' || state == 'downloading' || state == 'scanning') return;
		checkedThisSession = true;
		state = 'checking';
		Thread.create(function() {
			try
			{
				var b = fetch(BASE + 'update.json');
				remote = Json.parse(b.toString());
				remoteBuild = Std.int(remote.build);
				var lm = readLocalManifest();
				localBuild = lm != null ? Std.int(lm.build) : 0;
				state = remoteBuild > localBuild ? 'available' : 'none';
			}
			catch (e:Dynamic)
			{
				error = Std.string(e);
				state = 'error';
			}
		});
	}

	/** compare files and work out what has to be downloaded */
	public static function scan()
	{
		if (remote == null) return;
		state = 'scanning';
		Thread.create(function() {
			try
			{
				var lm = readLocalManifest();
				var known = new Map<String, String>();
				if (lm != null) for (f in (lm.files : Array<Dynamic>)) known.set(f.p, f.h);
				todo = [];
				totalBytes = 0;
				for (f in (remote.files : Array<Dynamic>))
				{
					var p:String = f.p;
					var target = local(p);
					var need = true;
					if (FileSystem.exists(target) && FileSystem.stat(target).size == f.s)
					{
						if (known.exists(p)) need = known.get(p) != f.h;
						else
						{
							current = p;
							need = Sha1.make(File.getBytes(target)).toHex() != f.h;
						}
					}
					if (need)
					{
						todo.push(f);
						totalBytes += f.s;
					}
				}
				fileCount = todo.length;
				current = '';
				state = 'ready';
			}
			catch (e:Dynamic)
			{
				error = Std.string(e);
				state = 'error';
			}
		});
	}

	/** download the changed files and put them in place (the running exe is renamed, not overwritten) */
	public static function download()
	{
		if (state != 'ready') return;
		state = 'downloading';
		doneBytes = 0;
		filesDone = 0;
		Thread.create(function() {
			try
			{
				var exe = Path.normalize(Sys.programPath()).toLowerCase();
				var pending:Array<String> = [];
				// the exe goes last, so an interrupted download never leaves a broken game
				todo.sort(function(a, b) return (local(a.p).toLowerCase().endsWith('.exe') ? 1 : 0) - (local(b.p).toLowerCase().endsWith('.exe') ? 1 : 0));
				for (f in todo)
				{
					var p:String = f.p;
					current = p;
					var data = fetch(BASE + encodePath(p));
					if (Sha1.make(data).toHex() != f.h) throw 'файл повреждён при загрузке: ' + p;
					var target = local(p);
					var dir = Path.directory(target);
					if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
					if (Path.normalize(target).toLowerCase() == exe)
					{
						var old = target + '.old';
						if (FileSystem.exists(old)) FileSystem.deleteFile(old);
						FileSystem.rename(target, old);
						File.saveBytes(target, data);
						restartNeeded = true;
					}
					else
					{
						try File.saveBytes(target, data)
						catch (e:Dynamic)
						{
							// file is in use right now: finish it on the next start
							File.saveBytes(target + '.new', data);
							pending.push(p);
						}
					}
					doneBytes += f.s;
					filesDone++;
				}
				if (pending.length > 0) File.saveContent(local('update_pending.txt'), pending.join('\n'));
				File.saveContent(local('update.json'), Json.stringify(remote));
				localBuild = remoteBuild;
				restartNeeded = true;
				current = '';
				state = 'done';
			}
			catch (e:Dynamic)
			{
				error = Std.string(e);
				state = 'error';
			}
		});
	}

	public static function restart()
	{
		try
		{
			Sys.command('cmd', ['/c', 'start', '""', '/D', gameDir(), Sys.programPath()]);
		}
		catch (e:Dynamic) {}
		Sys.exit(0);
	}
	#else
	public static function startupCleanup() {}
	public static function check() {}
	public static function scan() {}
	public static function download() {}
	public static function restart() {}
	#end
}
