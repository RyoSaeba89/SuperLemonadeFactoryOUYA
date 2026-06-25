package
{
	import org.flixel.*;
	import io.arkeus.ouya.ControllerInput;

	//WINNITRON : 
	//[SWF(width="1024", height="768", backgroundColor="#000000")]
	
	//PC Version:
	//[SWF(width = "1024", height = "780", backgroundColor = "#d3bdb2")]
	
	// Ouya
	[SWF(width = "1920", height = "1080", backgroundColor = "#d3bdb2")]
	

	[Frame(factoryClass = "Preloader")]


	public class SLF extends FlxGame
	{
		public function SLF()
		{
			// Create GameInput as early as possible (the [Frame] preloader that normally
			// does this does not run in the AIR/mxmlc build). On OUYA firmware, GameInput's
			// DEVICE_ADDED only fires for a pad that connects AFTER GameInput exists, so it
			// must be created before the controller finishes enumerating — hence here, at
			// the very entry point, not later in a game state. stage is null this early,
			// which is fine: initialize() only needs it for (optional) stage listeners.
			ControllerInput.initialize(null);


			//WINNITRON
			//super(512, 384, WinniMenuState, 2, 60, 30);
			//Registry.isPCVersion = false;
			//Registry.isWinnitron = true;		
			
			//PC Version:
			//super(520, 390, LicenseKeyState, 2, 60, 30);
			
			// RIGHT ONE
			super(640, 360, PCIntroState, 3, 60, 30);
			
			FlxG.debug = forceDebugger = false;
			
			
			
			
			//
			
			
			
			
			
			//super(520, 390, offsetTest, 2, 60, 30);
			
			//FlxG.flashFramerate = 60;
			//FlxG.framerate = 60;
			
			//super(520, 390, SpeechBubbleTest, 2, 60, 30);
			
			Registry.isPCVersion = true;
			Registry.isWinnitron = false;
			
			
			
			// IAP removed for OUYA build: ship the full game unlocked (no in-app purchase)
			Registry.DEMO = false;
			
			
			//forceDebugger = false;
			
			
			

			
			
			
			
			FlxG.usingJoystick = false;
						
			//trace(ControllerInput.hasReadyController().toString() + " <-- controller.ready?");

		}
	}
}
