package states;

import backend.FohUpdater;

/** Field of Hopes — download the latest build from inside the game */
class FohUpdateState extends MusicBeatState
{
	var title:FlxText;
	var info:FlxText;
	var hint:FlxText;
	var barBG:FlxSprite;
	var bar:FlxSprite;

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
		shade.alpha = 0.7;
		add(shade);

		title = new FlxText(40, 60, FlxG.width - 80, 'ОБНОВЛЕНИЕ ИГРЫ', 32);
		title.setFormat(font, 32, 0xFFFFCF5A, CENTER, FlxTextBorderStyle.SHADOW, 0xFF7A5CC4);
		title.borderSize = 4;
		add(title);

		info = new FlxText(80, 200, FlxG.width - 160, '', 18);
		info.setFormat(font, 18, FlxColor.WHITE, CENTER);
		MainMenuState.leading(info, 8);
		add(info);

		barBG = new FlxSprite(160, 420).makeGraphic(FlxG.width - 320, 28, 0xFF0B0614);
		add(barBG);
		bar = new FlxSprite(164, 424).makeGraphic(FlxG.width - 328, 20, 0xFFFFCF5A);
		bar.origin.x = 0;
		bar.scale.x = 0;
		add(bar);

		hint = new FlxText(40, FlxG.height - 100, FlxG.width - 80, '', 14);
		hint.setFormat(font, 14, 0xFFCFC6F2, CENTER);
		add(hint);

		if (FohUpdater.state == 'available') FohUpdater.scan();
		else if (FohUpdater.state != 'ready' && FohUpdater.state != 'downloading' && FohUpdater.state != 'done') FohUpdater.check();
	}

	static function mb(b:Float):String
		return Std.string(Math.round(b / 1048576 * 10) / 10) + ' МБ';

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var s = FohUpdater.state;
		bar.visible = barBG.visible = (s == 'downloading' || s == 'done');
		switch (s)
		{
			case 'checking':
				info.text = 'Проверяю, есть ли новая версия...';
				hint.text = 'ESC — назад';
			case 'available':
				FohUpdater.scan();
			case 'scanning':
				info.text = 'Сравниваю файлы с новой версией...\n' + FohUpdater.current;
				hint.text = 'ESC — назад';
			case 'none':
				info.text = 'У вас последняя версия (сборка ' + FohUpdater.localBuild + ').';
				hint.text = 'ESC — назад';
			case 'ready':
				if (FohUpdater.fileCount == 0)
					info.text = 'Все файлы уже свежие.\nENTER — перезапустить игру на новой версии';
				else
					info.text = 'Новая версия: сборка ' + FohUpdater.remoteBuild + '  (у вас: ' + (FohUpdater.localBuild > 0 ? Std.string(FohUpdater.localBuild) : '?') + ')\n\n'
						+ 'Нужно скачать: ' + FohUpdater.fileCount + ' файл(ов), ' + mb(FohUpdater.totalBytes);
				hint.text = 'ENTER — скачать и установить     ESC — позже';
			case 'downloading':
				var k = FohUpdater.totalBytes > 0 ? FohUpdater.doneBytes / FohUpdater.totalBytes : 0;
				bar.scale.x = k;
				info.text = 'Скачиваю... ' + FohUpdater.filesDone + ' / ' + FohUpdater.fileCount + '   ' + mb(FohUpdater.doneBytes) + ' из ' + mb(FohUpdater.totalBytes)
					+ '\n\n' + FohUpdater.current;
				hint.text = 'Не закрывайте игру';
			case 'done':
				bar.scale.x = 1;
				info.text = 'Готово! Обновление установлено.';
				hint.text = 'ENTER — перезапустить игру';
			case 'error':
				info.text = 'Не получилось обновиться:\n' + FohUpdater.error + '\n\nПроверьте интернет и попробуйте ещё раз.';
				hint.text = 'R — повторить     ESC — назад';
			default:
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			if (s == 'ready' && FohUpdater.fileCount > 0)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				if (FlxG.sound.music != null) FlxG.sound.music.stop();
				FohUpdater.download();
			}
			else if (s == 'done' || (s == 'ready' && FohUpdater.fileCount == 0))
				FohUpdater.restart();
		}
		if (FlxG.keys.justPressed.R && s == 'error')
		{
			FohUpdater.state = 'idle';
			FohUpdater.check();
		}
		if (FlxG.keys.justPressed.ESCAPE && s != 'downloading')
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if (s == 'done') FohUpdater.restart();
			if (FlxG.sound.music == null || !FlxG.sound.music.playing) FlxG.sound.playMusic(Paths.music('freakyMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
	}
}
