package;

import flixel.math.FlxMath;
import modding.ModManagerState;
import modding.PolymodHandler;
import story.StoryMenuState;
import flixel.util.FlxTimer;
import flixel.system.debug.console.ConsoleUtil;
import flixel.math.FlxPoint;
import config.*;
import transition.data.*;
import title.TitleScreen;
import freeplay.FreeplayState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.text.FlxText;
import extensions.flixel.FlxTextExt;
import caching.*;

using StringTools;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

@:hscriptClass
class ScriptedMainMenuState extends MainMenuState implements polymod.hscript.HScriptedClass{}

class MainMenuState extends MusicBeatState
{

	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;

	inline public static final FUSION_VERSION:String = "0.0.0";
	inline public static final VERSION:String = "7.0.2 (kinda)";
	inline public static final NONFINAL_TAG:String = "(Non-Release Build)";
	inline public static final SHOW_BUILD_INFO:Bool = false; //Set this to false when making a release build.

	public static var buildDate:String = "";

	var magenta:FlxSprite;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var allowMouse:Bool = true; // Turn this off to block mouse movement in menus

	public static var optionShit:Array<String> = ['storymode', 'freeplay', 'mods', "credits"];
	public static var leftOption:String = null;
	public static var rightOption:String = 'options';

	var camFollow:FlxObject;
	var camTarget:FlxPoint = new FlxPoint();
	var instantCamFollow:Bool = false;

	final warningDelay:Float = 10;
	var keyWarning:FlxTextExt;
	var canCancelWarning:Bool = true;

	public static var fromFreeplay:Bool = false;
	public static final lerpSpeed:Float = 0.085;

	override function create() {

		Config.setFramerate(144);

		if (!FlxG.sound.music.playing) FlxG.sound.playMusic(Paths.music(TitleScreen.titleMusic), TitleScreen.titleMusicVolume);

		persistentUpdate = persistentDraw = true;

		if(fromFreeplay) {
			fromFreeplay = false;
			customTransIn = new InstantTransition();
		}

		//------------------Assets------------------
		var bg:FlxSprite = MainMenuState.createMenuBG("");
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = MainMenuState.createMenuBG("Magenta");
		magenta.visible = false;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var id:Int = -1;
		for (num => option in MainMenuState.optionShit) {
			id += 1;
			var item:FlxSprite = MainMenuState.createMenuItem(option, 0, (num * 140) + 90, menuItems, id);
			item.y += (4 - optionShit.length) * 70; // Offsets for when you have anything other than 4 items
			item.screenCenter(X);
		}

		if (MainMenuState.leftOption != null) {
			id += 1;
			leftItem = MainMenuState.createMenuItem(leftOption, 60, 350, menuItems, id);
		}

		if (MainMenuState.rightOption != null) {
			id += 1;
			rightItem = MainMenuState.createMenuItem(MainMenuState.rightOption, FlxG.width - 60, 350, menuItems, id);
			rightItem.x -= rightItem.width;
		}

		FlxG.camera.follow(camFollow);

		var texts:FlxTypedGroup<FlxTextExt> = new FlxTypedGroup<FlxTextExt>();
		add(texts);

		MainMenuState.createMenuTexts(texts);

		/*keyWarning = new FlxTextExt(5, FlxG.height - 21 + 16, 0, "If your controls aren't working, try pressing CTRL + BACKSPACE to reset them.", 16);
		keyWarning.scrollFactor.set();
		keyWarning.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		keyWarning.alpha = 0;
		add(keyWarning);

		FlxTween.tween(versionText, {y: versionText.y - 16}, 0.75, {ease: FlxEase.quintOut, startDelay: warningDelay});
		FlxTween.tween(keyWarning, {alpha: 1, y: keyWarning.y - 16}, 0.75, {ease: FlxEase.quintOut, startDelay: warningDelay});

		new FlxTimer().start(warningDelay, function(t){
			canCancelWarning = false;
		});*/


		instantCamFollow = true;
		//FlxG.camera.follow(camFollow, null, 0.15);

		changeItem();
		Config.reload();

		super.create();
	}

	//------------------------------------ CREATE FUNCTIONS ------------------------------------

	public static function createMenuBG(suffix:String):FlxSprite {
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menu/menuBG$suffix'));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.setGraphicSize(Std.int(bg.width * 1.18));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		return bg;
	}

	public static function createMenuItem(name:String, x:Float, y:Float, group:FlxTypedGroup<FlxSprite>, id:Int):FlxSprite {
		var menuItem:FlxSprite = new FlxSprite(x, y);

		menuItem.frames = Paths.getSparrowAtlas('menu/main/$name');
		menuItem.animation.addByPrefix('idle', 'idle', 24, true);
		menuItem.animation.addByPrefix('selected', 'selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();

		menuItem.antialiasing = true;

		menuItem.scrollFactor.set();
		menuItem.ID = id;
		group.add(menuItem);
		return menuItem;
	}

	public static function createMenuTexts(group:FlxTypedGroup<FlxTextExt>) {
		var versionText = new FlxTextExt(5, FlxG.height - 21, 0, "FPS Plus: v" + VERSION + " | Mod API: v" + PolymodHandler.API_VERSION_STRING, 16);
		versionText.scrollFactor.set();
		versionText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		if(SHOW_BUILD_INFO) {
			versionText.text = "FPS Plus: v" + VERSION + " " + NONFINAL_TAG + " | Mod API: v" + PolymodHandler.API_VERSION_STRING;

			buildDate = CompileTime.buildDateString();

			var buildInfoText = new FlxTextExt(1280 - 5, FlxG.height - 37, 0, "Build Date: " + buildDate + "\n" + GitCommit.getGitBranch() +  " (" + GitCommit.getGitCommitHash() + ")", 16);
			buildInfoText.scrollFactor.set();
			buildInfoText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			buildInfoText.x -= buildInfoText.width;
			group.add(buildInfoText);
		}

		group.add(versionText);

		var fusionVersionText = new FlxTextExt(5, FlxG.height - 41, 0, "Fusionary Engine v" + FUSION_VERSION, 16);
		fusionVersionText.scrollFactor.set();
		fusionVersionText.setFormat("VCR OSD Mono", 16, 0xFF612B75, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		group.add(fusionVersionText);
	}

	//------------------------------------ FUNCTIONS ------------------------------------
	var selectedSomethin:Bool = false;
	override function update(elapsed:Float) {
/*
		if(canCancelWarning && (Binds.justPressed("menuUp") || Binds.justPressed("menuDown")) || Binds.justPressed("menuAccept")) {
			canCancelWarning = false;
			FlxTween.cancelTweensOf(versionText);
			FlxTween.cancelTweensOf(keyWarning);
		}*/
	
		if (!selectedSomethin) {
			if (Binds.justPressed("menuUp")) changeItem(-1);
			else if (Binds.justPressed("menuDown")) changeItem(1);

			var _allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) {
				_allowMouse = false;
				FlxG.mouse.visible = true;

				var selectedItem:FlxSprite;
				switch(curColumn) {
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem)) {
					_allowMouse = true;
					if(selectedItem != leftItem) {
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					_allowMouse = true;
					if(selectedItem != rightItem) {
						curColumn = RIGHT;
						changeItem();
					}
				} else {
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length) {
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb)) {
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist) {
								dist = distance;
								distItem = i;
								_allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem]) {
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}

			switch(curColumn) {
				case CENTER:
					if (Binds.justPressed("menuLeft") && leftOption != null) {
						curColumn = LEFT;
						changeItem();
					}
					else if (Binds.justPressed("menuRight") && rightOption != null) {
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if (Binds.justPressed("menuRight")) {
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if (Binds.justPressed("menuLeft")) {
						curColumn = CENTER;
						changeItem();
					}
			}

			/*/if (FlxG.keys.justPressed.BACKSPACE && FlxG.keys.pressed.CONTROL) {
				Binds.resetToDefaultControls();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
			else */
			if (Binds.justPressed("menuBack") && !FlxG.keys.pressed.CONTROL) {
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound("cancelMenu"));
				switchState(new TitleScreen());
			}

			if (Binds.justPressed("menuAccept") || (FlxG.mouse.justPressed && allowMouse)) {
				var daChoice:String;
				var item:FlxSprite;
				switch(curColumn) {
					case LEFT:
						daChoice = leftOption;
						item = leftItem;
					case RIGHT:
						daChoice = rightOption;
						item = rightItem;
					case CENTER:
						daChoice = optionShit[curSelected];
						item = menuItems.members[curSelected];
				}

				if(daChoice == 'freeplay') {
					selectedSomethin = true;
					customTransOut = new InstantTransition();
					FreeplayState.curSelected = 0;
					FreeplayState.curCategory = 0;
					ImageCache.keepCache = true;
					switchState(new FreeplayState(fromMainMenu, camFollow.getPosition()));
				} else {
					selectedSomethin = true;
					FlxG.mouse.visible = false;
					FlxG.sound.play(Paths.sound('confirmMenu'));

					switch (daChoice) {
						case 'options':
							if(!ConfigMenu.USE_MENU_MUSIC) FlxG.sound.music.stop();
							else ConfigMenu.startSong = false;
					}

					FlxFlicker.flicker(magenta, 1.1, 0.15, false);
					menuItems.forEach(function(spr:FlxSprite) {
						if (item != spr) {
							FlxTween.tween(spr, {alpha: 0}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween){
									spr.kill();
								}
							});
						} else {
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
								spr.visible = true;

								switch (daChoice) {
									case 'storymode':
										StoryMenuState.curWeek = 0;
										switchState(new StoryMenuState());
										trace("Story Menu Selected");
									/*case 'freeplay':
										FreeplayState.startingSelection = 0;
										FreeplayState.fromMainMenu = true;
										switchState(new FreeplayState());
										trace("Freeplay Menu Selected");*/
									case 'options':
										switchState(new ConfigMenu());
										trace("Options Selected");
									case 'mods':
										switchState(new ModManagerState(), false);
										trace("Mods Selected");
									default: // If the cur selected isn't here
										switchState(new MainMenuState(), false);
										FlxG.sound.play(Paths.sound('cancelMenu'));
										trace('No State for option: $daChoice');
								}	
							});
						}
					});
				}
			}
		}

		if(!instantCamFollow){
			camFollow.x = Utils.fpsAdjustedLerp(camFollow.x, camTarget.x, lerpSpeed, 144);
			camFollow.y = Utils.fpsAdjustedLerp(camFollow.y, camTarget.y, lerpSpeed, 144);
		} else {
			camFollow.x = camTarget.x;
			camFollow.y = camTarget.y;
			instantCamFollow = false;
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0) {
		if(change != 0) curColumn = CENTER;

		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems) {
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn) {
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camTarget.set(selectedItem.getGraphicMidpoint().x, selectedItem.getGraphicMidpoint().y);
		//camFollow.setPosition(selectedItem.getGraphicMidpoint().x, selectedItem.getGraphicMidpoint().y);
	}
}
