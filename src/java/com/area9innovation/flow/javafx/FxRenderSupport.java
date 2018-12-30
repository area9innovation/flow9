package com.area9innovation.flow.javafx;

import java.util.*;
import com.area9innovation.flow.*;

import javafx.application.Application;
import javafx.event.ActionEvent;
import javafx.event.EventHandler;
import javafx.event.EventType;
import javafx.scene.Scene;
import javafx.scene.Group;
import javafx.scene.Parent;
import javafx.scene.Node;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.StackPane;
import javafx.scene.text.Text;
import javafx.scene.text.Font;
import javafx.scene.text.TextBoundsType;
import javafx.stage.Stage;
import javafx.scene.shape.*;
import javafx.scene.paint.Color;
import javafx.scene.transform.Rotate;
import javafx.scene.transform.Scale;
import javafx.scene.effect.BoxBlur;
import javafx.scene.effect.Effect;
import javafx.beans.value.ChangeListener;
import javafx.beans.value.ObservableValue;
import javafx.scene.input.MouseEvent;
import javafx.scene.input.KeyEvent;
import javafx.scene.input.KeyCode;
import javafx.geometry.Point2D;
import javafx.scene.Cursor;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.effect.DropShadow;
import javafx.scene.effect.BlurType;
import javafx.scene.paint.Paint;
import javafx.scene.paint.CycleMethod;
import javafx.scene.paint.Stop;
import javafx.scene.paint.LinearGradient;
import javafx.scene.paint.RadialGradient;

public class FxRenderSupport extends RenderSupport {
	private Application app_object;
	private Stage stage;
	private Scene scene;
	private Clip stage_clip;
	private int next_event_id = 0;
	private double mouse_x, mouse_y;
	private String cur_cursor = "";

	private SortedMap<Integer,Func0<Object>> event_resize = new TreeMap<Integer,Func0<Object>>();
	private SortedMap<Integer,Func0<Object>> event_mousemove = new TreeMap<Integer,Func0<Object>>();
	private SortedMap<Integer,Func0<Object>> event_mousedown = new TreeMap<Integer,Func0<Object>>();
	private SortedMap<Integer,Func0<Object>> event_mouseup = new TreeMap<Integer,Func0<Object>>();
	private SortedMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> event_keydown = new TreeMap<>();
	private SortedMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> event_keyup = new TreeMap<>();

	private Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	private <T> Func0<Object> addEvent(final SortedMap<Integer,T> map, T listener) {
		final int id = next_event_id++;
		map.put(id, listener);
		return new Func0<Object>() {
			public Object invoke() {
				map.remove(id);
				return null;
			}
		};
	}

	private static boolean checkNodeHit(Node node, double x, double y) {
		Point2D pos = node.sceneToLocal(x,y);
		if (pos == null) return false;
		else return node.intersects(pos.getX(), pos.getY(), 1, 1);
	}

	private class Clip {
		Group container, top;
		Clip parent, mask, mask_owner;
		List<Clip> children = new ArrayList<Clip>();
		Graphics graphics;
		Rotate rotation;
		Scale scaling;
		double x, y;

		SortedMap<Integer,Func0<Object>> event_mouseenter;
		SortedMap<Integer,Func0<Object>> event_mouseleave;

		public Clip() {
			container = top = new Group();
		}
		protected Parent makeObj() {
			return new Group();
		}
		public Parent getTop() {
			return top;
		}
		public void setMaskOwner(Clip owner) {
			if (owner.mask != null)
				owner.mask.mask_owner = null;
			owner.mask = this;
			this.mask_owner = owner;
			owner.getTop().setClip(getTop());
			if (parent != null)
				parent.container.getChildren().remove(getTop());
		}
		public void setParent(Clip new_parent) {
			setParentAt(new_parent, new_parent != null ? new_parent.children.size() : 0);
		}
		public void setParentAt(Clip new_parent, Integer at) {
			if (new_parent == parent)
				return;
			if (parent != null) {
				parent.children.remove(this);
				parent.container.getChildren().remove(getTop());
			}
			parent = new_parent;
			if (parent != null) {
				parent.children.add(at, this);
				if (mask_owner == null)
					parent.container.getChildren().add(getTop());
			}
		}
		public Graphics getGraphics() {
			if (graphics == null)
				graphics = new Graphics(this);
			return graphics;
		}
		public boolean hittest(double x, double y) {
			if (graphics != null && graphics.hittest(x, y))
				return true;
			for (Clip child : children)
				if (child.hittest(x,y))
					return true;
			return false;
		}
	}

	@SuppressWarnings("unchecked")
	private static Func0<Object>[] event_cb_arr = new Func0[0];

	FxRenderSupport(Application app, Stage stage) {
		this.app_object = app;
		this.stage = stage;

		stage_clip = new Clip();
		scene = new Scene(stage_clip.getTop(), 640, 480);
		stage.setScene(scene);
		stage.show();

		ChangeListener<Number> resize_cb = new ChangeListener<Number>() {
			public void changed(ObservableValue<? extends Number> observable, Number oldValue, Number newValue) {
				for (Func0<Object> cb : event_resize.values().toArray(event_cb_arr))
					cb.invoke();
			}
		};

		stage.widthProperty().addListener(resize_cb);
		stage.heightProperty().addListener(resize_cb);

		EventHandler<MouseEvent> move_cb = new EventHandler<MouseEvent>() {
			@Override public void handle(MouseEvent event) {
			//	System.out.print(".");
				mouse_x = event.getSceneX();
				mouse_y = event.getSceneY();
				for (Func0<Object> cb : event_mousemove.values().toArray(event_cb_arr))
					cb.invoke();
			}
		};

		stage.addEventFilter(MouseEvent.MOUSE_MOVED, move_cb);
		stage.addEventFilter(MouseEvent.MOUSE_DRAGGED, move_cb);
		stage.addEventHandler(MouseEvent.MOUSE_PRESSED, new EventHandler<MouseEvent>() {
			@Override public void handle(MouseEvent event) {
				event.consume();
				mouse_x = event.getSceneX();
				mouse_y = event.getSceneY();
				for (Func0<Object> cb : event_mousedown.values().toArray(event_cb_arr))
					cb.invoke();
			}
		});
		stage.addEventHandler(MouseEvent.MOUSE_RELEASED, new EventHandler<MouseEvent>() {
			@Override public void handle(MouseEvent event) {
				mouse_x = event.getSceneX();
				mouse_y = event.getSceneY();
				for (Func0<Object> cb : event_mouseup.values().toArray(event_cb_arr))
					cb.invoke();
			}
		});

		EventHandler<KeyEvent> keyEventHandler = new EventHandler<KeyEvent>() {
			@Override public void handle(KeyEvent event) {
				handleKeyEvent(event);
			}
		};

		scene.setOnKeyPressed(keyEventHandler);
		scene.setOnKeyReleased(keyEventHandler);
	}

	private void handleKeyEvent(KeyEvent event) {
		SortedMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> handler_map;
		KeyCode[] codes = KeyCode.values();

		EventType<KeyEvent> type = event.getEventType();
		if (type == KeyEvent.KEY_PRESSED) {
			handler_map = event_keydown;
		} else {
			handler_map = event_keyup;
		}

		String text = event.getText().length() != 0 ? event.getText() : event.getCode().getName();
		Boolean isCtrl = event.isControlDown();
		Boolean isShift = event.isShiftDown();
		Boolean isAlt = event.isAltDown();
		Boolean isMeta = event.isMetaDown();
		Integer code = parseKeyCode(event.getCode());

		if (System.getProperty("os.name").equals("Mac OS X")) {
			boolean buf = isCtrl;
			isCtrl = isMeta;
			isMeta = buf;
		}

		for (Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> cb : handler_map.values())
			cb.invoke(text, isCtrl, isShift, isAlt, isMeta, code, no_op);
	}

	private Integer parseKeyCode(KeyCode keyCode) {
		Integer code = 0;
		switch(keyCode) {
			case BACK_SPACE: code = 8; break;
			case TAB: code = 9; break;
			case ENTER: code = 13; break;
			case SHIFT: code = 16; break;
			case CONTROL: code = 17; break;
			case ALT: code = 18; break;
			case PAUSE: code = 19; break;
			case CAPS: code = 20; break;
			case CANCEL: code = 24; break;
			case ESCAPE: code = 27; break;
			case PAGE_UP: code = 33; break;
			case PAGE_DOWN: code = 34; break;
			case END: code = 35; break;
			case HOME: code = 36; break;
			case LEFT: code = 37; break;
			case UP: code = 38; break;
			case RIGHT: code = 39; break;
			case DOWN: code = 40; break;
			case INSERT: code = 45; break;
			case DELETE: code = 46; break;
			case DIGIT0: code = 48; break;
			case DIGIT1: code = 49; break;
			case DIGIT2: code = 50; break;
			case DIGIT3: code = 51; break;
			case DIGIT4: code = 52; break;
			case DIGIT5: code = 53; break;
			case DIGIT6: code = 54; break;
			case DIGIT7: code = 55; break;
			case DIGIT8: code = 56; break;
			case DIGIT9: code = 57; break;
			case A: code = 65; break;
			case B: code = 66; break;
			case C: code = 67; break;
			case D: code = 68; break;
			case E: code = 69; break;
			case F: code = 70; break;
			case G: code = 71; break;
			case H: code = 72; break;
			case I: code = 73; break;
			case J: code = 74; break;
			case K: code = 75; break;
			case L: code = 76; break;
			case M: code = 77; break;
			case N: code = 78; break;
			case O: code = 79; break;
			case P: code = 80; break;
			case Q: code = 81; break;
			case R: code = 82; break;
			case S: code = 83; break;
			case T: code = 84; break;
			case U: code = 85; break;
			case V: code = 86; break;
			case W: code = 87; break;
			case X: code = 88; break;
			case Y: code = 89; break;
			case Z: code = 90; break;
			case WINDOWS: code = 91; break;
			case COMMAND: code = 91; break;
			case NUMPAD0: code = 96; break;
			case NUMPAD1: code = 97; break;
			case NUMPAD2: code = 98; break;
			case NUMPAD3: code = 99; break;
			case NUMPAD4: code = 100; break;
			case NUMPAD5: code = 101; break;
			case NUMPAD6: code = 102; break;
			case NUMPAD7: code = 103; break;
			case NUMPAD8: code = 104; break;
			case NUMPAD9: code = 105; break;
			case MULTIPLY: code = 106; break;
			case ADD: code = 107; break;
			case MINUS: code = 109; break;
			case DECIMAL: code = 110; break;
			case DIVIDE: code = 111; break;
			case F1: code = 112; break;
			case F2: code = 113; break;
			case F3: code = 114; break;
			case F4: code = 115; break;
			case F5: code = 116; break;
			case F6: code = 117; break;
			case F7: code = 118; break;
			case F8: code = 119; break;
			case F9: code = 120; break;
			case F10: code = 121; break;
			case F11: code = 122; break;
			case F12: code = 123; break;
			case NUM_LOCK: code = 144; break;
			case SCROLL_LOCK: code = 145; break;
			case SEMICOLON: code = 186; break;
			case EQUALS: code = 187; break;
			case COMMA: code = 188; break;
			case PERIOD: code = 190; break;
			case SLASH: code = 191; break;
			case BACK_QUOTE: code = 192; break;
			case OPEN_BRACKET: code = 219; break;
			case BACK_SLASH: code = 220; break;
			case CLOSE_BRACKET: code = 221; break;
			case QUOTE: code = 222; break;
			default: code = 0;
		};

		return code;
	}

	@Override
	public Object getStage() {
		return stage_clip;
	}
	@Override
	public double getStageWidth() {
		return stage.getWidth();
	}
	@Override
	public double getStageHeight() {
		return stage.getHeight();
	}
	@Override
	public Object setHitboxRadius(double val) {
		return null;
	}
	@Override
	public Object setWindowTitle(String title) {
		stage.setTitle(title);
		return null;
	}
	@Override
	public Object setFavIcon(String url) {
		return null;
	}
	@Override
	public Object enableResize() {
		// We always allow resizing, so let's just ignore this
		// System.out.println("enableResize not implemented");
		return null;
	}
	@Override
	public Object makeClip() {
		return new Clip();
	}
	@Override
	public Object makeGraphics() {
		return new Clip();
	}
	@Override
	public Object currentClip() {
		return stage_clip;
	}
	@Override
	public Object makeWebClip(String url,String domain,Boolean useCache, Boolean reloadBlock, Func1<String,Object[]> cb, Func1<Object,String> ondone, Boolean shrinkToFit) {
		System.out.println("makeWebClip not implemented");
		return new Clip();
	}
	@Override
	public String webClipHostCall(Object clip,String fn,Object[] args) {
		System.out.println("webClipHostCall not implemented");
		return null;
	}
	@Override
	public Object setWebClipZoomable(Object clip,Boolean zoomable) {
		System.out.println("setWebClipZoomable not implemented");
		return null;
	}
	@Override
	public Object setWebClipDomains(Object clip,Object[] domains) {
		return null;
	}
	@Override
	public Object addFilters(Object stg, Object[] filters) {
		Clip cl = (Clip)stg;
		for (int i = 0; i < filters.length; i++)
			if (filters[i] != null)
				cl.getTop().setEffect((Effect)filters[i]);
		return null;
	}
	@Override
	public Object setAccessAttributes(Object stg, Object[] attrs) {
		// TODO: If we need to support Accessibility, then this needs to be implemented
		// System.out.println("setAccessAttributes not implemented");
		return null;
	}
	@Override
	public Object setAccessCallback(Object stg, Func0 fn) {
		// TODO: If we need to support Accessibility, then this needs to be implemented
		// System.out.println("setAccessCallback not implemented");
		return null;
	}
	@Override
	public Object addChild(Object stg, Object child) {
		Clip cc = (Clip)child;
		cc.setParent((Clip)stg);
		return null;
	}
	@Override
	public Object addChildAt(Object stg, Object child, Integer at) {
		Clip cc = (Clip)child;
		cc.setParentAt((Clip)stg, at);
		return null;
	}
	@Override
	public Object removeChild(Object stg, Object child) {
		Clip cc = (Clip)child;
		if (cc.parent == stg)
			cc.setParent(null);
		return null;
	}
	@Override
	public Object setClipMask(Object stg, Object mask) {
		((Clip)mask).setMaskOwner((Clip)stg);
		return null;
	}
	@Override
	public Object setClipCallstack(Object stg, Object stack) {
		return null;
	}
	@Override
	public double getMouseX(Object stg) {
		return mouse_x;
	}
	@Override
	public double getMouseY(Object stg) {
		return mouse_y;
	}
	@Override
	public boolean getClipVisible(Object stg) {
		Clip cl = (Clip)stg;
		return cl.getTop().isVisible();
	}
	@Override
	public Object setClipVisible(Object stg, boolean on) {
		Clip cl = (Clip)stg;
		cl.getTop().setVisible(on);
		return null;
	}
	@Override
	public Object setClipX(Object stg, double val) {
		Clip cl = (Clip)stg;
		if (cl.mask_owner == null)
			cl.getTop().setTranslateX(cl.x = val);
		return null;
	}
	@Override
	public Object setClipY(Object stg, double val) {
		Clip cl = (Clip)stg;
		if (cl.mask_owner == null)
			cl.getTop().setTranslateY(cl.y = val);
		return null;
	}
	@Override
	public Object setClipScaleX(Object stg, double val) {
		Clip cl = (Clip)stg;
		if (cl.mask_owner != null)
			return null;
		if (cl.scaling == null) {
			if (val == 1.0)
				return null;
			cl.scaling = new Scale(val, 1.0, 0, 0);
			cl.getTop().getTransforms().add(cl.scaling);
		} else {
			cl.scaling.setX(val);
		}
		return null;
	}
	@Override
	public Object setClipScaleY(Object stg, double val) {
		Clip cl = (Clip)stg;
		if (cl.mask_owner != null)
			return null;
		if (cl.scaling == null) {
			if (val == 1.0)
				return null;
			cl.scaling = new Scale(1.0, val, 0, 0);
			cl.getTop().getTransforms().add(cl.scaling);
		} else {
			cl.scaling.setY(val);
		}
		return null;
	}
	@Override
	public Object setClipAlpha(Object stg, double val) {
		Clip cl = (Clip)stg;
		cl.getTop().setOpacity(val);
		return null;
	}
	@Override
	public Object setClipRotation(Object stg, double val) {
		Clip cl = (Clip)stg;
		if (cl.rotation == null) {
			if (val == 0.0)
				return null;
			cl.rotation = new Rotate(val, cl.x, cl.y);
			cl.getTop().getTransforms().add(0, cl.rotation);
		} else {
			cl.rotation.setAngle(val);
		}
		return null;
	}
	@Override
	public Object setScrollRect(Object stg, double x, double y, double w, double h) {
		Clip cl = (Clip)stg;
		if (cl.top == cl.container) {
			cl.top = new Group();
			cl.top.getChildren().add(cl.container);
		}
		cl.container.setClip(new Rectangle(x, y, w, h));
		cl.container.setTranslateX(-x);
		cl.container.setTranslateY(-y);
		return null;
	}
	@Override
	public String getCursor() {
		return cur_cursor;
	}
	@Override
	public Object setCursor(String val) {
		cur_cursor = val;
		if (val == "finger")
			scene.setCursor(Cursor.HAND);
		else if (val == "move")
			scene.setCursor(Cursor.MOVE);
		else if (val == "text")
			scene.setCursor(Cursor.TEXT);
		else if (val == "none")
			scene.setCursor(Cursor.NONE);
		else
			scene.setCursor(Cursor.DEFAULT);
		return null;
	}
	@Override
	public Func0<Object> addEventListener(Object stg, String event, Func0<Object> fn) {
		final Clip cl = (Clip)stg;
		if (event == "resize")
			return addEvent(event_resize, fn);
		else if (event == "mousemove")
			return addEvent(event_mousemove, fn);
		else if (event == "mousedown")
			return addEvent(event_mousedown, fn);
		else if (event == "mouseup")
			return addEvent(event_mouseup, fn);
		else if (event == "mouseenter" || event == "rollover") {
			if (cl.event_mouseenter == null) {
				cl.event_mouseenter = new TreeMap<Integer,Func0<Object>>();
				cl.getTop().addEventHandler(
					MouseEvent.MOUSE_ENTERED_TARGET, new EventHandler<MouseEvent>() {
					@Override public void handle(MouseEvent event) {
						mouse_x = event.getSceneX();
						mouse_y = event.getSceneY();
						for (Func0<Object> cb : cl.event_mouseenter.values().toArray(event_cb_arr))
							cb.invoke();
					}
				});
			}
			return addEvent(cl.event_mouseenter, fn);
		}
		else if (event == "mouseleave" || event == "rollout") {
			if (cl.event_mouseleave == null) {
				cl.event_mouseleave = new TreeMap<Integer,Func0<Object>>();
				cl.getTop().addEventHandler(
					MouseEvent.MOUSE_EXITED_TARGET, new EventHandler<MouseEvent>() {
					@Override public void handle(MouseEvent event) {
						mouse_x = event.getSceneX();
						mouse_y = event.getSceneY();
						for (Func0<Object> cb : cl.event_mouseleave.values().toArray(event_cb_arr))
							cb.invoke();
					}
				});
			}
			return addEvent(cl.event_mouseleave, fn);
		}
		/*
    else if (event == "click")
        type = FlowMouseClick;
     else if (event == "change")
        type = FlowTextChange;
    else if (event == "scroll")
        type = FlowTextScroll;
    else if (event == "focusin")
        type = FlowFocusIn;
    else if (event == "focusout")
        type = FlowFocusOut;
		*/
		return no_op;
	}
	@Override
	public Func0<Object> addKeyEventListener(Object stg, String event, Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> fn) {
		if (event == "keydown") {
			return addEvent(event_keydown, fn);
		} else if (event == "keyup") {
			return addEvent(event_keyup, fn);
		} else {
			System.out.println("Unknown key event!");
			return no_op;
		}
	}
	@Override
	public Object emitKeyEvent(Object stg, String name, String key, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer code) {
		System.out.println("emitKeyEvent not implemented");
		return null;
	}
	@Override
	public Func0<Object> addMouseWheelEventListener(Object stg, Func1<Object,Double> cb) {
		System.out.println("addMouseWheelEventListener not implemented");
		return no_op;
	}
	@Override
	public Func0<Object> addFinegrainMouseWheelEventListener(Object stg, Func2<Object,Double,Double> cb) {
		System.out.println("addFinegrainMouseWheelEventListener not implemented");
		return no_op;
	}
	@Override
	public Func0<Object> addGestureListener(String name, Func5<Boolean,Integer,Double,Double,Double,Double> cb) {
		System.out.println("addGestureListener not implemented");
		return no_op;
	}
	@Override
	public boolean hittest(Object stg, double x, double y) {
		Clip cl = (Clip)stg;
		return cl.hittest(x, y);
	}

	private class TextClip extends Clip {
		Text text;

		public TextClip() {
			text = new Text("");
			container.getChildren().add(text);
		}
		public boolean hittest(double x, double y) {
			if (checkNodeHit(text, x, y))
				return true;
			return super.hittest(x, y);
		}
	}

	@Override
	public Object makeTextField(String fontfamily) {
		return new TextClip();
	}
	@Override
	public Object setTextInput(Object stg) {
		System.out.println("setTextInput not implemented");
		return null;
	}
	@Override
	public double getTextFieldWidth(Object tf) {
		TextClip tc = (TextClip)tf;
		return tc.text.getLayoutBounds().getWidth();
	}
	@Override
	public double getTextFieldHeight(Object tf) {
		TextClip tc = (TextClip)tf;
		return tc.text.getLayoutBounds().getHeight();
	}
	@Override
	public Object setTextFieldWidth(Object stg, double val) {
		System.out.println("setTextFieldWidth not implemented");
		return null;
	}
	@Override
	public Object setTextFieldHeight(Object stg, double val) {
		System.out.println("setTextFieldHeight not implemented");
		return null;
	}
	@Override
	public Object setAdvancedText(Object stg,int a,int o,int e) {
		// Not required
		// System.out.println("setAdvancedText not implemented");
		return null;
	}
	@Override
	public Object setTextAndStyle(Object tf, String text, String font, double size, int weight, 
								  String slope, int fill, double fillopacity, double letterspacing, 
								  int bgColor,double bgOpacity) {
		TextClip tc = (TextClip)tf;
		// Unescape HTML glyphs here
		// &#xABCD; -> Some unicode glyph
		StringBuilder unicode = new StringBuilder();
		int n = text.length();
		for (int i = 0; i < text.length(); i++) {
			char c = text.charAt(i);
			if (c == '&' && i + 2 < n && text.charAt(i + 1) == '#'  && text.charAt(i + 2) == 'x') {
				int semi = text.indexOf(';', i + 2);
				if (semi == -1) {
					unicode.append(c);
				} else {
					int v = 0;
					String hex = text.substring(i + 3, semi);
					int code = Integer.decode("0x" + hex);
					unicode.append((char) code);
					i = semi;
				}
			} else {
				unicode.append(c);
			}
		}
		tc.text.setText(unicode.toString());
		// TODO: Translate font names here somehow
		tc.text.setFont(new Font(font, size));
		tc.text.setFill(mkColor(fill,fillopacity));
		tc.text.relocate(0,0);
		return null;
	}
	@Override
	public Object setTextDirection(Object stg, String val) {
		System.out.println("setTextDirection is not implemented");
		return null;
	}
	@Override
	public int getNumLines(Object stg) {
		System.out.println("getNumLines not implemented");
		return 0;
	}
	@Override
	public int getCursorPosition(Object stg) {
		System.out.println("getCursorPosition not implemented");
		return 0;
	}
	@Override
	public boolean getFocus(Object stg) {
		System.out.println("getFocus not implemented");
		return false;
	}
	@Override
	public Object setFocus(Object stg, boolean val) {
		System.out.println("setFocus not implemented");
		return null;
	}
	@Override
	public String getContent(Object stg) {
		System.out.println("getContent not implemented");
		return null;
	}
	@Override
	public Object setMultiline(Object stg, boolean val) {
		System.out.println("setMultiline not implemented");
		return null;
	}
	@Override
	public Object setWordWrap(Object stg, boolean val) {
		System.out.println("setWordWrap not implemented");
		return null;
	}
	@Override
	public Object setNumeric(Object stg, boolean val) {
		System.out.println("setNumeric not implemented");
		return null;
	}
	@Override
	public Object setReadOnly(Object stg, boolean val) {
		System.out.println("setReadOnly not implemented");
		return null;
	}
	@Override
	public Object setAutoAlign(Object stg, String val) {
		System.out.println("setAutoAlign not implemented");
		return null;
	}
	@Override
	public Object setTextFieldPasswordMode(Object stg, boolean val) {
		System.out.println("setTextFieldPasswordMode not implemented");
		return null;
	}
	@Override
	public Object setTabIndex(Object stg, int val) {
		System.out.println("setTabIndex not implemented");
		return null;
	}
	@Override
	public int getScrollV(Object stg) {
		System.out.println("getScrollV not implemented");
		return 0;
	}
	@Override
	public int getBottomScrollV(Object stg) {
		System.out.println("getBottomScrollV not implemented");
		return 0;
	}
	@Override
	public Object setScrollV(Object stg, int val) {
		System.out.println("setScrollV not implemented");
		return null;
	}
	@Override
	public Object setMaxChars(Object stg, int val) {
		System.out.println("setMaxChars not implemented");
		return null;
	}
	@Override
	public Object[] getTextMetrics(Object tf) {
		TextClip tc = (TextClip)tf;
		Text text = tc.text;
		Font font = text.getFont();

		double size = font.getSize();

		double ascent = text.getBaselineOffset();
		// double ascent2 = 0.9 * size;
		double descent = 0.1 * size;
		double leading = 0.15 * size;
		return new Object[] { ascent, descent, leading };
	}
	@Override
	public int getSelectionStart(Object stg) {
		System.out.println("getSelectionStart not implemented");
		return 0;
	}
	@Override
	public int getSelectionEnd(Object stg) {
		System.out.println("getSelectionEnd not implemented");
		return 0;
	}
	@Override
	public Object setSelection(Object stg, int start, int end) {
		System.out.println("setSelection not implemented");
		return null;
	}
	@Override
	public Object makeVideo(Func2<Object,Double,Double> mfn, Func1<Object, Boolean> pfn, Func1<Object, Double> dfn, Func1<Object, Double> posfn) {
		System.out.println("makeVideo not implemented");
		return new Clip();
	}
	@Override
	public Object pauseVideo(Object stg) {
		System.out.println("pauseVideo not implemented");
		return null;
	}
	@Override
	public Object resumeVideo(Object stg) {
		System.out.println("resumeVideo not implemented");
		return null;
	}
	@Override
	public Object closeVideo(Object stg) {
		System.out.println("closeVideo not implemented");
		return null;
	}
	@Override
	public Object playVideo(Object obj, String name, boolean pause) {
		System.out.println("playVideo not implemented");
		return null;
	}
	@Override
	public double getVideoPosition(Object stg) {
		System.out.println("getVideoPosition not implemented");
		return 0;
	}
	@Override
	public Object seekVideo(Object stg, double val) {
		System.out.println("seekVideo not implemented");
		return null;
	}
	@Override
	public Object setVideoVolume(Object stg, double val) {
		System.out.println("setVideoVolume not implemented");
		return null;
	}
	@Override
	public Object setVideoLooping(Object stg, boolean val) {
		System.out.println("setVideoLooping not implemented");
		return null;
	}
	@Override
	public Object setVideoControls(Object stg, Object[] info) {
		System.out.println("setVideoControls not implemented");
		return null;
	}
	@Override
	public Object setVideoSubtitle(Object tf, String text, String fontFamily, double fontSize, int fontWeight, 
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing, 
								  int backgroundColour,double backgroundOpacity) {
		System.out.println("setVideoSubtitle not implemented");
		return null;
	}
	@Override
	public Object setVideoPlaybackRate(Object tf, Double rate) {
		System.out.println("setVideoPlaybackRate not implemented");
		return null;
	}
	@Override
	public Func0<Object> addStreamStatusListener(Object vid, Func1<Object,String> cb) {
		System.out.println("addStreamStatusListener not implemented");
		return no_op;
	}
	@Override
	public boolean isFullScreen() {
		System.out.println("isFullScreen not implemented");
		return false;
	}
	@Override
	public Object toggleFullScreen(Boolean fs) {
		System.out.println("toggleFullScreen not implemented");
		return null;
	}
	@Override
	public Object toggleFullWindow(Boolean fs) {
		System.out.println("toggleFullWindow not implemented");
		return null;
	}
	@Override
	public Func0<Object> onFullScreen(Func1<Object,Boolean> cb) {
		System.out.println("onFullScreen not implemented");
		return null;
	}
	@Override
	public Object setFullScreen(Boolean fs) {
		System.out.println("setFullScreen not implemented");
		return null;
	}
	@Override
	public Object setFullWindowTarget(Object stg) {
		System.out.println("setFullWindowTarget not implemented");
		return null;
	}
	@Override
	public Object resetFullWindowTarget() {
		System.out.println("resetFullWindowTarget not implemented");
		return null;
	}
	@Override
	public Object setFullScreenRectangle(double x, double y, double w, double h) {
		System.out.println("setFullScreenRectangle not implemented");
		return null;
	}
	@Override
	public Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,boolean i) {
		System.out.println("makeBevel not implemented");
		return null;
	}
	@Override
	public Object makeDropShadow(double angle,double distance,double radius,double spread,int color, double alpha,boolean inside) {
		double a = Math.PI * angle / 180.0;
		double dx = Math.cos(a) * distance, dy = Math.sin(a) * distance;
		return new DropShadow(BlurType.TWO_PASS_BOX, mkColor(color, alpha), radius, spread, dx, dy);
	}
	@Override
	public Object makeBlur(double radius,double spread) {
		return new BoxBlur(radius, radius, (int)spread);
	}
	@Override
	public Object makeGlow(double a,double b,int c, double d,boolean e) {
		System.out.println("makeGlow not implemented");
		return null;
	}

	private class CachedPicture {
		Image image;
		boolean loaded = false;
		boolean failed = false;
		SortedMap<Integer,Func2<Object,Double,Double>> event_metrics = new TreeMap<Integer,Func2<Object,Double,Double>>();
		SortedMap<Integer,Func1<Object,String>> event_error = new TreeMap<Integer,Func1<Object,String>>();

		CachedPicture(String url) {
			image = new Image(url, true);

			ChangeListener<Number> resize_cb = new ChangeListener<Number>() {
				public void changed(ObservableValue<? extends Number> observable, Number oldValue, Number newValue) {
					double w = image.getWidth();
					double h = image.getHeight();

					if (w == 0 || h == 0 || loaded)
						return;

					for (Func2<Object,Double,Double> cb : event_metrics.values())
						cb.invoke(w, h);

					loaded = true;
					event_metrics = null;
					event_error = null;
				}
			};

			image.widthProperty().addListener(resize_cb);
			image.heightProperty().addListener(resize_cb);

			ChangeListener<Boolean> error_cb = new ChangeListener<Boolean>() {
				public void changed(ObservableValue<? extends Boolean> observable, Boolean oldValue, Boolean newValue) {
					if (!newValue || loaded)
						return;

					for (Func1<Object,String> cb : event_error.values())
						cb.invoke("load failed");

					loaded = failed = true;
					event_metrics = null;
					event_error = null;
				}
			};

			image.errorProperty().addListener(error_cb);
		}
	}

	private Hashtable<String,CachedPicture> img_cache = new Hashtable<String,CachedPicture>();

	private class PictureClip extends Clip {
		ImageView view;
		CachedPicture pic;

		public PictureClip(CachedPicture pic) {
			this.pic = pic;
			view = new ImageView(pic.image);
			container.getChildren().add(view);
		}
		public boolean hittest(double x, double y) {
			if (checkNodeHit(view, x, y))
				return true;
			return super.hittest(x, y);
		}
	}

	@Override
	public Object makePicture(String name,boolean cache,Func2<Object,Double,Double> metricsFn,Func1<Object,String> errorFn,boolean onlyDownload) {
		CachedPicture img = img_cache.get(name);

		if (img == null) {
			img = new CachedPicture("http://cloud1.area9.dk/flow/"+name);
			if (cache)
				img_cache.put(name, img);
		}

		if (img.loaded) {
			if (img.failed)
				errorFn.invoke("load failed");
			else
				metricsFn.invoke(img.image.getWidth(), img.image.getHeight());
		} else {
			addEvent(img.event_metrics, metricsFn);
			addEvent(img.event_error, errorFn);
		}

		return new PictureClip(img);
	}
	@Override
	public Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1<Object,Object> n,Func1<Object,String> s) {
		System.out.println("makeCamera not implemented");
		Clip tmp = new Clip();
		return new Object[] { tmp, tmp };
	}
	@Override
	public Object startRecord(Object cm,String a,String o) {
		System.out.println("startRecord not implemented");
		return null;
	}
	@Override
	public Object stopRecord(Object cm) {
		System.out.println("stopRecord not implemented");
		return null;
	}

	private class Graphics {
		Clip owner;
		Path path;

		Graphics(Clip owner) {
			this.owner = owner;
			path = new Path();
			path.setStroke(null);
			owner.container.getChildren().add(0,path);
		}
		public boolean hittest(double x, double y) {
			return checkNodeHit(path, x, y);
		}
	}

	@Override
	public Object getGraphics(Object clip) {
		Clip cl = (Clip)clip;
		return cl.getGraphics();
	}
	private Color mkColor(int color, double alpha) {
		return Color.rgb((color>>16)&0xff,(color>>8)&0xff,color&0xff,alpha);
	}
	@Override
	public Object beginFill(Object gr,int color,double alpha) {
		Graphics g = (Graphics)gr;
		g.path.setFill(mkColor(color, alpha));
		return null;
	}
	@Override
	public Object setLineStyle(Object gr,double width,int color,double alpha) {
		Graphics g = (Graphics)gr;
		g.path.setStroke(mkColor(color, alpha));
		g.path.setStrokeWidth(width);
		return null;
	}
	@Override
	public Object makeMatrix(double width,double height,double rotation,double x,double y) {
		return new double[] { width, height, rotation, x, y };
	}
	private Paint makeLinearGradient(Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		double[] mat = (double[])matrix;
		double a = Math.PI * mat[2] / 180.0;
		double dx = Math.cos(a) * mat[0], dy = Math.sin(a) * mat[0];
		double x1 = mat[3] + (mat[0] - dx) * 0.5, y1 = mat[4] + (mat[1] - dy) * 0.5;
		double x2 = mat[3] + (mat[0] + dx) * 0.5, y2 = mat[4] + (mat[1] + dy) * 0.5;
		List<Stop> stops = new ArrayList<Stop>();
		for (int i = 0; i < color.length; i++)
			stops.add(new Stop((double)offset[i], mkColor((int)color[i], (double)alpha[i])));
		return new LinearGradient(x1,y1,x2,y2,false,CycleMethod.NO_CYCLE,stops);
	}
	private Paint makeRadialGradient(Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		double[] mat = (double[])matrix;
		double x = mat[3] + mat[0] * 0.5, y = mat[4] + mat[1] * 0.5;
		double r = Math.sqrt((mat[0]*mat[0]+mat[1]*mat[1])/8.0);
		List<Stop> stops = new ArrayList<Stop>();
		for (int i = 0; i < color.length; i++)
			stops.add(new Stop((double)offset[i], mkColor((int)color[i], (double)alpha[i])));
		return new RadialGradient(0,0,x,y,r,false,CycleMethod.NO_CYCLE,stops);
	}
	@Override
	public Object beginGradientFill(Object gr,Object[] color,Object[] alpha,Object[] offset,Object matrix,String type) {
		Graphics g = (Graphics)gr;
		Paint p;
		if (type == "radial")
			p = makeRadialGradient(color,alpha,offset,matrix);
		else
			p = makeLinearGradient(color,alpha,offset,matrix);
		g.path.setFill(p);
		return null;
	}
	@Override
	public Object setLineGradientStroke(Object gr,Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		Graphics g = (Graphics)gr;
		g.path.setStroke(makeLinearGradient(color,alpha,offset,matrix));
		return null;
	}
	@Override
	public Object moveTo(Object gr,double x,double y) {
		Graphics g = (Graphics)gr;
		MoveTo moveTo = new MoveTo();
		moveTo.setX(x);
		moveTo.setY(y);
		g.path.getElements().add(moveTo);
		return null;
	}
	@Override
	public Object lineTo(Object gr,double x,double y) {
		Graphics g = (Graphics)gr;
		LineTo lineTo = new LineTo();
		lineTo.setX(x);
		lineTo.setY(y);
		g.path.getElements().add(lineTo);
		return null;
	}
	@Override
	public Object curveTo(Object gr,double cx,double cy,double x, double y) {
		Graphics g = (Graphics)gr;
		QuadCurveTo quadTo = new QuadCurveTo();
		quadTo.setControlX(cx);
		quadTo.setControlY(cy);
		quadTo.setX(x);
		quadTo.setY(y);
		g.path.getElements().add(quadTo);
		return null;
	}
	@Override
	public Object endFill(Object gr) {
		return null;
	}
}
