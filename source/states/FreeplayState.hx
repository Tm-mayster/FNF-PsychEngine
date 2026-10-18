package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var statsBG:FlxSprite;
	var statsText:FlxText;
	var starBase:Array<FlxSprite> = [];
	var starTop:Array<FlxSprite> = [];
	var starValue:Float = 0;
	var starNum:FlxText;
	var clearBadge:FlxText;
	var progressText:FlxText;
	static var statsCache:Map<String, Array<Float>> = [];
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			
			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		statsBG = new FlxSprite(FlxG.width - 470, 72).makeGraphic(470, 190, 0xFF0B0614);
		statsBG.alpha = 0.7;
		add(statsBG);
		statsText = new FlxText(FlxG.width - 456, 82, 442, '', 12);
		statsText.setFormat(MainMenuState.menuFont(), 12, FlxColor.WHITE, LEFT);
		add(statsText);
		for (i in 0...10)
		{
			var b = new FlxSprite(FlxG.width - 458 + i * 34, 166).loadGraphic(Paths.image('fohStar'));
			b.antialiasing = false;
			starBase.push(b);
			add(b);
		}
		for (i in 0...10)
		{
			var t = new FlxSprite(FlxG.width - 458 + i * 34, 166).loadGraphic(Paths.image('fohStar'));
			t.antialiasing = false;
			t.visible = false;
			starTop.push(t);
			add(t);
		}
		starNum = new FlxText(FlxG.width - 112, 174, 104, '', 16);
		starNum.setFormat(MainMenuState.menuFont(), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		add(starNum);
		progressText = new FlxText(12, 8, 600, '', 16);
		progressText.setFormat(MainMenuState.menuFont(), 16, 0xFFFFE27A, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		progressText.borderSize = 3;
		add(progressText);
		updateProgress();

		clearBadge = new FlxText(FlxG.width - 458, 212, 440, '', 14);
		clearBadge.setFormat(MainMenuState.menuFont(), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
		clearBadge.borderSize = 2;
		add(clearBadge);


		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "SPACE: Listen / CTRL: Gameplay Changers / Q,E: Scroll Speed / RESET: Reset Score");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		if (PlayState.lastOffsetMessage != null)
		{
			var note = new FlxText(40, FlxG.height - 110, FlxG.width - 80, PlayState.lastOffsetMessage, 14);
			note.setFormat(MainMenuState.menuFont(), 14, 0xFF7DF9B0, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF0B0614);
			note.borderSize = 2;
			add(note);
			PlayState.lastOffsetMessage = null;
			FlxTween.tween(note, {alpha: 0}, 1.5, {startDelay: 6});
		}
		
		changeSelection();
		updateTexts();
		super.create();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		animateStars(elapsed);
		if(WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}

			if (FlxG.keys.justPressed.Q || FlxG.keys.justPressed.E)
			{
				ScrollUtil.change(FlxG.keys.justPressed.E ? 1 : -1);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				updateStats();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		updateStats();
	}

	function computeStats(chart:Dynamic):Array<Float>
	{
		var times:Array<Float> = [];
		var sections:Array<Dynamic> = chart.notes;
		if (sections != null)
			for (sec in sections)
			{
				var notes:Array<Dynamic> = sec.sectionNotes;
				if (notes == null) continue;
				for (n in notes)
					if (n[1] >= 0 && n[1] < 4) times.push(n[0]);
			}
		if (times.length < 2) return [times.length, 0, 0, 0];
		times.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));

		// chords: notes sharing a timestamp
		var chords:Int = 0;
		for (i in 1...times.length)
			if (Math.abs(times[i] - times[i - 1]) < 2) chords++;

		var dur:Float = (times[times.length - 1] - times[0]) / 1000;
		var avg:Float = dur > 0 ? times.length / dur : 0;

		// peak density over a sliding 4-second window
		var peak:Float = 0;
		var j:Int = 0;
		for (i in 0...times.length)
		{
			while (times[i] - times[j] > 4000) j++;
			var nps:Float = (i - j + 1) / 4;
			if (nps > peak) peak = nps;
		}
		// star rating: ~1-2 easy, ~3 normal, ~5-6 hard, ~8 expert, 10+ insane
		var level:Float = 0.4 + 0.45 * avg + 0.55 * peak + 2.5 * (chords / times.length);
		return [times.length, avg, peak, level];
	}

	function updateStats()
	{
		if (statsText == null || songs.length < 1) return;
		var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
		var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
		var key:String = songs[curSelected].folder + '/' + poop;
		var st:Array<Float> = statsCache.get(key);
		if (st == null)
		{
			st = [-1, 0, 0, 0];
			try
			{
				var chart:Dynamic = Song.getChart(poop, songLowercase);
				if (chart != null) st = computeStats(chart);
			}
			catch (e:Dynamic) {}
			statsCache.set(key, st);
		}

		var r = function(v:Float) return Math.round(v * 10) / 10;
		var scroll:String = 'Скролл: ' + ScrollUtil.label() + '  Q/E';
		if (st[0] < 0)
		{
			statsText.text = 'Чарт не найден\n' + scroll;
			statsText.color = 0xFFCFC6F2;
			setStars(0);
			return;
		}
		statsText.text = 'Звёзды: ' + r(st[3]) + '   Нот: ' + Std.int(st[0])
			+ '\nNPS: ' + r(st[1]) + ' средн. / ' + r(st[2]) + ' пик'
			+ '\n' + scroll;
		statsText.color = FlxColor.WHITE;
		setStars(st[3]);
		var bestAll:Dynamic = FlxG.save.data.fohBestDiff;
		var bestHere:Null<Int> = bestAll != null ? Reflect.field(bestAll, songLowercase) : null;
		var clears:Dynamic = FlxG.save.data.fohClears;
		var rank:String = clears != null ? Reflect.field(clears, poop) : null;
		clearBadge.text = switch (rank)
		{
			case 'SFC': '★ PERFECT FULL COMBO';
			case 'GFC': '★ GREAT FULL COMBO';
			case 'FC': '★ FULL COMBO';
			case 'SDCB': 'Пройдено (меньше 10 промахов)';
			case 'Clear': 'Пройдено';
			default: 'На этой сложности ещё не пройдено';
		};
		if (bestHere != null) clearBadge.text += '\nЛучшее: ' + Difficulty.list[Std.int(Math.min(bestHere, Difficulty.list.length - 1))].toUpperCase();
		clearBadge.color = switch (rank) { case 'SFC': 0xFFFFE27A; case 'GFC': 0xFF7DF9FF; case 'FC': 0xFFC77DFF; case null: 0xFF6E6690; default: 0xFFCFC6F2; };
		clearBadge.alpha = 1;
	}

	static function starColor(v:Float):FlxColor
		return v < 2.5 ? 0xFF7DF9B0 : v < 4.5 ? 0xFFFFE27A : v < 6.5 ? 0xFFFFA24A : v < 8.5 ? 0xFFFF5A6E : 0xFFC77DFF;

	function setStars(v:Float)
	{
		starValue = v;
		var c = starColor(v);
		var full = Std.int(Math.min(10, Math.floor(v)));
		var frac = v - Math.floor(v);
		for (i in 0...10)
		{
			var b = starBase[i];
			b.scale.set(1, 1);
			if (i < full) { b.color = c; b.alpha = 1; }
			else if (i == full && v < 10) { b.color = c; b.alpha = 1; b.scale.set(0.45 + 0.55 * frac, 0.45 + 0.55 * frac); }
			else { b.color = 0xFF3A3358; b.alpha = 0.6; }
		}
		// above 10: extra stars stack on top of the row and burn
		var over = v - 10;
		for (i in 0...10)
		{
			var t = starTop[i];
			t.visible = over > 0 && i < Math.ceil(over);
			t.alpha = (i < Math.floor(over)) ? 1 : 0.55;
		}
		starNum.text = (Math.round(v * 10) / 10) + '*';
		starNum.color = c;
	}

	/** 100% = every song cleared on Hard or above (any accuracy). Normal gives half credit. */
	function updateProgress()
	{
		var best:Dynamic = FlxG.save.data.fohBestDiff;
		var pts = 0.0;
		var seen:Array<String> = [];
		for (i in 0...songs.length)
		{
			var id = Paths.formatToSongPath(songs[i].songName);
			if (seen.contains(id)) continue;
			seen.push(id);
			var b:Null<Int> = best != null ? Reflect.field(best, id) : null;
			var item = grpSongs.members[i];
			if (b == null) { item.color = FlxColor.WHITE; continue; }
			if (b >= 2) { pts += 1; item.color = 0xFFFFE27A; }      // Hard+ : gold
			else if (b >= 1) { pts += 0.5; item.color = 0xFF9CF7C4; } // Normal : green
			else { pts += 0.25; item.color = 0xFFCFE8FF; }           // Easy : pale
		}
		var pct = seen.length > 0 ? Math.floor(pts / seen.length * 100) : 0;
		FlxG.save.data.fohProgress = pct;
		progressText.text = 'Прогресс игры: ' + pct + '%' + (pct >= 100 ? '  ★ ПРОЙДЕНО!' : '');
	}

	function animateStars(elapsed:Float)
	{
		if (clearBadge != null && clearBadge.text.indexOf('FULL COMBO') > -1)
			clearBadge.alpha = 0.75 + 0.25 * Math.sin(FlxG.game.ticks / 180);
		if (starValue < 10) return;
		var tm:Float = FlxG.game.ticks / 1000;
		for (i in 0...10)
		{
			// base row shimmers
			var b = starBase[i];
			var k = 0.5 + 0.5 * Math.sin(tm * 5 + i * 0.6);
			b.color = FlxColor.interpolate(0xFFC77DFF, 0xFFFF9BF0, k);
			var t = starTop[i];
			if (!t.visible) continue;
			var f = 0.5 + 0.5 * Math.sin(tm * 9 + i * 1.3);
			t.color = FlxColor.interpolate(0xFFFF4A1C, 0xFFFFE27A, f);
			var sc = 0.7 + 0.15 * f;
			t.scale.set(sc, sc);
			t.offset.set(0, 6 + 3 * f);
		}
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}