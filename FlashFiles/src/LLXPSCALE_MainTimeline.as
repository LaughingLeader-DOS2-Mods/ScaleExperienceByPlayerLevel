package
{
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;

	import LS_Classes.LSButton;
			
	public class MainTimeline extends MovieClip
	{
		public var settingsWindow:SettingsWindow;
		public var events: Array;
		public var layout: String = "fixed";
		public const anchorId:String = "LLXPSCALE_SettingsWindow";

		public var isUIMoving:Boolean;

		public function MainTimeline()
		{
			super();
			addFrameScript(0,this.frame1);
		}

		private function onEventResize(): * {}

		private function onEventInit(): * {
			ExternalInterface.call("registerAnchorId", anchorId);
			ExternalInterface.call("setPosition","center","screen","center");
			ExternalInterface.call("resized",this.settingsWindow.bg.width,this.settingsWindow.bg.height);
		}

		public function openMenu() : *
		{
			this.settingsWindow.openMenu();
		}

		public function closeMenu() : *
		{
			this.settingsWindow.closeMenu();
		}

		public function onEventDown(eventIndex:Number) : *
		{
			var handled:Boolean = false;
			if(this.settingsWindow.visible && stage.focus != null && this.events[eventIndex] != null)
			{
				stage.focus = null;
				closeMenu();
				handled = true;
			}
			return handled;
		}

		private function frame1() : *
		{
			this.events = new Array("IE ToggleInGameMenu", "IE UIAccept");
			this.layout = "fixed";
			this.isUIMoving = false;
		}
	}
}