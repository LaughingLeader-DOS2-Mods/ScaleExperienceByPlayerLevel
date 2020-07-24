package
{
	import LS_Classes.larTween;
	import LS_Classes.listDisplay;
	import LS_Classes.scrollList;
	import LS_Classes.textEffect;
	import fl.motion.easing.Sine;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
   
	public dynamic class overview_mc_1 extends MovieClip
	{
		public var closeButtonMC:MovieClip;
		public var titleText:TextField;
		public var closeTimeLine:larTween;
		public var controlsList:scrollList;

		public var opened:Boolean;
		
		public var Root;
		
		public var selectedID:Number;
		
		public var totalHeight:Number;
		
		public var maxWidth:Number;


		public var HLCounter:Number;
		
		public const elementX:Number = 0;
		
		public const WidthSpacing:Number = 80;
		
		public const HeightSpacing:Number = 40;
		
		public var elementHSpacing:Number;
		
		public var minWidth:Number;
		
		public function SettingsWindow()
		{
			super();
			addFrameScript(0,this.frame1);
		}
		
		public function setCanScroll(enabled:Boolean) : *
		{
			this.controlsList.mouseWheelEnabled = enabled;
		}

		public function openMenu() : *
		{
			ExternalInterface.call("soundEvent","UI_Generic_Open");
			this.closeTimeLine = new larTween(this,"alpha",Sine.easeOut,NaN,1,0.3);
		}
		
		public function closeMenu() : *
		{
			ExternalInterface.call("PlaySound","UI_Gen_Back");
			this.closeTimeLine = new larTween(this,"alpha",Sine.easeIn,NaN,0,0.2,this.destroyMenu);
		}
		
		public function destroyMenu() : *
		{
			ExternalInterface.call("requestCloseUI");
		}

		public function setFormat(txt:TextField, size:Number = 16)
		{
			txt.defaultTextFormat.size = size;
			txt.defaultTextFormat.color = 0xFFFFFF;
			txt.defaultTextFormat.font = "Ubuntu Mono";
			txt.setTextFormat(txt.defaultTextFormat, 0, txt.htmlText.length);
		}
		
		public function setTitle(text:String) : *
		{
			setFormat(this.titleText, 22);
			this.titleText.htmlText = text.toUpperCase();
		}
		
		public function addMenuCheckbox(id:Number, labelText:String, isEnabled:Boolean, state:Number, filterEnabled:Boolean, tooltip:String) : *
		{
			var checkbox:MovieClip = new Checkbox();
			checkbox.x = this.elementX;
			checkbox.label_txt.htmlText = labelText;
			setFormat(checkbox.label_txt, 16);
			checkbox.id = id;
			checkbox.name = "item" + this.controlsList.length + "_mc";
			checkbox.mHeight = 30;
			checkbox.filterBool = filterEnabled;
			checkbox.stateID = state;
			checkbox.tooltip = tooltip;
			checkbox.bg_mc.gotoAndStop(state * 3 + 1);
			this.totalHeight = this.totalHeight + (checkbox.mHeight + this.elementHSpacing);
			if(checkbox.label_txt.textWidth > this.minWidth)
			{
				if(this.maxWidth < checkbox.label_txt.textWidth)
				{
					this.maxWidth = checkbox.label_txt.textWidth;
				}
			}
			else
			{
				this.maxWidth = this.minWidth;
			}
			checkbox.enable = isEnabled;
			if(isEnabled == false)
			{
				checkbox.alpha = 0.3;
			}
			this.controlsList.addElement(checkbox);
			checkbox.formHL_mc.alpha = 0;
			this.HLCounter = this.HLCounter + 1;
		}
		
		public function setMenuCheckbox(id:Number, enabled:Boolean, state:Number) : *
		{
			var menu:MovieClip = this.getElementByID(id);
			if(menu)
			{
				menu.enable = enabled;
				if(enabled == false)
				{
					menu.alpha = 0.3;
				}
				else
				{
					menu.alpha = 1;
				}
				menu.setState(state);
			}
		}

		public function getElementByID(id:Number) : MovieClip
		{
			return this.controlsList.getElementByNumber("id",id);
		}

		public function removeItems() : *
		{
			this.controlsList.clearElements();
			this.totalHeight = 0;
			this.maxWidth = 0;
		}
		
		function frame1() : *
		{
			this.titleText.filters = textEffect.createStrokeFilter(0,2,0.75,1.4,3);
			this.opened = false;
			this.totalHeight = 0;
			this.maxWidth = 0;
			this.controlsList = new scrollList("down_id","up_id","handle_id","scrollBg_id");
			this.controlsList.m_forceDepthReorder = true;
			this.controlsList.TOP_SPACING = 20;
			this.controlsList.EL_SPACING = 2;
			this.controlsList.setFrame(900,791);
			this.controlsList.m_scrollbar_mc.m_SCROLLSPEED = 40;
			this.controlsList.m_scrollbar_mc.m_hideWhenDisabled = false;
			this.controlsList.m_scrollbar_mc.y = 16;
			this.controlsList.SB_SPACING = -3;
			this.controlsList.m_scrollbar_mc.setLength(682);
			this.HLCounter = 0;
			this.addChild(this.list);

			this.elementHSpacing = 10;
			this.minWidth = 400;
		}
	}
}