package com.area9innovation.flow.javafx;

import java.awt.*;
import java.util.*;
import java.util.List;

import com.area9innovation.flow.*;

import javafx.application.Platform;
import javafx.animation.AnimationTimer;
import javafx.beans.property.StringProperty;
import javafx.beans.property.StringPropertyBase;
import javafx.event.EventHandler;
import javafx.event.EventType;
import javafx.geometry.BoundingBox;
import javafx.geometry.Bounds;
import javafx.geometry.NodeOrientation;
import javafx.scene.Scene;
import javafx.scene.Group;
import javafx.scene.Parent;
import javafx.scene.Node;
import javafx.scene.control.TextField;
import javafx.scene.control.PasswordField;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextInputControl;
import javafx.scene.input.*;
import javafx.scene.shape.Rectangle;
import javafx.scene.text.Text;
import javafx.scene.transform.Transform;
import javafx.stage.Stage;
import javafx.scene.shape.*;
import javafx.scene.paint.Color;
import javafx.scene.transform.Rotate;
import javafx.scene.transform.Scale;
import javafx.scene.effect.BoxBlur;
import javafx.scene.effect.Effect;
import javafx.beans.value.ChangeListener;
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
import javafx.scene.text.Font;

public class FxRenderSupport extends RenderSupport {
	private static Stage stage;
	private static Scene scene;
	private static Clip stage_clip;
	private static int next_event_id = 0;
	private static double mouse_x, mouse_y;
	private static String cur_cursor = "";
	private static Boolean isMouseDown = false;

	private static TreeMap<Integer, Func0<Object>> event_resize = new TreeMap<>();
	private static TreeMap<Integer,Func0<Object>> event_mousemove = new TreeMap<>();
	private static TreeMap<Integer,Func0<Object>> event_mousedown = new TreeMap<>();
	private static TreeMap<Integer,Func0<Object>> event_mouseup = new TreeMap<>();
	private static TreeMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> event_keydown = new TreeMap<>();
	private static TreeMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> event_keyup = new TreeMap<>();
	private static TreeMap<Integer,Func1<Object,Double>> event_mousewheel = new TreeMap<>();
	private static TreeMap<Integer,Func2<Object,Double,Double>> event_finegrain_mousewheel = new TreeMap<>();

	private static Func0<Object> no_op = () -> null;

	private static <T> Func0<Object> addEvent(final TreeMap<Integer,T> map, T listener) {
		final int id = next_event_id++;
		map.put(id, listener);
		return () -> {
			map.remove(id);
			return null;
		};
	}

	private static boolean checkNodeCliped(Node node, double x, double y) {
		Point2D pos = node.sceneToLocal(x,y);
		if (pos == null) return false;
		else return node.getClip().intersects(pos.getX(), pos.getY(), 1, 1);
	}

	private static boolean checkNodeHit(Node node, double x, double y) {
		Point2D pos = node.sceneToLocal(x,y);
		if (pos == null) return false;
		else return node.intersects(pos.getX(), pos.getY(), 1, 1);
	}

	private static class Clip {
		Group container, top;
		Clip parent, mask, mask_owner;
		List<Clip> children = new ArrayList<>();
		Graphics graphics;
		Rotate rotation;
		Scale scaling;
		double x, y;

		TreeMap<Integer,Func0<Object>> event_mouseenter;
		TreeMap<Integer,Func0<Object>> event_mouseleave;

		Clip() {
			container = top = new Group();
		}

		Parent getTop() {
			return top;
		}
		void setScrollRect(BoundingBox rect) {
			getTop().setClip(new Rectangle(rect.getMinX(), rect.getMinY(), rect.getWidth(), rect.getHeight()));
			getTop().setTranslateX(-rect.getMinX());
			getTop().setTranslateY(-rect.getMinY());
		}
		void setMask(Clip mask) {
			if (this.mask != null)
				this.mask.mask_owner = null;
			this.mask = this;
			mask.mask_owner = this;
			this.getTop().setClip(mask.getTop());
			if (mask.parent != null) {
				parent.container.getChildren().remove(mask.getTop());
				parent.children.remove(mask);
			}
		}
		void setParent(Clip new_parent) {
			setParentAt(new_parent, new_parent != null ? new_parent.children.size() : 0);
		}
		void setParentAt(Clip new_parent, Integer at) {
			if (new_parent == parent || mask_owner != null)
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
		Graphics getGraphics() {
			if (graphics == null)
				graphics = new Graphics(this);
			return graphics;
		}
		Point2D getMousePos(Point2D global) {
			if (graphics != null)
				return graphics.path.sceneToLocal(global);

			Transform globalTransform = getTop().getLocalToSceneTransform();
			Bounds globalBounds = getTop().localToScene(getTop().getBoundsInLocal());
			return new Point2D(
					(global.getX() - globalBounds.getMinX()) / globalTransform.getMxx(),
					(global.getY() - globalBounds.getMinY()) / globalTransform.getMyy());
		}

		boolean hittestCliped(double x, double y) {
			if (getTop().getClip() != null && !checkNodeCliped(getTop(), x, y)) {
				return false;
			} else if (getTop().getParent() != null) {
				return parent.hittestCliped(x, y);
			} else {
				return true;
			}
		}

		public boolean hittest(double x, double y) {
			if (graphics != null && graphics.hittest(x, y))
				return true;
			if (getTop().getClip() != null && !checkNodeCliped(getTop(), x, y))
				return false;

			for (Clip child : children)
				if (child.hittest(x,y))
					return true;

			return false;
		}
	}
	@SuppressWarnings("unchecked")
	private static Func0<Object>[] event_cb_arr = new Func0[0];

	FxRenderSupport(Stage stage) {
		this.stage = stage;

		stage_clip = new Clip();
		scene = new Scene(stage_clip.getTop(), 1024, 600);
		scene.getStylesheets().add(getClass().getClassLoader().getResource("./css/style.css").toExternalForm());
		scene.getStylesheets().add("https://fonts.googleapis.com/css?family=Roboto:400,500%7CMaterial+Icons");
		stage.setScene(scene);
		stage.show();

		ChangeListener<Number> resize_cb = (observable, oldValue, newValue) -> {
			for (Func0<Object> cb : event_resize.values())
				cb.invoke();
		};

		stage.widthProperty().addListener(resize_cb);
		stage.heightProperty().addListener(resize_cb);

		EventHandler<MouseEvent> move_cb = event -> {
			mouse_x = event.getSceneX();
			mouse_y = event.getSceneY();
			for (Func0<Object> cb : event_mousemove.values().toArray(event_cb_arr))
				cb.invoke();
		};

		stage.addEventHandler(MouseEvent.MOUSE_MOVED, move_cb);
		stage.addEventHandler(MouseEvent.MOUSE_DRAGGED, move_cb);

		// Sometimes javafx doesn't fire mouse released event.
		// At least when textinput was previously focused
		EventHandler<MouseEvent> mouseDownHandler = event -> {
			isMouseDown = true;
			mouse_x = event.getSceneX();
			mouse_y = event.getSceneY();

			for (Func0<Object> cb : event_mousedown.values().toArray(event_cb_arr))
				cb.invoke();
		};
		EventHandler<MouseEvent> mouseUpHandler = event -> {
			isMouseDown = false;
			mouse_x = event.getSceneX();
			mouse_y = event.getSceneY();

			for (Func0<Object> cb : event_mouseup.values().toArray(event_cb_arr))
				cb.invoke();
		};
		EventHandler<MouseEvent> mouseClickHandler = event -> {
			if (!isMouseDown)
				return;

			mouseUpHandler.handle(event);
		};
		EventHandler<ScrollEvent> mouseWheelHandler = event -> {
			Double dx = event.getDeltaX() / 12;
			Double dy = event.getDeltaY() / 12;
			for (Func1<Object,Double> cb : event_mousewheel.values())
				cb.invoke(dy + dx);

			for (Func2<Object,Double,Double> cb : event_finegrain_mousewheel.values())
				cb.invoke(dx, dy);
		};

		stage.addEventHandler(MouseEvent.MOUSE_PRESSED, mouseDownHandler);
		stage.addEventHandler(MouseEvent.MOUSE_RELEASED, mouseUpHandler);
		stage.addEventHandler(MouseEvent.MOUSE_CLICKED, mouseClickHandler);
		stage.addEventHandler(ScrollEvent.SCROLL, mouseWheelHandler);

		EventHandler<KeyEvent> keyEventHandler = this::handleKeyEvent;

		scene.setOnKeyPressed(keyEventHandler);
		scene.setOnKeyReleased(keyEventHandler);
		scene.setOnMouseExited(e -> {
			if (isMouseDown) {
				mouseUpHandler.handle(e);
			}
		});
	}

	private void handleKeyEvent(KeyEvent event) {
		TreeMap<Integer,Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>>> handler_map;

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

	private static Integer parseKeyCode(KeyCode keyCode) {
		Integer code;
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
		}

		return code;
	}

	public static Object getStage() {
		return stage_clip;
	}

	public static double getStageWidth() {
		return stage.getWidth();
	}

	public static double getStageHeight() {
		return stage.getHeight();
	}

	public static Object setHitboxRadius(double val) {
		return null;
	}

	public static Object setWindowTitle(String title) {
		stage.setTitle(title);
		return null;
	}

	public static Object setFavIcon(String url) {
		return null;
	}

	public static Object enableResize() {
		// We always allow resizing, so let's just ignore this
		// System.out.println("enableResize not implemented");
		return null;
	}

	public static final Object makeClip() {
		return new Clip();
	}

	public static Object makeGraphics() {
		return new Clip();
	}

	public static Object currentClip() {
		return stage_clip;
	}

	public static Object makeWebClip(String url,String domain,Boolean useCache, Boolean reloadBlock, Func1<String,Object[]> cb, Func1<Object,String> ondone, Boolean shrinkToFit) {
		System.out.println("makeWebClip not implemented");
		return new Clip();
	}

	public static String webClipHostCall(Object clip,String fn,Object[] args) {
		System.out.println("webClipHostCall not implemented");
		return null;
	}

	public static Object setWebClipZoomable(Object clip,Boolean zoomable) {
		System.out.println("setWebClipZoomable not implemented");
		return null;
	}

	public static Object setWebClipDomains(Object clip,Object[] domains) {
		return null;
	}

	public static Object addFilters(Object stg, Object[] filters) {
		Clip cl = (Clip)stg;
		for (Object filter : filters)
			if (filter != null)
				cl.getTop().setEffect((Effect) filter);
		return null;
	}

	public static Object setAccessAttributes(Object stg, Object[] attrs) {
		// TODO: If we need to support Accessibility, then this needs to be implemented
		// System.out.println("setAccessAttributes not implemented");
		return null;
	}

	public static Object setAccessCallback(Object stg, Func0 fn) {
		// TODO: If we need to support Accessibility, then this needs to be implemented
		// System.out.println("setAccessCallback not implemented");
		return null;
	}

	public static Object addChild(Object stg, Object child) {
		Clip cc = (Clip)child;
		cc.setParent((Clip)stg);
		return null;
	}

	public static Object addChildAt(Object stg, Object child, Integer at) {
		Clip cc = (Clip)child;
		cc.setParentAt((Clip)stg, at);
		return null;
	}

	public static Object removeChild(Object stg, Object child) {
		Clip cc = (Clip)child;
		if (cc.parent == stg)
			cc.setParent(null);
		return null;
	}

	public static Object setClipMask(Object stg, Object mask) {
		((Clip)stg).setMask((Clip)mask);
		return null;
	}

	public static Object setClipCallstack(Object stg, Object stack) {
		return null;
	}

	public static double getMouseX(Object stg) {
		Clip cl = (Clip) stg;
		return cl.getMousePos(new Point2D(mouse_x, mouse_y)).getX();
	}

	public static double getMouseY(Object stg) {
		Clip cl = (Clip)stg;
		return cl.getMousePos(new Point2D(mouse_x, mouse_y)).getY();
	}

	public static boolean getClipVisible(Object stg) {
		Clip cl = (Clip)stg;
		return cl.getTop().isVisible();
	}

	public static Object setClipVisible(Object stg, boolean on) {
		Clip cl = (Clip)stg;
		cl.getTop().setVisible(on);
		return null;
	}

	public static Object setClipX(Object stg, double val) {
		Clip cl = (Clip)stg;
		cl.getTop().setLayoutX(cl.x = val);
		return null;
	}

	public static Object setClipY(Object stg, double val) {
		Clip cl = (Clip)stg;
		cl.getTop().setLayoutY(cl.y = val);
		return null;
	}

	public static Object setClipScaleX(Object stg, double val) {
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

	public static Object setClipScaleY(Object stg, double val) {
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

	public static Object setClipAlpha(Object stg, double val) {
		Clip cl = (Clip)stg;
		cl.getTop().setOpacity(val);
		return null;
	}

	public static Object setClipRotation(Object stg, double val) {
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

	public static Object setScrollRect(Object stg, double x, double y, double w, double h) {
		Clip cl = (Clip)stg;
		cl.setScrollRect(new BoundingBox(x, y, w, h));
		return null;
	}

	public static String getCursor() {
		return cur_cursor;
	}

	public static Object setCursor(String val) {
		cur_cursor = val;
		if ("finger".equals(val))
			scene.setCursor(Cursor.HAND);
		else if ("move".equals(val))
			scene.setCursor(Cursor.MOVE);
		else if ("text".equals(val))
			scene.setCursor(Cursor.TEXT);
		else if ("none".equals(val))
			scene.setCursor(Cursor.NONE);
		else
			scene.setCursor(Cursor.DEFAULT);
		return null;
	}

	public static Func0<Object> addEventListener(Object stg, String event, Func0<Object> fn) {
		final Clip cl = (Clip)stg;
		if ("resize".equals(event))
			return addEvent(event_resize, fn);
		else if ("mousemove".equals(event))
			return addEvent(event_mousemove, fn);
		else if ("mousedown".equals(event))
			return addEvent(event_mousedown, fn);
		else if ("mouseup".equals(event))
			return addEvent(event_mouseup, fn);
		else if ("mouseenter".equals(event) || "rollover".equals(event)) {
			if (cl.event_mouseenter == null) {
				cl.event_mouseenter = new TreeMap<>();
				cl.getTop().setOnMouseEntered(e -> {
					mouse_x = e.getSceneX();
					mouse_y = e.getSceneY();
					for (Func0<Object> cb : cl.event_mouseenter.values().toArray(event_cb_arr))
						cb.invoke();
				});
			}
			return addEvent(cl.event_mouseenter, fn);
		}
		else if ("mouseleave".equals(event) || "rollout".equals(event)) {
			if (cl.event_mouseleave == null) {
				cl.event_mouseleave = new TreeMap<>();
				cl.getTop().setOnMouseExited(e -> {
					mouse_x = e.getSceneX();
					mouse_y = e.getSceneY();
					for (Func0<Object> cb : cl.event_mouseleave.values().toArray(event_cb_arr))
						cb.invoke();
				});
			}
			return addEvent(cl.event_mouseleave, fn);
		} else if (cl instanceof TextInput) {
			TextInput ti = (TextInput)cl;

			if ("change".equals(event)) {
				return ti.addTextListener(fn);
//			} else if ("scroll".equals(event)) {
			} else if ("focusin".equals(event)) {
				ti.addFocusInListener(fn);
			} else if ("focusout".equals(event)) {
				ti.addFocusOutListener(fn);
			}
		}

		return no_op;
	}

	public static Func0<Object> addKeyEventListener(Object stg, String event, Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> fn) {
		if ("keydown".equals(event)) {
			return addEvent(event_keydown, fn);
		} else if ("keyup".equals(event)) {
			return addEvent(event_keyup, fn);
		} else {
			System.out.println("Unknown key event!");
			return no_op;
		}
	}

	public static Object emitKeyEvent(Object stg, String name, String key, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer code) {
		System.out.println("emitKeyEvent not implemented");
		return null;
	}

	public static Func0<Object> addMouseWheelEventListener(Object stg, Func1<Object,Double> cb) {
		return addEvent(event_mousewheel, cb);
	}

	public static Func0<Object> addFinegrainMouseWheelEventListener(Object stg, Func2<Object,Double,Double> cb) {
		return addEvent(event_finegrain_mousewheel, cb);
	}

	public static Func0<Object> addGestureListener(String name, Func5<Boolean,Integer,Double,Double,Double,Double> cb) {
		System.out.println("addGestureListener not implemented");
		return no_op;
	}

	public static boolean hittest(Object stg, double x, double y) {
		Clip cl = (Clip)stg;
		return cl.hittestCliped(x, y) && cl.hittest(x, y);
	}

	private static class TextClip extends Clip {
		Text textClip;

		StringProperty text = new StringPropertyBase("") {
			public Object getBean() {
				return null;
			}
			public String getName() {
				return "text";
			}
		};

		Boolean wordWrap;
		String font, slope;
		Integer weight, fill, backgroundColor;
		Double size, fillOpacity, letterspacing, backgroundOpacity, wrappingWidth, interlineSpacing;

		TextClip() {
			super();

			interlineSpacing = 0.0;

			textClip = new Text(text.getValue());
			container.getChildren().add(textClip);
		}

		public boolean hittest(double x, double y) {
			if (checkNodeHit(textClip, x, y))
				return true;
			return super.hittest(x, y);
		}

		String makeCssColor(Integer color, Double opacity) {
			return "rgba(" + ((color >> 16) & 255) + "," + ((color >> 8) & 255) + "," + (color & 255) + "," + (opacity) + ")" ;
		}

		protected String getCssStyle() {
			String style = "-fx-font-weight: " + weight + ";\n";
			style += "-fx-letterspacing: " + letterspacing + "px;\n";
			style += "background-color: " + makeCssColor(backgroundColor, backgroundOpacity) + ";\n";
			style += "-fx-line-spacing: " + Math.round(interlineSpacing) + "px;\n";
			style += "-fx-font-family: \"" + font + "\";\n";
			style += "-fx-font-size: " + size + "px;\n";

			return style;
		}

		protected void updateWidgetTextStyle() {
			this.textClip.setText(this.text.getValue());
			this.textClip.setStyle(this.getCssStyle());
			this.textClip.setFont(new Font(this.font, this.size));
			this.textClip.setFill(Color.rgb((fill >> 16) & 255, (fill >> 8) & 255, fill & 255, fillOpacity));
			this.textClip.setTranslateY(textClip.getBaselineOffset());
		}

		Object[] getTextMetrics() {
			return new Object[] { textClip.getBaselineOffset(), 0.1 * size, 0.15 * size };
		}

		void setTextAndStyle(String text, String font, double size, int weight,
							 String slope, int fill, double fillopacity, double letterspacing,
							 int bgColor, double bgOpacity) {
			this.text.setValue(text);
			this.font = font;
			this.size = size;
			this.weight = weight;
			this.slope = slope;
			this.fill = fill;
			this.fillOpacity = fillopacity;
			this.letterspacing = letterspacing;
			this.backgroundColor = bgColor;
			this.backgroundOpacity = bgOpacity;

			updateWidgetTextStyle();
		}

		public Double getWidth() {
			return textClip.getLayoutBounds().getWidth();
		}

		public Double getHeight() {
			return textClip.getLayoutBounds().getHeight();
		}

		void setWidth(Double width) {
			this.wrappingWidth = width;

			textClip.setWrappingWidth(width);
		}

		void setHeight(Double height) {}

		void setWordWrap(Boolean wordWrap) {
			this.wordWrap = wordWrap;

			updateWidgetTextStyle();
		}

		void setInterlineSpacing(Double spacing) {
			this.interlineSpacing = spacing;
			updateWidgetTextStyle();
		}
	}

	private static class TextInput extends TextClip {
		TextInputControl textField;

		private Boolean multiline, wordWrap, readOnly;
		private String type, textDirection, autoAlign;
		private Double width, height;
		private Integer tabIndex, maxChars;

		TextInput() {
			super();

			textField = null;
			multiline = wordWrap = readOnly = false;

			size = width = height = interlineSpacing = 0.0;
			backgroundOpacity = fillOpacity = 1.0;

			type = "text";
			textDirection = "ltr";
			autoAlign = "AutoAlignNone";

			fill = tabIndex = 0;
			backgroundColor = 0xffffff;
			weight = 400;
		}

		private String makeCssAlignment(String align) {
			if ("AutoAlignCenter".equals(align)) {
				return "center";
			} else if ("AutoAlignRight".equals(align)) {
				return "right";
			} else {
				return "left";
			}
		}

		private NodeOrientation getDirection(String direction) {
			return "rtl".equals(direction) ? NodeOrientation.RIGHT_TO_LEFT : NodeOrientation.LEFT_TO_RIGHT;
		}

		protected String getCssStyle() {
			String style = super.getCssStyle();
			style += "-fx-text-fill: " + makeCssColor(fill, fillOpacity) + ";\n";
			style += "-fx-wrap-text: " + wordWrap + ";\n";
			style += "text-alignment: " + makeCssAlignment(autoAlign) + ";\n";
			style += "direction: " + textDirection + ";\n";

			return style;
		}

		protected void updateWidgetTextStyle() {
			if (textField == null) {
				super.updateWidgetTextStyle();
				return ;
			}

			textField.setText(text.getValue());
			textField.setStyle(getCssStyle());
		}

		void setTextInputType(String type) {
			this.type = type;

			if (textField != null && type.equals("password"))
				setTextInput();
		}

		void setMultiline(Boolean multiline) {
			this.multiline = multiline;

			if (textField != null)
				setTextInput();
		}

		void setWidth(Double width) {
			this.width = width;

			if (textField != null) {
				textField.setPrefWidth(width);
			} else {
				super.setWidth(width);
			}
		}

		void setHeight(Double height) {
			this.height = height;

			if (textField != null) {
				textField.setPrefHeight(height);
			}
		}

		void requestFocus() {
			textField.requestFocus();
		}

		void setTextDirection(String direction) {
			this.textDirection = direction;
			updateWidgetTextStyle();
		}

		void setAutoAlign(String autoAlign) {
			this.autoAlign = autoAlign;
			updateWidgetTextStyle();
		}

		void setTabIndex(Integer index) {
			this.tabIndex = index;

			// TODO: Implement tab indexing
		}

		void setReadOnly(Boolean readOnly) {
			this.readOnly = readOnly;

			if (this.textField != null)
				this.textField.setEditable(!readOnly);
		}

		void setMaxChars(Integer max) {
			this.maxChars = max;
		}

		void setTextInput() {
			TextInputControl field = multiline ? new TextArea() : type.equals("password") ? new PasswordField() : new TextField();

			if (textField != null) {
				field.setText(textField.getText());
				field.setStyle(textField.getStyle());
				field.setEditable(!readOnly);
				field.setPrefWidth(this.width);
				field.setPrefHeight(this.height);
				textField.textProperty().unbindBidirectional(this.text);
				container.getChildren().remove(textField);
			}

			textField = field;
			container.getChildren().add(textField);
			textField.relocate(0.0, 0.0);
			textField.textProperty().bindBidirectional(this.text);

			textField.setMouseTransparent(false);
		}

		public Double getWidth() {
			if (textField != null)
				return this.width;
			else
				return super.getWidth();
		}

		public Double getHeight() {
			if (textField != null)
				return this.height;
			else
				return super.getHeight();
		}

		Object[] getTextMetrics() {
			textClip.setFont(new Font(this.font, this.size));

			return super.getTextMetrics();
		}

		Func0<Object> addTextListener(Func0<Object> listener) {
			final ChangeListener<String> changeListener = (observable, oldValue, newValue) -> {
				listener.invoke();
			};

			textField.textProperty().addListener(changeListener);
			return () -> {
				textField.textProperty().removeListener(changeListener);
				return null;
			};
		}

		private Func0<Object> addFocusListener(Func1<Object, Boolean> listener) {
			final ChangeListener<Boolean> changeListener = (observable, oldValue, newValue) -> listener.invoke(newValue);

			textField.focusedProperty().addListener(changeListener);
			return () -> {
				textField.focusedProperty().removeListener(changeListener);
				return null;
			};
		}

		Func0<Object> addFocusInListener(Func0<Object> listener) {
			return addFocusListener(value -> {
				if (value)
					listener.invoke();

				return null;
			});
		}

		Func0<Object> addFocusOutListener(Func0<Object> listener) {
			return addFocusListener(value -> {
				if (!value)
					listener.invoke();

				return null;
			});
		}

		String getText() {
			return text.getValue();
		}

		Integer getCursorPosition() {
			return textField.getCaretPosition();
		}

		boolean isFocused() {
			return textField.isFocused();
		}
	}

	public static Object makeTextField(String fontfamily) {
		return new TextInput();
	}

	public static Object setTextInput(Object stg) {
		TextInput tf = (TextInput)stg;
		tf.setTextInput();
		return null;
	}

	public static double getTextFieldWidth(Object tf) {
		TextClip tc = (TextClip)tf;
		return tc.getWidth();
	}

	public static double getTextFieldHeight(Object tf) {
		TextClip tc = (TextClip)tf;
		return tc.getHeight();
	}

	public static Object setTextFieldWidth(Object stg, double val) {
		TextClip tc = (TextClip)stg;
		tc.setWidth(val);
		return null;
	}

	public static Object setTextFieldHeight(Object stg, double val) {
		TextClip tc = (TextClip)stg;
		tc.setHeight(val);
		return null;
	}

	public static Object setTextFieldCropWords(Object stg, boolean crop) {
		// Impossible for this target
		return null;
	}

	public static Object setAdvancedText(Object stg,int a,int o,int e) {
		// Not required
		// System.out.println("setAdvancedText not implemented");
		return null;
	}

	public static Object setTextAndStyle(Object tf, String text, String font, double size, int weight,
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
					String hex = text.substring(i + 3, semi);
					int code = Integer.decode("0x" + hex);
					unicode.append((char) code);
					i = semi;
				}
			} else {
				unicode.append(c);
			}
		}

		String f = font;

		switch (font) {
			case "RobotoMedium":
				f = "Roboto";
				weight = 500;
				break;
			case "MaterialIcons":
				f = "Material Icons";
				break;
		}

		tc.setTextAndStyle(unicode.toString(), f, size, weight, slope, fill, fillopacity, letterspacing, bgColor, bgOpacity);
		return null;
	}

	public static Object setTextDirection(Object stg, String val) {
		TextInput ti = (TextInput)stg;
		ti.setTextDirection(val);
		return null;
	}

	public static int getNumLines(Object stg) {
		System.out.println("getNumLines not implemented");
		return 0;
	}

	public static int getCursorPosition(Object stg) {
		TextInput ti = (TextInput)stg;
		return ti.getCursorPosition();
	}

	public static boolean getFocus(Object stg) {
		return ((TextInput)stg).isFocused();
	}

	public static Object setFocus(Object stg, boolean val) {
		TextInput ti = (TextInput)stg;
		if (val)
			ti.requestFocus();
		else
			stage.requestFocus();
		return null;
	}

	public static String getContent(Object stg) {
		return ((TextInput)stg).getText();
	}

	public static Object setMultiline(Object stg, boolean val) {
		TextInput tc = (TextInput)stg;
		tc.setMultiline(val);
		return null;
	}

	public static Object setTextFieldInterlineSpacing(Object stg, double val) {
		TextInput ti = (TextInput)stg;
		ti.setInterlineSpacing(val);
		return null;
	}

	public static Object setWordWrap(Object stg, boolean val) {
		TextInput tc = (TextInput)stg;
		tc.setWordWrap(val);
		return null;
	}

	public static Object setTextInputType(Object stg, String type) {
		TextInput tc = (TextInput)stg;
		tc.setTextInputType(type);
		return null;
	}

	public static Object setReadOnly(Object stg, boolean val) {
		TextInput tc = (TextInput)stg;
		tc.setReadOnly(val);
		return null;
	}

	public static Object setAutoAlign(Object stg, String val) {
		TextInput ti = (TextInput)stg;
		ti.setAutoAlign(val);
		return null;
	}

	public static Object setTabIndex(Object stg, int val) {
		TextInput ti = (TextInput)stg;
		ti.setTabIndex(val);
		return null;
	}

	public static int getScrollV(Object stg) {
		System.out.println("getScrollV not implemented");
		return 0;
	}

	public static int getBottomScrollV(Object stg) {
		System.out.println("getBottomScrollV not implemented");
		return 0;
	}

	public static Object setScrollV(Object stg, int val) {
		System.out.println("setScrollV not implemented");
		return null;
	}

	public static Object setMaxChars(Object stg, int val) {
		TextInput ti = (TextInput)stg;
		ti.setMaxChars(val);
		return null;
	}

	public static Object[] getTextMetrics(Object tf) {
		TextInput ti = (TextInput)tf;
		return ti.getTextMetrics();
	}

	public static int getSelectionStart(Object stg) {
		System.out.println("getSelectionStart not implemented");
		return 0;
	}

	public static int getSelectionEnd(Object stg) {
		System.out.println("getSelectionEnd not implemented");
		return 0;
	}

	public static Object setSelection(Object stg, int start, int end) {
		System.out.println("setSelection not implemented");
		return null;
	}

	public static Object makeVideo(Func2<Object,Double,Double> mfn, Func1<Object, Boolean> pfn, Func1<Object, Double> dfn, Func1<Object, Double> posfn) {
		System.out.println("makeVideo not implemented");
		return new Clip();
	}

	public static Object pauseVideo(Object stg) {
		System.out.println("pauseVideo not implemented");
		return null;
	}

	public static Object resumeVideo(Object stg) {
		System.out.println("resumeVideo not implemented");
		return null;
	}

	public static Object closeVideo(Object stg) {
		System.out.println("closeVideo not implemented");
		return null;
	}

	public static Object playVideo(Object obj, String name, boolean pause) {
		System.out.println("playVideo not implemented");
		return null;
	}

	public static double getVideoPosition(Object stg) {
		System.out.println("getVideoPosition not implemented");
		return 0;
	}

	public static Object seekVideo(Object stg, double val) {
		System.out.println("seekVideo not implemented");
		return null;
	}

	public static Object setVideoVolume(Object stg, double val) {
		System.out.println("setVideoVolume not implemented");
		return null;
	}

	public static Object setVideoLooping(Object stg, boolean val) {
		System.out.println("setVideoLooping not implemented");
		return null;
	}

	public static Object setVideoControls(Object stg, Object[] info) {
		System.out.println("setVideoControls not implemented");
		return null;
	}

	public static Object setVideoSubtitle(Object tf, String text, String fontFamily, double fontSize, int fontWeight,
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing,
								  int backgroundColour, double backgroundOpacity, boolean alignBottom,
								  double bottomBorder, boolean scaleMode, double scaleModeMin, double scaleModeMax, boolean escapeHTML) {
		System.out.println("setVideoSubtitle not implemented");
		return null;
	}

	public static Object setVideoPlaybackRate(Object tf, Double rate) {
		System.out.println("setVideoPlaybackRate not implemented");
		return null;
	}

	public static Func0<Object> addStreamStatusListener(Object vid, Func1<Object,String> cb) {
		System.out.println("addStreamStatusListener not implemented");
		return no_op;
	}

	public static boolean isFullScreen() {
		System.out.println("isFullScreen not implemented");
		return false;
	}

	public static Object toggleFullScreen(Boolean fs) {
		System.out.println("toggleFullScreen not implemented");
		return null;
	}

	public static Object toggleFullWindow(Boolean fs) {
		System.out.println("toggleFullWindow not implemented");
		return null;
	}

	public static Func0<Object> onFullScreen(Func1<Object,Boolean> cb) {
		System.out.println("onFullScreen not implemented");
		return null;
	}

	public static Object setFullScreen(Boolean fs) {
		System.out.println("setFullScreen not implemented");
		return null;
	}

	public static Object setFullWindowTarget(Object stg) {
		System.out.println("setFullWindowTarget not implemented");
		return null;
	}

	public static Object resetFullWindowTarget() {
		System.out.println("resetFullWindowTarget not implemented");
		return null;
	}

	public static Object setFullScreenRectangle(double x, double y, double w, double h) {
		System.out.println("setFullScreenRectangle not implemented");
		return null;
	}

	public static Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,boolean i) {
		System.out.println("makeBevel not implemented");
		return null;
	}

	public static Object makeDropShadow(double angle,double distance,double radius,double spread,int color, double alpha,boolean inside) {
		double a = Math.PI * (90 - angle) / 180.0;
		double dx = Math.cos(a) * distance, dy = Math.sin(a) * distance;
		return new DropShadow(BlurType.GAUSSIAN, mkColor(color, alpha), radius * 2.5, 0.0, dx, dy);
	}

	public static Object makeBlur(double radius,double spread) {
		return new BoxBlur(radius, radius, (int)spread);
	}

	public static Object makeGlow(double a,double b,int c, double d,boolean e) {
		System.out.println("makeGlow not implemented");
		return null;
	}

	private static class CachedPicture {
		Image image;
		boolean loaded = false;
		boolean failed = false;
		TreeMap<Integer,Func2<Object,Double,Double>> event_metrics = new TreeMap<>();
		TreeMap<Integer,Func1<Object,String>> event_error = new TreeMap<>();

		CachedPicture(String url) {
			image = new Image(url, true);

			ChangeListener<Number> resize_cb = (observable, oldValue, newValue) -> {
				double w = image.getWidth();
				double h = image.getHeight();

				if (w == 0 || h == 0 || loaded)
					return;

				for (Func2<Object,Double,Double> cb : event_metrics.values())
					cb.invoke(w, h);

				loaded = true;
				event_metrics = null;
				event_error = null;
			};

			image.widthProperty().addListener(resize_cb);
			image.heightProperty().addListener(resize_cb);

			ChangeListener<Boolean> error_cb = (observable, oldValue, newValue) -> {
				if (!newValue || loaded)
					return;

				for (Func1<Object,String> cb : event_error.values())
					cb.invoke("load failed");

				loaded = failed = true;
				event_metrics = null;
				event_error = null;
			};

			image.errorProperty().addListener(error_cb);
		}
	}

	private static Hashtable<String,CachedPicture> img_cache = new Hashtable<>();

	private static class PictureClip extends Clip {
		ImageView view;
		CachedPicture pic;

		PictureClip(CachedPicture pic) {
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

	public static Object makePicture(String name,boolean cache,Func2<Object,Double,Double> metricsFn,Func1<Object,String> errorFn,boolean onlyDownload, String altText, Object[] headers) {
		CachedPicture img = img_cache.get(name);

		if (img == null) {
			img = new CachedPicture(name);
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

	public static Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1<Object,Object> n,Func1<Object,String> s) {
		System.out.println("makeCamera not implemented");
		Clip tmp = new Clip();
		return new Object[] { tmp, tmp };
	}

	public static Object startRecord(Object cm,String a,String o) {
		System.out.println("startRecord not implemented");
		return null;
	}

	public static Object stopRecord(Object cm) {
		System.out.println("stopRecord not implemented");
		return null;
	}

	private static class Graphics {
		Clip owner;
		Path path;

		Graphics(Clip owner) {
			this.owner = owner;
			path = new Path();
			path.setStroke(null);
			owner.container.setMouseTransparent(true);
			owner.container.getChildren().add(0,path);
		}
		boolean hittest(double x, double y) {
			return checkNodeHit(path, x, y);
		}
	}

	public static Object getGraphics(Object clip) {
		Clip cl = (Clip)clip;
		return cl.getGraphics();
	}
	private static Color mkColor(int color, double alpha) {
		return Color.rgb((color>>16)&0xff,(color>>8)&0xff,color&0xff,alpha);
	}

	public static Object beginFill(Object gr,int color,double alpha) {
		Graphics g = (Graphics)gr;
		g.path.setFill(mkColor(color, alpha));
		g.owner.container.setMouseTransparent(alpha < 0.1);
		return null;
	}

	public static Object setLineStyle(Object gr,double width,int color,double alpha) {
		Graphics g = (Graphics)gr;
		g.path.setStroke(mkColor(color, alpha));
		g.path.setStrokeWidth(width);
		return null;
	}

	public static Object makeMatrix(double width,double height,double rotation,double x,double y) {
		return new double[] { width, height, rotation, x, y };
	}

	private static Paint makeLinearGradient(Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		double[] mat = (double[])matrix;
		double a = Math.PI * mat[2] / 180.0;
		double dx = Math.cos(a) * mat[0], dy = Math.sin(a) * mat[0];
		double x1 = mat[3] + (mat[0] - dx) * 0.5, y1 = mat[4] + (mat[1] - dy) * 0.5;
		double x2 = mat[3] + (mat[0] + dx) * 0.5, y2 = mat[4] + (mat[1] + dy) * 0.5;
		List<Stop> stops = new ArrayList<>();
		for (int i = 0; i < color.length; i++)
			stops.add(new Stop((double)offset[i], mkColor((int)color[i], (double)alpha[i])));
		return new LinearGradient(x1,y1,x2,y2,false,CycleMethod.NO_CYCLE,stops);
	}

	private static Paint makeRadialGradient(Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		double[] mat = (double[])matrix;
		double x = mat[3] + mat[0] * 0.5, y = mat[4] + mat[1] * 0.5;
		double r = Math.sqrt((mat[0]*mat[0]+mat[1]*mat[1])/8.0);
		List<Stop> stops = new ArrayList<>();
		for (int i = 0; i < color.length; i++)
			stops.add(new Stop((double)offset[i], mkColor((int)color[i], (double)alpha[i])));
		return new RadialGradient(0,0,x,y,r,false,CycleMethod.NO_CYCLE,stops);
	}

	public static Object beginGradientFill(Object gr,Object[] color,Object[] alpha,Object[] offset,Object matrix,String type) {
		Graphics g = (Graphics)gr;
		Paint p;
		if ("radial".equals(type))
			p = makeRadialGradient(color,alpha,offset,matrix);
		else
			p = makeLinearGradient(color,alpha,offset,matrix);
		g.path.setFill(p);
		return null;
	}

	public static Object setLineGradientStroke(Object gr,Object[] color,Object[] alpha,Object[] offset,Object matrix) {
		Graphics g = (Graphics)gr;
		g.path.setStroke(makeLinearGradient(color,alpha,offset,matrix));
		return null;
	}

	public static Object moveTo(Object gr,double x,double y) {
		Graphics g = (Graphics)gr;
		MoveTo moveTo = new MoveTo();
		moveTo.setX(x);
		moveTo.setY(y);
		g.path.getElements().add(moveTo);
		return null;
	}

	public static Object lineTo(Object gr,double x,double y) {
		Graphics g = (Graphics)gr;
		LineTo lineTo = new LineTo();
		lineTo.setX(x);
		lineTo.setY(y);
		g.path.getElements().add(lineTo);
		return null;
	}

	public static Object curveTo(Object gr,double cx,double cy,double x, double y) {
		Graphics g = (Graphics)gr;
		QuadCurveTo quadTo = new QuadCurveTo();
		quadTo.setControlX(cx);
		quadTo.setControlY(cy);
		quadTo.setX(x);
		quadTo.setY(y);
		g.path.getElements().add(quadTo);
		return null;
	}

	public static Object endFill(Object gr) {
		return null;
	}

	private static AnimationTimer animation = new AnimationTimer() {
		public void handle(long now) {
			callbackDrawFrame(now / 1000000.0);
		}
	};

	private static HashSet<Func1<Object,Double>> animationCallbacks = new HashSet<>();

	private static void callbackDrawFrame(double now) {
		for (Func1<Object,Double> cb : animationCallbacks) {
			cb.invoke(now);
		}
	}

	public static Func0<Object> addDrawFrameEventListener(final Func1<Object,Double> cb) {
		animationCallbacks.add(cb);
		if (animationCallbacks.size() == 1)
			animation.start();

		return new Func0<Object>() {
			public Object invoke() {
				animationCallbacks.remove(cb);
				if (animationCallbacks.size() == 0)
					animation.stop();

				return null;
			}
		};
    }
}
