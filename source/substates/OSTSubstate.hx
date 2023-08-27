package substates;

import flash.geom.Rectangle;
import tjson.TJSON as Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import flixel.addons.transition.FlxTransitionableState;

import backend.Song;
import backend.Section;
import backend.StageData;


import objects.AttachedSprite;
import substates.Prompt;

#if sys
import flash.media.Sound;
import sys.io.File;
import sys.FileSystem;
#end

#if android
import android.flixel.FlxButton;
#else
import flixel.ui.FlxButton;
#end

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)



class OSTSubstate extends MusicBeatSubstate
{
    var waveformVoiceSprite:FlxSprite;
    public static var waveFormMainSprite:FlxSprite;
    var logoBl:FlxSprite;
    var flashSpr2:FlxSprite;
    public static var flashGFX2:Graphics;
    var bpm:Float = 0;
    public static var vocals:FlxSound;
    var songVoice:Bool = false;
	public function new(needVoices:Bool,songBpm:Float)
	{
		super();		
		
		bpm = songBpm;		
		
		songVoice = needVoices;
		
		if (needVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();
		
		FlxG.sound.list.add(vocals);
		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
		vocals.play();
		vocals.persist = true;
		vocals.looped = true;
		vocals.volume = 0.7;		
		
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(0,0);
		bg.setGraphicSize(Std.int(bg.width));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		
		logoBl = new FlxSprite(0, 0);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.centerOrigin();
		logoBl.scale.x = 0.5;
		logoBl.scale.y = 0.5;
		logoBl.updateHitbox();
		add(logoBl);
		logoBl.x = 320 - logoBl.width / 2 - logoBl.offset.x /2;
		logoBl.y = 360 - logoBl.height / 2 - logoBl.offset.y / 2;
		
		waveformVoiceSprite = new FlxSprite(1280 - 400 - 50, 50).makeGraphic(400, 100, 0xFF000000);
		waveformVoiceSprite.alpha = 0.5;
		add(waveformVoiceSprite);
				
		waveFormMainSprite = new FlxSprite(1280 - 400 - 50, 50 + 200).makeGraphic(400, 100, 0xFF000000);
		waveFormMainSprite.alpha = 0.5;
		add(waveFormMainSprite);
		
		flashGFX2 = flashSpr2.graphics;
		
	
	    
	}
    
    var SoundTime:Float = 0;
	var BeatTime:Float = 0;
	
	var canBeat:Bool = true;
	override function update(elapsed:Float)
	{
		
		
		flashGFX2.clear(); flashGFX2.beginFill(0xFFFFFF, 1);
		
		updateVoiceWaveform();		
		updateMainWaveform();
		
		SoundTime = FlxG.sound.music.time / 1000;
        BeatTime = 60 / bpm;
        
        if ( Math.floor(SoundTime/BeatTime) % 4  == 0 && canBeat){       

            canBeat = false;
            
            logoBl.animation.play('bump');
        }
		
		if ( Math.floor(SoundTime/BeatTime + 0.5) % 4  == 2) canBeat = true;   
		
		if(FlxG.keys.justPressed.ESCAPE #if android || FlxG.android.justReleased.BACK #end)
		{
		    FlxG.sound.music.volume = 0;
		    destroyVocals();
		
		    FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);		
		    
			#if android
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
			#else
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			#end
		}
		
		super.update(elapsed);
	}
	


	function updateVoiceWaveform() {
	
	    var flashGFX = FlxSpriteUtil.flashGfx;
		
		var _rect = new Rectangle(0, 0, 400, 100);
		//var _temprect = new Rectangle(0, 0, 0, 0);
		var midx = 100 / 2;
	
	    waveformVoiceSprite.pixels.lock();
		waveformVoiceSprite.pixels.fillRect(_rect, 0xFF000000);

		FlxSpriteUtil.beginDraw(0xFFFFFFFF);
		
		
		var snd = FlxG.sound.music;

		var currentTime = snd.time;
		
		var buffer = snd._sound.__buffer;
		var bytes = buffer.data.buffer;
		
		var length = bytes.length - 1;
		var khz = (buffer.sampleRate / 1000);
		var channels = buffer.channels;
		var stereo = channels > 1;
		
		var index = Math.floor(currentTime * khz);
		var samples = 720;//Math.floor((currentTime + (((60 / Conductor.bpm) * 1000 / 4) * 16)) * khz - index);
		var samplesPerRow = samples / 720;

		var lmin:Float = 0;
		var lmax:Float = 0;
		
		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows = 0;
		var render = 0;
		var prevRows = 0;
		
		while (index < length) {
			if (index >= 0) {
				var byte = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (stereo) {
					var byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					var sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}
			
			if (rows - prevRows >= samplesPerRow) {
				prevRows = rows + ((rows - prevRows) - 1);
				
				flashGFX.drawRect(render, midx + (rmin * midx * 2), 1, (rmax - rmin) * midx * 2);
				//flashGFX.drawRect(midx + (rmin * midx * 2), render, (rmax - rmin) * midx * 2, 1);
				
				
				
				lmin = lmax = rmin = rmax = 0;
				render++;
			}
			
			index++;
			rows++;
			if (render > 400 - 1) break;
		}
		
		flashGFX.endFill(); 
		waveformVoiceSprite.pixels.draw(FlxSpriteUtil.flashGfxSprite);
		waveformVoiceSprite.pixels.unlock(); 
		
		return;
	}	
	
	public static function updateMainWaveform() {
	
	    var flashGFX = FlxSpriteUtil.flashGfx;
		
		var _rect = new Rectangle(0, 0, 400, 100);
		//var _temprect = new Rectangle(0, 0, 0, 0);
		var midx = 100 / 2;
	
	    waveFormMainSprite.pixels.lock();
		waveFormMainSprite.pixels.fillRect(_rect, 0xFF000000);

		FlxSpriteUtil.beginDraw(0xFFFFFFFF);
		
		
		var snd = FlxG.sound.music;

		var currentTime = snd.time;
		
		var buffer = snd._sound.__buffer;
		var bytes = buffer.data.buffer;
		
		var length = bytes.length - 1;
		var khz = (buffer.sampleRate / 1000);
		var channels = buffer.channels;
		var stereo = channels > 1;
		
		var index = Math.floor(currentTime * khz);
		var samples = 720;//Math.floor((currentTime + (((60 / Conductor.bpm) * 1000 / 4) * 16)) * khz - index);
		var samplesPerRow = samples / 720;

		var lmin:Float = 0;
		var lmax:Float = 0;
		
		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows = 0;
		var render = 0;
		var prevRows = 0;
		
		while (index < length) {
			if (index >= 0) {
				var byte = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (stereo) {
					var byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					var sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}
			
			if (rows - prevRows >= samplesPerRow) {
				prevRows = rows + ((rows - prevRows) - 1);
				
				flashGFX2.drawRect(render, 100, 1, -(rmax - rmin) * midx * 2);
				//flashGFX.drawRect(midx + (rmin * midx * 2), render, (rmax - rmin) * midx * 2, 1);
				
				
				
				lmin = lmax = rmin = rmax = 0;
				render++;
			}
			
			index++;
			rows++;
			if (render > 400 - 1) break;
		}
		
		flashGFX2.endFill(); 
		waveFormMainSprite.pixels.draw(flashSpr2);
		waveFormMainSprite.pixels.unlock(); 
		
		return;
	}	

	public static function destroyVocals() {
		if(vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}
}