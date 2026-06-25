package io.arkeus.ouya {
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.GameInputEvent;
	import flash.events.KeyboardEvent;
	import flash.ui.GameInput;
	import flash.ui.GameInputControl;
	import flash.ui.GameInputDevice;
	import flash.ui.Keyboard;

	import io.arkeus.ouya.controller.GameController;
	import io.arkeus.ouya.controller.OuyaController;
	import io.arkeus.ouya.controller.Xbox360Controller;

	import org.flixel.FlxG;

	/**
	 * A class for reading input from controllers. Allows you to pull ready controllers from a queue
	 * of controllers that have been initialized, to allow input from as many controllers as you need.
	 */
	public class ControllerInput {
		private static var controllers:Vector.<GameController> = new Vector.<GameController>;
		private static var readyControllers:Vector.<GameController> = new Vector.<GameController>;
		private static var removedControllers:Vector.<GameController> = new Vector.<GameController>;
		private static var gameInput:GameInput;

		public static var now:Number = 0;
		public static var previous:Number = now;

		/** True once GameInput has been created. Guards against double initialization. */
		public static var didInit:Boolean = false;
		/** True once the per-frame ENTER_FRAME / KEY_DOWN listeners are attached to a stage. */
		private static var stageHooked:Boolean = false;

		/**
		 * Initializes the library. Two independent, idempotent steps:
		 *
		 *  1. Create the GameInput object + device listeners. This MUST happen as early as
		 *     possible (called from the SLF constructor, stage still null) because on OUYA
		 *     firmware GameInput's DEVICE_ADDED only fires for a pad that connects AFTER
		 *     GameInput exists — a pad already on at launch is never reported if GameInput is
		 *     created late.
		 *  2. Attach the ENTER_FRAME / KEY_DOWN listeners to the stage. This needs a valid
		 *     stage and drives ControllerInput.now/previous, which the ButtonControl edge
		 *     detection (pressed/released) depends on. Call again once a stage is available
		 *     (from PCIntroState) to complete this step.
		 *
		 * Safe to call any number of times with or without a stage.
		 *
		 * @param stage The root stage, or null if not yet available.
		 */
		public static function initialize(stage:DisplayObject):void {
			if (!didInit) {
				// Safe non-null placeholder so per-frame FlxG.ouyaController.*.reset()/.pressed
				// never dereferences null before a real pad is attached (white-screen guard).
				if (FlxG.ouyaController == null) {
					FlxG.ouyaController = new OuyaController(null);
				}

				gameInput = new GameInput;
				gameInput.addEventListener(GameInputEvent.DEVICE_ADDED, onDeviceAttached);
				gameInput.addEventListener(GameInputEvent.DEVICE_REMOVED, onDeviceDetached);

				for (var i:uint = 0; i < GameInput.numDevices; i++) {
					attach(GameInput.getDeviceAt(i));
				}

				didInit = true;
			}

			if (stage != null && !stageHooked) {
				stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
				stageHooked = true;
			}
		}

		/**
		 * Returns the active controller with the passed index.
		 *
		 * @param index The index of the controller to grab.
		 * @return An active controller.
		 */
		public static function controller(index:uint):GameController {
			return controllers[index];
		}

		/**
		 * Returns whether or not there is a controller that is ready to be polled for input.
		 *
		 * @return Whether there is a ready controller or not.
		 */
		public static function hasReadyController():Boolean {
			return readyControllers.length > 0;
		}

		/**
		 * Returns a ready controller and activates it (allowing it to be polled for input). This moves the
		 * controller from the "ready controllers" queue to the list of active "controllers".
		 *
		 * @return The controller, now in a ready state.
		 */
		public static function getReadyController():GameController {
			var readyController:GameController = readyControllers.shift();
			readyController.enable();
			controllers.push(readyController);
			return readyController;
		}

		/**
		 * Returns whether or not one of the currently used controllers has been disconnected. You can check this
		 * queue in order to handle this case gracefully. Also, you can check if the "removed" property of the
		 * controller is true, which also signifies that the controller has been detached from the system and can
		 * no longer be read for input.
		 *
		 * @return Whether or not there is a detached controller.
		 */
		public static function hasRemovedController():Boolean {
			return removedControllers.length > 0;
		}

		/**
		 * Similar to reading a newly ready controller, this allows you to read a removed controller and handle it
		 * however you'd like.
		 *
		 * @return The removed controller.
		 */
		public static function getRemovedController():GameController {
			var removedController:GameController = removedControllers.shift();
			removedController.disable();
			return removedController;
		}

		/**
		 * Callback when a device is attached.
		 *
		 * @param event The GameInputEvent containing the attached deviced.
		 */
		private static function onDeviceAttached(event:GameInputEvent):void {
			attach(event.device);
		}

		/**
		 * Attaches a game device by creating a class that corresponds to the device type
		 * and adding it to the ready controllers list.
		 */
		private static function attach(device:GameInputDevice):void {
			if (device == null) {
				return;
			}
			var controllerClass:Class = parseControllerType(device.name);
			if (controllerClass == null) {
				// Unknown device
				return;
			}
			readyControllers.push(new controllerClass(device));
		}

		/**
		 * Callback when a device is detached.
		 *
		 * @param event The GameInputEvent containing the detached deviced.
		 */
		private static function onDeviceDetached(event:GameInputEvent):void {
			detach(event.device);
		}

		/**
		 * Detaches a device by setting the removed attribute to true, removing it from the controllers
		 * list, and adding to the removed controllers list.
		 */
		private static function detach(device:GameInputDevice):void {
			if (device == null) {
				return;
			}
			var detachedController:GameController = findAndRemoveDevice(controllers, device) || findAndRemoveDevice(readyControllers, device);
			if (detachedController == null) {
				return;
			}
			detachedController.remove();
			removedControllers.push(detachedController);
		}

		/**
		 * Helper method that takes a group and a target device, removes the device from the group
		 * and returns it. If the controller was not present in the group, returns null instead.
		 *
		 * @param source The group to remove the controller from.
		 * @param target The game input device to remove and return.
		 * @return The removed controller corresponding to the device, or null if it wasn't present.
		 */
		private static function findAndRemoveDevice(source:Vector.<GameController>, target:GameInputDevice):GameController {
			var result:GameController = null;
			for each (var controller:GameController in source) {
				if (controller.device == target) {
					result = controller;
					break;
				}
			}

			if (result != null) {
				source.splice(source.indexOf(result), 1);
				return result;
			}

			return null;
		}

		/**
		 * Sets up timers on enter frame in order to keep track of whether a button is pressed or held.
		 *
		 * @param event The enter frame event.
		 */
		private static function onEnterFrame(event:Event):void {
			// now/previous are advanced once per game-logic frame in FlxG.updateInput(),
			// not here at render rate (see comment there). Kept for the KEY_DOWN listener.
		}

		/**
		 * Given the name of a device, returns the supported class for that device. If the device isn't
		 * supported by AS3 Controller Input, returns null.
		 *
		 * @param name The name of the device.
		 * @return The controller class corresponding to the device name.
		 */
		private static function parseControllerType(name:String):Class {
			if (name.toLowerCase().indexOf("xbox 360") != -1) {
				return Xbox360Controller;
			} else if (name.toLowerCase().indexOf("ouya") != -1) {
				return OuyaController;
			}

			return null;
		}

		/**
		 * Callback for keyboard events that catches the back and escape keys such that stupid bindings
		 * don't exit the application.
		 *
		 * @param event The keyboard event.
		 */
		private static function onKeyDown(event:KeyboardEvent):void {
			if (event.keyCode == 27 || event.keyCode == Keyboard.BACK) {
				event.preventDefault();
			}
		}
	}
}
