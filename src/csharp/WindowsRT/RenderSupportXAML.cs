using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Shapes;
using Windows.UI.Xaml.Media;
using Windows.Foundation;
using Windows.UI;
using System.Diagnostics;
using Windows.UI.Xaml.Documents;
using System.Globalization;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media.Imaging;
using Windows.UI.Text;
using Windows.UI.Input;
using Windows.Storage;
using Windows.UI.Core;
using Windows.System;
using Windows.Storage.Pickers;
using Windows.ApplicationModel.Activation;
using Windows.Storage.Streams;
using Windows.Graphics.Imaging;
using System.IO;
using System.Runtime.InteropServices.WindowsRuntime;

namespace Area9Innovation.Flow
{
	public sealed class RenderSupportXAML : RenderSupport
	{
		class Graphics
		{
			public readonly Clip parent;
			public readonly Canvas node;

			Windows.UI.Xaml.Shapes.Path cur_shape;
			PathGeometry cur_outline;
			PathFigure cur_figure;

			public Graphics(Clip parent)
			{
				this.parent = parent;
				this.node = new Canvas();
			}

			private void startShape(bool force_figure = false)
			{
				if (cur_shape == null)
				{
					cur_shape = new Windows.UI.Xaml.Shapes.Path();
					cur_shape.Data = cur_outline = new PathGeometry();
					node.Children.Add(cur_shape);
					cur_figure = null;
				}
				if (cur_figure == null || (force_figure && cur_figure.Segments.Count > 0))
				{
					cur_figure = new PathFigure();
					cur_outline.Figures.Add(cur_figure);
				}
			}
			private void endShape()
			{
				if (cur_shape == null)
					return;

				cur_shape = null;
				cur_outline = null;
				cur_figure = null;
			}

			public void moveTo(double x, double y)
			{
				startShape(true);

				cur_figure.StartPoint = new Point(x, y);
			}
			public void lineTo(double x, double y)
			{
				startShape();

				var seg = new LineSegment();
				seg.Point = new Point(x, y);
				cur_figure.Segments.Add(seg);
			}
			public void curveTo(double cx, double cy, double x, double y)
			{
				startShape();

				var seg = new QuadraticBezierSegment();
				seg.Point1 = new Point(cx, cy);
				seg.Point2 = new Point(x, y);
				cur_figure.Segments.Add(seg);
			}
			public void setLineStyle(double width, int color, double alpha, bool hint)
			{
				startShape();

				cur_shape.StrokeThickness = width;
				cur_shape.Stroke = new SolidColorBrush(mkColor(color, alpha));
			}
			public void endFill()
			{
				endShape();
			}
			public void beginFill(int color, double alpha)
			{
				startShape();

				cur_shape.Fill = new SolidColorBrush(mkColor(color, alpha));
			}
			private GradientBrush makeGradient(object[] color, object[] alpha, object[] offset, object matrix, string type)
			{
				GradientBrush brush;

				/*if (type == "radial")
				{

				}
				else*/
				{
					var gbrush = new LinearGradientBrush();
					gbrush.StartPoint = new Point(-1, 0);
					gbrush.EndPoint = new Point(1, 0);
					brush = gbrush;
				}

				brush.MappingMode = BrushMappingMode.Absolute;
				brush.RelativeTransform = (Transform)matrix;

				for (int i = 0; i < alpha.Length; i++)
				{
					var stop = new GradientStop();
					stop.Color = mkColor((int)color[i], (double)alpha[i]);
					stop.Offset = (double)offset[i];
					brush.GradientStops.Add(stop);
				}

				return brush;
			}
			public void beginGradientFill(object[] color, object[] alpha, object[] offset, object matrix, string type)
			{
				startShape();

				cur_shape.Fill = makeGradient(color, alpha, offset, matrix, type);
			}
			public void setLineGradientStroke(object[] color, object[] alpha, object[] offset, object matrix)
			{
				startShape();

				cur_shape.Stroke = makeGradient(color, alpha, offset, matrix, "");
			}
		}

		private static Color mkColor(int color, double alpha)
		{
			return Color.FromArgb((byte)(alpha*255), (byte)((color >> 16) & 0xff), (byte)((color >> 8) & 0xff), (byte)(color & 0xff));
		}

		class Clip : IDisposable
		{
			public readonly Canvas node;

			protected readonly RenderSupportXAML owner;
			Clip cparent;
			Graphics cgraphics;
			UIElement ctop;
			List<Clip> children;

			TransformGroup ctransforms;
			ScaleTransform cscale;
			RotateTransform crotation;

			double cx, cy, csx, csy, crot, calpha;
			bool cvisible;

			Canvas scroller;
			double scrollw, scrollh;
			TranslateTransform scroll_trf;

			public bool isMask;

			private bool is_dead;
			public bool isDead
			{
				get { return is_dead; }
			}

			public Clip parent
			{
				get { return cparent; }
				set
				{
					if (cparent != value)
					{
						if (cparent != null)
						{
							cparent.children.Remove(this);
							cparent.node.Children.Remove(this.top_node);
						}
						cparent = value;
						if (cparent != null)
						{
							cparent.children.Add(this);
							cparent.node.Children.Add(this.top_node);
						}
					}
				}
			}
			protected UIElement top_node
			{
				get { return ctop; }
				set
				{
					if (cparent != null)
					{
						int idx = cparent.node.Children.IndexOf(ctop);
						cparent.node.Children[idx] = value;
					}
					value.RenderTransform = ctop.RenderTransform;
					ctop.RenderTransform = null;
					Canvas.SetLeft(ctop, 0);
					Canvas.SetTop(ctop, 0);
					ctop.Visibility = Visibility.Visible;
					ctop.Opacity = 1.0;
					Canvas.SetLeft(value, cx);
					Canvas.SetTop(value, cy);
					value.Visibility = cvisible ? Visibility.Visible : Visibility.Collapsed;
					value.Opacity = calpha;
					ctop = value;
				}
			}
			protected ScaleTransform scale
			{
				get
				{
					if (cscale == null)
					{
						if (ctransforms == null)
							ctop.RenderTransform = ctransforms = new TransformGroup();
						cscale = new ScaleTransform();
						ctransforms.Children.Insert(0, cscale);
					}
					return cscale;
				}
			}
			protected RotateTransform rotation
			{
				get
				{
					if (crotation == null)
					{
						if (ctransforms == null)
							ctop.RenderTransform = ctransforms = new TransformGroup();
						crotation = new RotateTransform();
						ctransforms.Children.Add(crotation);
					}
					return crotation;
				}
			}
			public Graphics graphics
			{
				get
				{
					if (cgraphics == null)
					{
						cgraphics = new Graphics(this);
						node.Children.Insert(0, cgraphics.node);
					}
					return cgraphics;
				}
			}
			public double x
			{
				get { return cx; }
				set { Canvas.SetLeft(ctop, cx = value); }
			}
			public double y
			{
				get { return cy; }
				set { Canvas.SetTop(ctop, cy = value); }
			}
			public bool visible
			{
				get { return cvisible; }
				set { ctop.Visibility = (cvisible = value) ? Visibility.Visible : Visibility.Collapsed; }
			}
			public double alpha
			{
				get { return calpha; }
				set { ctop.Opacity = calpha = value; }
			}
			public virtual double scalex
			{
				get { return csx; }
				set { scale.ScaleX = csx = value; }
			}
			public virtual double scaley
			{
				get { return csy; }
				set { scale.ScaleY = csy = value; }
			}
			public double rotate
			{
				get { return crot; }
				set { rotation.Angle = crot = value; }
			}

			public Clip(RenderSupportXAML owner, Canvas obj = null)
			{
				this.owner = owner;
				ctop = node = (obj == null) ? new Canvas() : obj;
				children = new List<Clip>();
				cvisible = true;
				calpha = 1.0;
				is_dead = false;
			}

			public virtual void Dispose()
			{
				is_dead = true;
			}

			public bool isReallyVisible()
			{
				return cvisible && calpha > 0 && (parent == null ? this == owner.stage : parent.isReallyVisible());
			}

			public void setScrollRect(double x, double y, double w, double h)
			{
				if (scroller == null)
				{
					top_node = scroller = new Canvas();
					scroll_trf = new TranslateTransform();
					node.RenderTransform = scroll_trf;
					scroller.Children.Add(node);
				}

				scroll_trf.X = -x;
				scroll_trf.Y = -y;

				RectangleGeometry clip = scroller.Clip;

				if (w < 0) w = 0;
				if (h < 0) h = 0;

				if (clip == null || scrollw != w || scrollh != h)
				{
					if (clip == null)
						scroller.Clip = clip = new RectangleGeometry();

					clip.Rect = new Rect(0, 0, scrollw = w, scrollh = h);
				}
			}
			public virtual Func0 addEventListener(string name, Event0 cb)
			{
				return no_op;
			}
			public virtual void setFocus(bool set) { }
		}

		delegate void Event0();
		static object no_op() { return null; }

		Event0 wrapCallback(Func0 cb) {
			return () => {
				try {
					cb();
				} catch (Exception e) {
					Debug.WriteLine(e);
				}
			};
		}

		delegate void KeyEvent(string key, bool ctrl, bool shift, bool alt, bool meta, int code, Func0 preventDefault);

		KeyEvent wrapKeyCallback(Func7 cb) {
			return (string key, bool ctrl, bool shift, bool alt, bool meta, int code, Func0 preventDefault) => {
				try	{
					cb(key, ctrl, shift, alt, meta, code, preventDefault);
				} catch (Exception e) {
					Debug.WriteLine(e);
				}
			};
		}

		delegate void GestureEvent(ref bool handled, int state, double x, double y, double dx, double dy);

		GestureEvent wrapGestureCallback(Func5 cb) {
			return (ref bool handled, int state, double x, double y, double dx, double dy) => {
				try	{
					handled = handled || (bool)cb(state, x, y, dx, dy);
				} catch (Exception e) {
					Debug.WriteLine(e);
				}
			};
		}

		Uri base_uri;
		MediaCache media;

		Clip stage;
		Event0 event_resize, event_mousemove, event_mousedown, event_mouseup;
		KeyEvent event_keydown, event_keyup;
		GestureEvent event_pan, event_pinch, event_swipe;
		Point mouse_point;
		HashSet<DependencyObject> mouse_hits;

		GestureRecognizer gesture_recognizer = new GestureRecognizer();

		struct FontSpec
		{
			public FontFamily font;
			public FontStyle style;

			public FontSpec(FontFamily font = null, FontStyle style = FontStyle.Normal)
			{
				this.font = font; this.style = style;
			}
		}

		static Dictionary<string, FontSpec> known_fonts = new Dictionary<string,FontSpec>();

		public RenderSupportXAML(Canvas root, Uri base_uri, MediaCache media)
		{
			this.base_uri = base_uri;
			this.media = media;

			stage = new Clip(this, root);

			root.Loaded += Node_Loaded;
			root.Unloaded += Node_Unloaded;

			root.SizeChanged += (sender, e) => {
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
				{
					if (event_resize != null) event_resize();
				}
			};

			gesture_recognizer.GestureSettings =
				GestureSettings.ManipulationTranslateX | GestureSettings.ManipulationTranslateY |
				GestureSettings.ManipulationScale | GestureSettings.ManipulationMultipleFingerPanning;

			gesture_recognizer.ManipulationStarted += Gesture_recognizer_ManipulationStarted;
			gesture_recognizer.ManipulationUpdated += Gesture_recognizer_ManipulationUpdated;
			gesture_recognizer.ManipulationCompleted += Gesture_recognizer_ManipulationCompleted;

			var window = CoreWindow.GetForCurrentThread();
			window.KeyDown += window_KeyDown;
			window.KeyUp += window_KeyUp;

			var content = Window.Current.Content;
			content.AddHandler(UIElement.PointerMovedEvent, new PointerEventHandler(Throttle(Stage_PointerMoved, TimeSpan.FromMilliseconds(30))), true);
			content.AddHandler(UIElement.PointerPressedEvent, new PointerEventHandler(Stage_PointerPressed), true);
			content.AddHandler(UIElement.PointerReleasedEvent, new PointerEventHandler(Stage_PointerReleased), true);
			content.AddHandler(UIElement.PointerCanceledEvent, new PointerEventHandler(Stage_PointerCanceled), true);
		}

		PointerEventHandler Throttle(PointerEventHandler handler, TimeSpan throttle)
		{
			bool throttling = false;
			return (s, e) =>
			{
				if (throttling) return;
				handler(s, e);
				throttling = true;
				Task.Delay(throttle).ContinueWith(_ => throttling = false);
			};
		}

		private void Node_Loaded(object sender, RoutedEventArgs e)
		{
		}

		private void Node_Unloaded(object sender, RoutedEventArgs e)
		{
		}

		private void window_KeyDown(CoreWindow sender, KeyEventArgs args)
		{
			invokeKeyEvent(event_keydown, args);
		}

		private void window_KeyUp(CoreWindow sender, KeyEventArgs args)
		{
			invokeKeyEvent(event_keyup, args);
		}

		private void invokeKeyEvent(KeyEvent cb, KeyEventArgs args)
		{
			if (cb == null)
				return;

			bool ctrl = isDown(VirtualKey.Control);
			bool shift = isDown(VirtualKey.Shift);
			bool alt = isDown(VirtualKey.Menu);

			var key = args.VirtualKey;
			string keystr = null;
			int code = 0;
			bool meta = false;

			if (key >= VirtualKey.A && key <= VirtualKey.Z)
			{
				code = 65 + key - VirtualKey.A;
				if (shift && !ctrl && !alt)
					keystr = new string(new char[] { (char)('A' + key - VirtualKey.A) });
				else
					keystr = new string(new char[] { (char)('a' + key - VirtualKey.A) });
			}
			else if (key >= VirtualKey.Number0 && key <= VirtualKey.Number9)
			{
				code = 48 + key - VirtualKey.Number0;
				keystr = new string(new char[] { (char)('0' + key - VirtualKey.Number0) });
			}
			else if (key >= VirtualKey.NumberPad0 && key <= VirtualKey.NumberPad9)
			{
				code = 96 + key - VirtualKey.NumberPad0;
				keystr = new string(new char[] { (char)('0' + key - VirtualKey.NumberPad0) });
			}
			else if (key >= VirtualKey.F1 && key <= VirtualKey.F24)
			{
				code = 112 + key - VirtualKey.F1;
				keystr = "F" + (key - VirtualKey.F1 + 1);
			}
			else
			{
				switch (key)
				{
					case VirtualKey.Back:
						code = 8; keystr = "backspace"; break;
					case VirtualKey.Tab:
						code = 9; keystr = "tab"; break;
					case VirtualKey.Enter:
						code = 13; keystr = "enter"; break;
					case VirtualKey.Shift:
					case VirtualKey.LeftShift:
					case VirtualKey.RightShift:
						code = 16; keystr = "shift"; shift = true; break;
					case VirtualKey.Control:
					case VirtualKey.LeftControl:
					case VirtualKey.RightControl:
						code = 17; keystr = "ctrl"; ctrl = true; break;
					case VirtualKey.Escape:
						code = 27; keystr = "esc"; break;
					case VirtualKey.Space:
						code = 32; keystr = " "; break;
					case VirtualKey.PageUp:
						code = 33; keystr = "page up"; break;
					case VirtualKey.PageDown:
						code = 34; keystr = "page down"; break;
					case VirtualKey.End:
						code = 35; keystr = "end"; break;
					case VirtualKey.Home:
						code = 36; keystr = "home"; break;
					case VirtualKey.Left:
						code = 37; keystr = "left"; break;
					case VirtualKey.Up:
						code = 38; keystr = "up"; break;
					case VirtualKey.Right:
						code = 39; keystr = "right"; break;
					case VirtualKey.Down:
						code = 40; keystr = "down"; break;
					case VirtualKey.Insert:
						code = 45; keystr = "insert"; break;
					case VirtualKey.Delete:
						code = 46; keystr = "delete"; break;
					case VirtualKey.Multiply:
						code = 106; keystr = "*"; break;
					case VirtualKey.Add:
						code = 107; keystr = "+"; break;
					case VirtualKey.Subtract:
						code = 108; keystr = "-"; break;
					case VirtualKey.Decimal:
						code = 110; keystr = "."; break;
					case VirtualKey.Divide:
						code = 111; keystr = "/"; break;
				}
			}

			if (keystr != null)
				cb(keystr, ctrl, shift, alt, meta, code, () => {});
		}

		private static bool isDown(Windows.System.VirtualKey key)
		{
			var window = Window.Current.CoreWindow;
			return (window.GetKeyState(key) & CoreVirtualKeyStates.Down) == CoreVirtualKeyStates.Down;
		}

		public static void registerFont(string id, string url, FontStyle style)
		{
			known_fonts[id] = new FontSpec(new FontFamily(url), style);
		}

		private static FontSpec findFont(string id)
		{
			FontSpec rv;
			if (!known_fonts.TryGetValue(id, out rv))
				rv.font = new FontFamily(id);
			return rv;
		}

		private void setMousePoint(PointerPoint point)
		{
			if (mouse_point == point.Position)
				return;

			mouse_point = point.Position;
			mouse_hits = null;
		}

		private void Stage_PointerMoved(object sender, PointerRoutedEventArgs e)
		{
			IList<PointerPoint> points = e.GetIntermediatePoints(stage.node);

			setMousePoint(points.Last());

			gesture_recognizer.ProcessMoveEvents(points);

			if (event_mousemove != null)
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_mousemove();
		}

		private void Stage_PointerPressed(object sender, PointerRoutedEventArgs e)
		{
			var currentPoint = e.GetCurrentPoint(stage.node);

			setMousePoint(currentPoint);

			//if (!e.Handled)
			//	stage.node.CapturePointer(e.Pointer);

			gesture_recognizer.ProcessDownEvent(currentPoint);

			if (event_mousedown != null) {
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_mousedown();
			}
		}

		private void Stage_PointerReleased(object sender, PointerRoutedEventArgs e)
		{
			var currentPoint = e.GetCurrentPoint(stage.node);

			setMousePoint(currentPoint);

			//stage.node.ReleasePointerCapture(e.Pointer);

			gesture_recognizer.ProcessUpEvent(currentPoint);

			if (event_mouseup != null) {
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_mouseup();
			}
		}

		private void Stage_PointerCanceled(object sender, PointerRoutedEventArgs e)
		{
			gesture_recognizer.CompleteGesture();

			if (event_mouseup != null)
			{
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_mouseup();
			}
		}

		private void Gesture_recognizer_ManipulationStarted(GestureRecognizer sender, ManipulationStartedEventArgs args)
		{
			if (event_pan != null)
			{
				bool handled = false;
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_pan(ref handled, 0, args.Position.X, args.Position.Y, 0, 0);
			}
		}

		private void Gesture_recognizer_ManipulationUpdated(GestureRecognizer sender, ManipulationUpdatedEventArgs args)
		{
			if (event_pan != null)
			{
				bool handled = false;
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_pan(ref handled, 1, args.Position.X, args.Position.Y, args.Delta.Translation.X, args.Delta.Translation.Y);
			}
		}

		private void Gesture_recognizer_ManipulationCompleted(GestureRecognizer sender, ManipulationCompletedEventArgs args)
		{
			if (event_pan != null)
			{
				bool handled = false;
				using (var ctx = new FlowRuntime.DeferredContext(runtime))
					event_pan(ref handled, 2, args.Position.X, args.Position.Y, 0, 0);
			}
		}

		public override Object getStage()
		{
			return stage;
		}
		public override double getStageWidth()
		{
			return stage.node.ActualWidth;
		}
		public override double getStageHeight()
		{
			return stage.node.ActualHeight;
		}
		public override Object setHitboxRadius(double val)
		{
			return null;
		}
		public override Object setWindowTitle(String title)
		{
			return null;
		}
		public override Object setFavIcon(String url)
		{
			return null;
		}
		public override int getScreenPixelColor(double x, double y)
		{
			return 0;
		}
		public override Object enableResize()
		{
			return null;
		}
		public override Object makeClip()
		{
			return new Clip(this);
		}
		public override Object currentClip()
		{
			return stage;
		}
		public override Object addFilters(Object stg, Object[] filters)
		{
			return null;
		}
		public override Object setAccessAttributes(Object stg, Object[] attrs)
		{
			return null;
		}
		public override Object setAccessCallback(Object stg, Func0 fn)
		{
			return null;
		}
		public override Object addChild(Object stg, Object child)
		{
			Clip cclip = (Clip)child;
			if (!cclip.isMask)
				cclip.parent = ((Clip)stg);
			return null;
		}
		public override Object removeChild(Object stg, Object child)
		{
			Clip cclip = (Clip)child;
			if (cclip.parent != stg && (!cclip.isMask || cclip.parent != null))
				throw new Exception("Invalid parent in removeChild");
			cclip.parent = null;
			return null;
		}
		public override Object setClipMask(Object stg, Object mask)
		{
			Clip cclip = (Clip)mask;
			cclip.isMask = true;
			cclip.parent = null;
			return null;
		}
		public override Object setClipCallstack(Object stg, Object stack)
		{
			return null;
		}
		public override double getMouseX(Object stg)
		{
			Clip clip = (Clip)stg;
			if (clip == stage)
				return mouse_point.X;

			GeneralTransform gt = stage.node.TransformToVisual(clip.node);
			return gt.TransformPoint(mouse_point).X;
		}
		public override double getMouseY(Object stg)
		{
			Clip clip = (Clip)stg;
			if (clip == stage)
				return mouse_point.Y;

			GeneralTransform gt = stage.node.TransformToVisual(clip.node);
			return gt.TransformPoint(mouse_point).Y;
		}
		public override bool getClipVisible(Object stg)
		{
			return ((Clip)stg).visible;
		}
		public override Object setClipVisible(Object stg, bool on)
		{
			((Clip)stg).visible = on;
			return null;
		}
		public override Object setClipX(Object stg, double val)
		{
			((Clip)stg).x = val;
			return null;
		}
		public override Object setClipY(Object stg, double val)
		{
			((Clip)stg).y = val;
			return null;
		}
		public override Object setClipScaleX(Object stg, double val)
		{
			((Clip)stg).scalex = val;
			return null;
		}
		public override Object setClipScaleY(Object stg, double val)
		{
			((Clip)stg).scaley = val;
			return null;
		}
		public override Object setClipAlpha(Object stg, double val)
		{
			((Clip)stg).alpha = val;
			return null;
		}
		public override Object setClipRotation(Object stg, double val)
		{
			((Clip)stg).rotate = val;
			return null;
		}
		public override Object setScrollRect(Object stg, double x, double y, double w, double h)
		{
			((Clip)stg).setScrollRect(x, y, w, h);
			return null;
		}
		public override String getCursor()
		{
			return null;
		}
		public override Object setCursor(String val)
		{
			return null;
		}
		public override Func0 addEventListener(Object stg, String name, Func0 fn)
		{
			Clip clip = (Clip)stg;
			var cb = wrapCallback(fn);

			if (name == "resize")
			{
				event_resize += cb;
				return () => { event_resize -= cb; return null; };
			}
			else if (name == "mousemove")
			{
				event_mousemove += cb;
				return () => { event_mousemove -= cb; return null; };
			}
			else if (name == "mouseup")
			{
				event_mouseup += cb;
				return () => { event_mouseup -= cb; return null; };
			}
			else if (name == "mousedown")
			{
				event_mousedown += cb;
				return () => { event_mousedown -= cb; return null; };
			}
			else if (name == "mouseenter" || name == "rollover")
			{
				PointerEventHandler pcb = (object sender, PointerRoutedEventArgs e) =>
				{
					setMousePoint(e.GetCurrentPoint(stage.node));
					using (var ctx = new FlowRuntime.DeferredContext(runtime))
						cb();
				};
				clip.node.PointerEntered += pcb;
				return () => { clip.node.PointerEntered -= pcb; return null; };
			}
			else if (name == "mouseleave" || name == "rollout")
			{
				PointerEventHandler pcb = (object sender, PointerRoutedEventArgs e) =>
				{
					setMousePoint(e.GetCurrentPoint(stage.node));
					using (var ctx = new FlowRuntime.DeferredContext(runtime))
						cb();
				};
				clip.node.PointerExited += pcb;
				return () => { clip.node.PointerExited -= pcb; return null; };
			}
			else
				return clip.addEventListener(name, cb);
		}
		public override Func0 addKeyEventListener(Object stg, String name, Func7 fn)
		{
			var cb = wrapKeyCallback(fn);

			if (name == "keydown")
			{
				event_keydown += cb;
				return () => { event_keydown -= cb; return null; };
			}
			else if (name == "keyup")
			{
				event_keyup += cb;
				return () => { event_keyup -= cb; return null; };
			}

			return no_op;
		}
		public override Func0 addMouseWheelEventListener(Object stg, Func1 cb)
		{
			return no_op;
		}
		public override Func0 addFinegrainMouseWheelEventListener(Object stg, Func2 cb)
		{
			return no_op;
		}
		public override Func0 addGestureListener(String name, Func5 fn)
		{
			var cb = wrapGestureCallback(fn);

			if (name == "pan")
			{
				event_pan += cb;
				return () => { event_pan -= cb; return null; };
			}
			else if (name == "pinch")
			{
				event_pinch += cb;
				return () => { event_pinch -= cb; return null; };
			}
			else if (name == "swipe")
			{
				event_swipe += cb;
				return () => { event_swipe -= cb; return null; };
			}

			return no_op;
		}

		private HashSet<DependencyObject> computeHits(Point pt)
		{
			GeneralTransform gt = stage.node.TransformToVisual(Window.Current.Content as UIElement);
			Point gp = gt.TransformPoint(pt);

			var hit = VisualTreeHelper.FindElementsInHostCoordinates(gp, stage.node, true);
			var result = new HashSet<DependencyObject>();

			foreach (var node in hit)
			{
				DependencyObject cur = node;

				while (cur != null)
				{
					if (result.Contains(cur))
						break;

					result.Add(cur);
					cur = VisualTreeHelper.GetParent(cur);
				}
			}

			return result;
		}

		public override bool hittest(Object stg, double x, double y)
		{
			Clip clip = (Clip)stg;
			Point pt = new Point(x, y);
			HashSet<DependencyObject> hits;

			if (pt == mouse_point)
			{
				if (mouse_hits == null)
					mouse_hits = computeHits(pt);

				hits = mouse_hits;
			}
			else
				hits = computeHits(pt);

			return hits.Contains(clip.node) && clip.isReallyVisible();
		}

		private struct HtmlFormat
		{
			public double size;
			public FontSpec font;

			public double alpha;
			public Brush brush;

			public InlineCollection sequence;
			Run current;

			public void setFont(string family)
			{
				font = findFont(family);
			}
			public void setColor(int fill)
			{
				brush = new SolidColorBrush(mkColor(fill, alpha));
			}

			private void pushText(string str)
			{
				if (current == null)
				{
					current = new Run();
					current.FontSize = size;
					current.FontFamily = font.font;
					current.FontStyle = font.style;
					current.Foreground = brush;
					sequence.Add(current);
				}

				current.Text += str;
			}

			private void flush()
			{
				current = null;
			}

			private void parseEntity(string str, ref int pos)
			{
				int start = pos;
				int len = str.Length;
				while (pos < len && str[pos] != ';')
					pos++;

				if (pos >= len || pos - start < 2)
				{
					pushText(str.Substring(start-1));
					return;
				}

				string code = str.Substring(start, pos++ - start);

				if (code[0] == '#')
				{
					int codeval;

					if (code[1] == 'x')
					{
						if (int.TryParse(code.Substring(2), NumberStyles.HexNumber, null, out codeval))
						{
							pushText(new string((char)codeval, 1));
							return;
						}
					}
					else
					{
						if (int.TryParse(code.Substring(1), NumberStyles.Integer, null, out codeval))
						{
							pushText(new string((char)codeval, 1));
							return;
						}
					}
				}
				else
				{
					string outv = null;
					if (code == "nbsp")
						outv = "\u00a0";
					else if (code == "lt")
						outv = "<";
					else if (code == "gt")
						outv = ">";
					else if (code == "amp")
						outv = "&";
					else if (code == "quot")
						outv = "\"";
					else if (code == "apos")
						outv = "'";

					if (outv != null)
					{
						pushText(outv);
						return;
					}
				}

				pushText(str.Substring(start-1, pos-start));
			}

			private bool parseHtmlTag(string str, ref int pos, out bool term1, out bool term2,
				out string tag,	out Dictionary<string,string> attrs)
			{
				int len = str.Length;
				term1 = term2 = false;
				tag = null;
				attrs = null;

			    // < [space*]
				while (pos < len && char.IsWhiteSpace(str[pos])) pos++;

				// < space* [/?]
				if (pos < len && str[pos] == '/') {
					term1 = true;
					pos++;
				}

				// < space* /? [space*]
				while (pos < len && char.IsWhiteSpace(str[pos])) pos++;

				// < space* /? space* [tag-name]
				int tstart = pos;
				while (pos < len && char.IsLetter(str[pos])) pos++;

				if (pos == tstart)
					return false;

				tag = str.Substring(tstart, pos - tstart);

				// < space* /? space* tag-name [attr=value* /? >]
				for (;;) {
					while (pos < len && char.IsWhiteSpace(str[pos])) pos++;

					if (pos >= len) return false;
					char cur = str[pos++];

					if (cur == '>') {
						return true;
					} else if (cur == '/' && !term1) {
						term2 = true;
					} else if (char.IsLetter(cur) && !term1) {
						// [attr-name]
						int astart = pos-1;
						while (pos < len && char.IsLetter(str[pos])) pos++;
						string attr = str.Substring(astart, pos - astart);

						// attr-name [space*]
						while (pos < len && char.IsWhiteSpace(str[pos])) pos++;
						// attr-name space* [=]
						if (pos >= len || str[pos++] != '=')
							return false;
						// attr-name space* = [space*]
						while (pos < len && char.IsWhiteSpace(str[pos])) pos++;
						// attr-name space* = space* ['value']
						if (pos >= len)
							return false;
						char quote = str[pos++];
						if (quote != '\'' && quote != '"')
							return false;

						int vstart = pos;
						while (pos < len && str[pos] != quote) pos++;
						if (pos >= len)
							return false;
						string val = str.Substring(vstart, pos++ - vstart);

						if (attrs == null)
							attrs = new Dictionary<string, string>();
						attrs[attr] = val;
					} else {
						return false;
					}
				}
			}

			public void parse(string str)
			{
				int pos = 0;
				List<string> open_tags = new List<string>();

				parseRec(str, ref pos, open_tags);
				flush();
			}

			private string parseRec(string str, ref int pos, List<string> open_tags)
			{
				int len = str.Length;
				while (pos < len)
				{
					char cur = ' ';
					int pstart = pos;

					while (pos < len)
					{
						cur = str[pos++];

						if (cur == '\n' || cur == '<' || cur == '&')
						{
							pos--;
							break;
						}
					}

					if (pos > pstart)
						pushText(str.Substring(pstart, pos - pstart));

					if (cur == '\n')
					{
						pos++;
						flush();
						sequence.Add(new LineBreak());
					}
					else if (cur == '&')
					{
						pos++;
						parseEntity(str, ref pos);
					}
					else if (cur == '<')
					{
						bool term1, term2;
						string tag;
						Dictionary<string, string> attrs;

						pstart = ++pos;

						if (!parseHtmlTag(str, ref pos, out term1, out term2, out tag, out attrs))
						{
							pushText("<");
							pos = pstart;
						}

						if (term1)
						{
							if (open_tags.Contains(tag))
								return tag;
							continue;
						}

						flush();
						HtmlFormat new_format = this; // by value copy
						string val;

						if (tag == "font") {
							if (attrs != null && attrs.TryGetValue("face", out val))
								new_format.setFont(val);
							if (attrs != null && attrs.TryGetValue("size", out val))
								double.TryParse(val, out new_format.size);
							if (attrs != null && attrs.TryGetValue("color", out val) && val[0] == '#') {
								int colorv;
								if (int.TryParse(val.Substring(1), NumberStyles.Integer, null, out colorv))
									new_format.setColor(colorv);
							}
						} else if (tag == "u") {
							var ul = new Underline();
							sequence.Add(ul);
							new_format.sequence = ul.Inlines;
						} else if (tag == "a") {
							var ul = new Underline();
							sequence.Add(ul);
							new_format.sequence = ul.Inlines;
							new_format.setColor(0x0000FF);
						} else if (tag == "br") {
							sequence.Add(new LineBreak());
							continue;
						} else if (tag == "p") {
							if (sequence.Count > 0 && !(sequence[sequence.Count-1] is LineBreak))
								sequence.Add(new LineBreak());
						}

						if (!term1 && !term2) {
							int depth = open_tags.Count;
							bool newv = !open_tags.Contains(tag);
							if (newv)
								open_tags.Add(tag);

							var rtag = new_format.parseRec(str, ref pos, open_tags);

							new_format.flush();

							open_tags.RemoveRange(depth, open_tags.Count-depth);

							if (tag == "p" && sequence.Count > 0 && !(sequence[sequence.Count-1] is LineBreak))
								sequence.Add(new LineBreak());
							if (rtag != tag)
								return rtag;
						}
					}
				}

				return "";
			}
		}

		class TextClip : Clip
		{
			private bool size_set = false;
			public Size auto_size;

			private bool focused = false;
			private Event0 event_focusin, event_focusout, event_change;

			private Impl impl_;
			public Impl impl
			{
				get { return impl_; }
				private set
				{
					if (impl_ != null)
						node.Children.Remove(impl_.control);
					impl_ = value;
					node.Children.Add(impl_.control);
				}
			}

			public TextClip(RenderSupportXAML owner) : base(owner)
			{
				impl = new ImplRO(this);
			}

			public override Func0 addEventListener(string name, Event0 cb)
			{
				if (name == "focusin")
				{
					event_focusin += cb;
					return () => { event_focusin -= cb; return null; };
				}
				else if (name == "focusout")
				{
					event_focusout += cb;
					return () => { event_focusout -= cb; return null; };
				}
				else if (name == "change")
				{
					event_change += cb;
					return () => { event_change -= cb; return null; };
				}

				return base.addEventListener(name, cb);
			}

			private void onGotFocus(object sender, RoutedEventArgs e)
			{
				focused = true;
				if (event_focusin != null && !isDead)
					using (var ctx = new FlowRuntime.DeferredContext(owner.runtime))
						event_focusin();
			}

			private void onLostFocus(object sender, RoutedEventArgs e)
			{
				focused = false;
				if (event_focusout != null && !isDead)
					using (var ctx = new FlowRuntime.DeferredContext(owner.runtime))
						event_focusout();
			}

			private void notifyChange()
			{
				if (event_change != null && !isDead)
					using (var ctx = new FlowRuntime.DeferredContext(owner.runtime))
						event_change();
			}

			private void measure()
			{
				if (!size_set)
				{
					impl.control.Measure(new Size(Double.PositiveInfinity, Double.PositiveInfinity));
					auto_size.Width = impl.control.ActualWidth;
					auto_size.Height = impl.control.ActualHeight;
					//auto_size = impl.control.DesiredSize;
				}
			}

			private static FlowDirection parseTextDirection(string val)
			{
				if (val == "RTL" or val == "rtl") return FlowDirection.RightToLeft;
				return FlowDirection.LeftToRight;
			}

			private static TextAlignment parseAutoAlign(string val)
			{
				if (val == "AutoAlignLeft")
					return TextAlignment.Left;
				else if (val == "AutoAlignRight")
					return TextAlignment.Right;
				else if (val == "AutoAlignCenter")
					return TextAlignment.Center;
				else if (val == "AutoAlignNone")
					return TextAlignment.Left;

				return TextAlignment.Left;
			}

			public abstract class Impl
			{
				public readonly TextClip owner;

				public abstract FrameworkElement control { get; }

				public Impl(TextClip owner)
				{
					this.owner = owner;
				}

				public virtual void setTextInput() { }
				public abstract void setTextAndStyle(string tstr, string font, double size, int weight, string slope, int fill, double fillopacity, int letterspacing, int bgcolor, double bgopacity);
				public virtual void setTextDirection(string val) {}
				public virtual void getTextMetrics(out double ascent, out double descent, out double leading)
				{
					ascent = descent = leading = 10;
				}
				public virtual int getNumLines() { return 1; }
				public virtual int getCursorPosition() { return 0; }
				public virtual void setFocus(bool val) {}
				public abstract string getContent();
				public virtual void setMultiline(bool val) {}
				public virtual void setWordWrap(bool val) {}
				public virtual void setReadOnly(bool val) {}
				public virtual void setAutoAlign(string val) {}
				public virtual void setTextInputType(string mode) {}
				public virtual void setMaxChars(int val) {}
				public virtual void setTabIndex(int val) {}
				public virtual int getSelectionStart() { return 0; }
				public virtual int getSelectionEnd() { return 0; }
				public virtual void setSelection(int start, int end) {}
			}

			class ImplRO : Impl
			{
				public readonly TextBlock text;

				public override FrameworkElement control { get { return text; } }

				public ImplRO(TextClip owner) : base(owner)
				{
					text = new TextBlock();
				}

				public override void setTextInput()
				{
					owner.impl = new ImplInput(owner);
				}

				public override void setTextAndStyle(string tstr, string font, double size, int weight, string slope, int fill, double fillopacity, int letterspacing, int bgcolor, double bgopacity)
				{
					text.Inlines.Clear();
					text.FontSize = size;
					var spec = findFont(font);
					text.FontFamily = spec.font;
					text.FontStyle = spec.style;
					text.Foreground = new SolidColorBrush(mkColor(fill, fillopacity));

					HtmlFormat format = new HtmlFormat();
					format.size = size;
					format.alpha = fillopacity;
					format.setColor(fill);
					format.setFont(font);
					format.sequence = text.Inlines;
					format.parse(tstr);

					// Make trailing whitespace &nbsp; because otherwise the text box size seems to ignore it
					if (text.Inlines.Count > 0)
					{
						var last = text.Inlines[text.Inlines.Count - 1];
						while (last != null && last is Underline)
							last = ((Underline)last).Inlines.LastOrDefault();

						var last_run = last as Run;
						if (last_run != null && last_run.Text.EndsWith(" "))
						{
							var part = last_run.Text.TrimEnd(new char[] { ' ' });
							last_run.Text = part + new String('\u00a0', last_run.Text.Length - part.Length);
						}
					}

					owner.measure();
				}
				public override void setTextDirection(string val)
				{
					text.FlowDirection = parseTextDirection(val);
				}
				public override void getTextMetrics(out double ascent, out double descent, out double leading)
				{
					ascent = text.BaselineOffset;
					descent = text.FontSize - ascent;
					leading = 0;
				}
				public override string getContent()
				{
					return text.Text;
				}
				public override void setAutoAlign(string val)
				{
					text.TextAlignment = parseAutoAlign(val);
				}
			}

			class ImplInput : Impl
			{
				public readonly TextBox input;

				public override FrameworkElement control { get { return input; } }

				public ImplInput(TextClip owner) : base(owner)
				{
					input = new TextBox();
					input.Style = (Style)Application.Current.Resources["TextBoxFlow"];

					input.Margin = new Thickness(0);
					input.Padding = new Thickness(0);
					input.Background = null;
					input.BorderBrush = null;
					input.BorderThickness = new Thickness(0);

					input.GotFocus += owner.onGotFocus;
					input.LostFocus += owner.onLostFocus;
					input.TextChanged += input_TextChanged;
					input.SelectionChanged += input_SelectionChanged;
				}

				public void switchOver(PasswordBox from)
				{
					input.FontSize = from.FontSize;
					input.FontFamily = from.FontFamily;
					input.Foreground = from.Foreground;
					input.Text = from.Password;
					input.MaxLength = from.MaxLength;
					input.TabIndex = from.TabIndex;

					if (owner.size_set)
					{
						input.Width = from.Width;
						input.Height = from.Height;
					}

					owner.impl = this;
					if (owner.focused)
						setFocus(true);
				}

				private void input_TextChanged(object sender, TextChangedEventArgs e)
				{
					owner.notifyChange();
				}

				private void input_SelectionChanged(object sender, RoutedEventArgs e)
				{
					owner.notifyChange();
				}

				public override void setTextAndStyle(string tstr, string font, double size, int weight, string slope, int fill, double fillopacity, int letterspacing, int bgcolor, double bgopacity)
				{
					input.FontSize = size;
					var spec = findFont(font);
					input.FontFamily = spec.font;
					input.FontStyle = spec.style;
					input.Foreground = new SolidColorBrush(mkColor(fill, fillopacity));
					input.Background = new SolidColorBrush(mkColor(bgcolor, bgopacity));

					input.Text = tstr;

					owner.measure();
				}
				public override void setTextDirection(string val)
				{
					input.FlowDirection = parseTextDirection(val);
				}
				public override int getCursorPosition()
				{
					return input.SelectionStart;
				}
				public override void setFocus(bool val)
				{
					if (val)
						input.Focus(FocusState.Programmatic);
				}
				public override string getContent()
				{
					return input.Text;
				}
				public override void setMultiline(bool val)
				{
					input.AcceptsReturn = val;
				}
				public override void setWordWrap(bool val)
				{
					input.TextWrapping = val ? TextWrapping.Wrap : TextWrapping.NoWrap;
				}
				public override void setReadOnly(bool val)
				{
					input.IsReadOnly = val;
				}
				public override void setAutoAlign(string val)
				{
					input.TextAlignment = parseAutoAlign(val);
				}
				public override void setTextInputType(string mode)
				{
					if (mode == "password")
						setTextFieldPasswordMode();
				}
				private void setTextFieldPasswordMode()
				{
					ImplPassword iin = new ImplPassword(owner);
					iin.switchOver(this.input);
				}
				public override void setMaxChars(int val)
				{
					input.MaxLength = val;
				}
				public override void setTabIndex(int val)
				{
					input.TabIndex = val;
				}
				public override int getSelectionStart()
				{
					return input.SelectionStart;
				}
				public override int getSelectionEnd()
				{
					return input.SelectionLength + input.SelectionStart;
				}
				public override void setSelection(int start, int end)
				{
					input.Select(start, end - start);
				}
			}

			class ImplPassword : Impl
			{
				public readonly PasswordBox input;

				public override FrameworkElement control { get { return input; } }

				public ImplPassword(TextClip owner)
					: base(owner)
				{
					input = new PasswordBox();
					input.Style = (Style)Application.Current.Resources["PasswordBoxFlow"];

					input.Margin = new Thickness(0);
					input.Padding = new Thickness(0);
					input.Background = null;
					input.BorderBrush = null;
					input.BorderThickness = new Thickness(0);

					input.GotFocus += owner.onGotFocus;
					input.LostFocus += owner.onLostFocus;
					input.PasswordChanged += input_PasswordChanged;
				}

				public void switchOver(TextBox from)
				{
					input.FontSize = from.FontSize;
					input.FontFamily = from.FontFamily;
					input.Foreground = from.Foreground;
					input.Password = from.Text;
					input.MaxLength = from.MaxLength;
					input.TabIndex = from.TabIndex;

					if (owner.size_set)
					{
						input.Width = from.Width;
						input.Height = from.Height;
					}

					owner.impl = this;
					if (owner.focused)
						setFocus(true);
				}

				void input_PasswordChanged(object sender, RoutedEventArgs e)
				{
					owner.notifyChange();
				}

				public override void setTextAndStyle(string tstr, string font, double size, int weight, string slope, int fill, double fillopacity, int letterspacing, int bgcolor, double bgopacity)
				{
					input.FontSize = size;
					var spec = findFont(font);
					input.FontFamily = spec.font;
					input.FontStyle = spec.style;
					input.Foreground = new SolidColorBrush(mkColor(fill, fillopacity));
					input.Background = new SolidColorBrush(mkColor(bgcolor, bgopacity));

					input.Password = tstr;

					owner.measure();
				}
				public override void setFocus(bool val)
				{
					if (val)
						input.Focus(FocusState.Programmatic);
				}
				public override string getContent()
				{
					return input.Password;
				}
				public override void setTextInputType(string mode)
				{
					if (mode != "password")
					{
						ImplInput iin = new ImplInput(owner);
						iin.switchOver(this.input);
						iin.setTextInputType(mode);
					}
				}
				public override void setMaxChars(int val)
				{
					input.MaxLength = val;
				}
				public override void setTabIndex(int val)
				{
					input.TabIndex = val;
				}
			}

			public void setTextFieldWidth(double val)
			{
				size_set = true;
				impl.control.Width = auto_size.Width = val;
			}
			public void setTextFieldHeigth(double val)
			{
				size_set = true;
				impl.control.Height = auto_size.Height = val;
			}
			public bool getFocus()
			{
				return focused;
			}
			public override void setFocus(bool set)
			{
				impl.setFocus(set);
			}
		}

		public override Object makeTextField(String fontFamily)
		{
			return new TextClip(this);
		}
		public override Object setTextInput(Object stg)
		{
			((TextClip)stg).impl.setTextInput();
			return null;
		}
		public override double getTextFieldWidth(Object stg)
		{
			return ((TextClip)stg).auto_size.Width;
		}
		public override double getTextFieldHeight(Object stg)
		{
			return ((TextClip)stg).auto_size.Height;
		}
		public override Object setTextFieldWidth(Object stg, double val)
		{
			((TextClip)stg).setTextFieldWidth(val);
			return null;
		}
		public override Object setTextFieldHeight(Object stg, double val)
		{
			((TextClip)stg).setTextFieldHeigth(val);
			return null;
		}
		public override Object setAdvancedText(Object stg, int a, int o, int e)
		{
			return null;
		}
		public override Object setTextAndStyle(Object tf,String text,String font,double size,int weight, string slope, int fill,double fillopacity,int letterspacing,int bgcolor,double bgopacity)
		{
			((TextClip)tf).impl.setTextAndStyle(text, font, size, weight, slope, fill, fillopacity, letterspacing, bgcolor, bgopacity);
			return null;
		}
		public override Object setTextDirection(Object stg, String val)
		{
			((TextClip)stg).impl.setTextDirection(val);
			return null;
		}
		public override int getNumLines(Object stg)
		{
			return ((TextClip)stg).impl.getNumLines();
		}
		public override int getCursorPosition(Object stg)
		{
			return ((TextClip)stg).impl.getCursorPosition();
		}
		public override bool getFocus(Object stg)
		{
			return ((TextClip)stg).getFocus();
		}
		public override Object setFocus(Object stg, bool val)
		{
			((Clip)stg).setFocus(val);
			return null;
		}
		public override String getContent(Object stg)
		{
			return ((TextClip)stg).impl.getContent();
		}
		public override Object setMultiline(Object stg, bool val)
		{
			((TextClip)stg).impl.setMultiline(val);
			return null;
		}
		public override Object setWordWrap(Object stg, bool val)
		{
			((TextClip)stg).impl.setWordWrap(val);
			return null;
		}
		public override Object setReadOnly(Object stg, bool val)
		{
			((TextClip)stg).impl.setReadOnly(val);
			return null;
		}
		public override Object setAutoAlign(Object stg, String val)
		{
			((TextClip)stg).impl.setAutoAlign(val);
			return null;
		}
		public override Object setTextInputType(Object stg, string mode)
		{
			((TextClip)stg).impl.setTextInputType(mode);
			return null;
		}
		public override Object setTabIndex(Object stg, int val)
		{
			((TextClip)stg).impl.setTabIndex(val);
			return null;
		}
		public override int getScrollV(Object stg)
		{
			return 0;
		}
		public override int getBottomScrollV(Object stg)
		{
			return 0;
		}
		public override Object setScrollV(Object stg, int val)
		{
			return null;
		}
		public override Object setMaxChars(Object stg, int val)
		{
			((TextClip)stg).impl.setMaxChars(val);
			return null;
		}
		public override Object[] getTextMetrics(Object stg)
		{
			double ascent, descent, leading;
			((TextClip)stg).impl.getTextMetrics(out ascent, out descent, out leading);
			return new Object[] { ascent, descent, leading };
		}
		public override int getSelectionStart(Object stg)
		{
			return ((TextClip)stg).impl.getSelectionStart();
		}
		public override int getSelectionEnd(Object stg)
		{
			return ((TextClip)stg).impl.getSelectionEnd();
		}
		public override Object setSelection(Object stg, int start, int end)
		{
			((TextClip)stg).impl.setSelection(start, end);
			return null;
		}

		private class VideoClip : Clip
		{
			public readonly MediaElement player;

			Func2 metrics_cb;
			Func1 duration_cb;
			int width, height;
			double length;

			Func1 status_cb;
			MediaElementState prev_state;

			// We can't rely on MediaElement's AutoPlay, since setting it to false
			// is causing decoding errors. Instead, we use this property to decide
			// if we should start playing once the media is opened
			private bool AutoPlay = true;

			public VideoClip(RenderSupportXAML owner, int w, int h, Func2 metrics_cb, Func1 duration_cb)
				: base(owner)
			{
				this.metrics_cb = metrics_cb;
				this.duration_cb = duration_cb;

				player = new MediaElement();
				node.Children.Add(player);

				player.Width = width = Math.Max(1, w);
				player.Height = height = Math.Max(1, h);

				player.MediaOpened += player_MediaOpened;
				player.MediaFailed += player_MediaFailed;
				player.MediaEnded += player_MediaEnded;

				prev_state = player.CurrentState;
				player.CurrentStateChanged += player_CurrentStateChanged;
			}

			public override void Dispose()
			{
				status_cb = null;
				base.Dispose();
			}

			bool isPlayingState(MediaElementState state)
			{
				switch (state)
				{
					case MediaElementState.Buffering:
					case MediaElementState.Paused:
					case MediaElementState.Playing:
						return true;

					default:
						return false;
				}
			}

			void player_CurrentStateChanged(object sender, RoutedEventArgs e)
			{
				var cur_state = player.CurrentState;

				var is_playing = isPlayingState(cur_state);
				var was_playing = isPlayingState(prev_state);
				prev_state = cur_state;

				if (is_playing != was_playing && status_cb != null)
				{
					status_cb(is_playing ? "NetStream.Play.Start" : "NetStream.Play.Stop");
				}
			}

			void player_MediaEnded(object sender, RoutedEventArgs e)
			{
			}

			void player_MediaFailed(object sender, ExceptionRoutedEventArgs e)
			{
				if (status_cb != null)
					status_cb("NetStream.Play.StreamNotFound");
			}

			void player_MediaOpened(object sender, RoutedEventArgs e)
			{
				if (!AutoPlay)
					player.Stop();

				player.Width = width = player.NaturalVideoWidth;
				player.Height = height = player.NaturalVideoHeight;
				length = player.NaturalDuration.TimeSpan.TotalMilliseconds;

				if (isDead || !owner.runtime.IsRunning) return;

				try
				{
					metrics_cb(width, height);
					duration_cb(length);
					if (status_cb != null)
						status_cb("NetStream.Play.Start");
				}
				catch (Exception ex)
				{
					Debug.WriteLine(ex);
				}
			}

			public async void play(Uri link, bool pause)
			{
				try
				{
					// Better let Windows manage the caching to avoid problems with streaming
					// var cached = await owner.media.getCachedObjectAsync(link);

					if (isDead || !owner.runtime.IsRunning) return;

					// Setting AutoPlay to false causes intermittend MF_MEDIA_ENGINE_ERR_DECODE at least on Windows Phone,
					// so we stop immediately after the media is opened if the "play" parameter is false
					player.AutoPlay = true;
					AutoPlay = !pause;

					player.AreTransportControlsEnabled = true;
					player.Source = link;
					//player.Source = MediaCache.fileToLink(cached);
				}
				catch (Exception e)
				{
					Debug.WriteLine(e.ToString());
					if (status_cb != null)
						status_cb("NetStream.Play.StreamNotFound");
				}
			}

			public Func0 addStreamStatusListener(Func1 cb)
			{
				Func1 invoke = delegate(object msg) {
					try
					{
						cb(msg);
					}
					catch (Exception e)
					{
						Debug.WriteLine(e);
					}
					return null;
				};
				status_cb += invoke;
				return () => { status_cb -= invoke; return null; };
			}
		}

		public override Object[] makeVideo(int w, int h, Func2 cb1, Func1 cb2)
		{
			var clip = new VideoClip(this, w, h, cb1, cb2);
			return new object[] { clip, clip };
		}
		public override Object pauseVideo(Object stg)
		{
			var clip = (VideoClip)stg;
			clip.player.Pause();
			return null;
		}
		public override Object resumeVideo(Object stg)
		{
			var clip = (VideoClip)stg;
			clip.player.Play();
			return null;
		}
		public override Object closeVideo(Object stg)
		{
			var clip = (VideoClip)stg;
			clip.player.Stop();
			return null;
		}
		public override Object playVideo(Object obj, String name, bool pause)
		{
			var clip = (VideoClip)obj;
			clip.play(new Uri(base_uri, name.TrimStart('/')), pause);
			return null;
		}
		public override double getVideoPosition(Object stg)
		{
			var clip = (VideoClip)stg;
			return clip.player.Position.TotalMilliseconds;
		}
		public override Object seekVideo(Object stg, double val)
		{
			var clip = (VideoClip)stg;
			clip.player.Position = new TimeSpan((long)(val * TimeSpan.TicksPerMillisecond));
			return null;
		}
		public override Object setVideoVolume(Object stg, double val)
		{
			var clip = (VideoClip)stg;
			clip.player.Volume = val;
			return null;
		}
		public override Object setVideoLooping(Object stg, bool val)
		{
			var clip = (VideoClip)stg;
			clip.player.IsLooping = val;
			return null;
		}
		public override Object setVideoControls(Object stg, Object[] info)
		{
			return null;
		}
		public override Object setVideoSubtitle(Object stg, String txt, double size, int color)
		{
			return null;
		}
		public override Func0 addStreamStatusListener(Object vid, Func1 cb)
		{
			var clip = (VideoClip)vid;
			return clip.addStreamStatusListener(cb);
		}
		public override bool isFullScreen()
		{
			return false;
		}
		public override Object toggleFullScreen(bool fs)
		{
			return null;
		}
		public override Func0 onFullScreen(Func1 cb)
		{
			return null;
		}
		public override Func0 setFullScreen(bool fs)
		{
			return null;
		}
		public override Object setFullScreenTarget(Object stg)
		{
			return null;
		}
		public override Object resetFullScreenTarget()
		{
			return null;
		}
		public override Object setFullScreenRectangle(double x, double y, double w, double h)
		{
			return null;
		}
		public override Object makeBevel(double a, double b, double c, double d, int e, double f, int g, double h, bool i)
		{
			return null;
		}
		public override Object makeDropShadow(double a1, double a2, double a3, double a4, int a5, double a6, bool a7)
		{
			return null;
		}
		public override Object makeBlur(double a, double b)
		{
			return null;
		}
		public override Object makeGlow(double a, double b, int c, double d, bool e)
		{
			return null;
		}

		private Dictionary<IStorageFile, CachedPicture> picture_cache = new Dictionary<IStorageFile, CachedPicture>();

		private class CachedPicture
		{
			private readonly RenderSupportXAML owner;

			public readonly Uri name;
			public readonly IStorageFile file;
			public readonly BitmapImage data;

			private bool loaded;
			private Func2 metricsFn;
			private Func1 errorFn;
			private List<Image> widgets;

			public CachedPicture(RenderSupportXAML owner, Uri name, IStorageFile file, Func2 metricsFn1, Func1 errorFn1)
			{
				this.owner = owner;
				this.name = name;
				this.file = file;
				this.metricsFn = metricsFn1;
				this.errorFn = errorFn1;

				owner.picture_cache.Add(file, this);

				data = new BitmapImage();

				data.ImageFailed += (object sender, ExceptionRoutedEventArgs a) =>
				{
					try
					{
						owner.picture_cache.Remove(file);

						using (var ctx = new FlowRuntime.DeferredContext(owner.runtime))
							errorFn(a.ErrorMessage);
					}
					catch (Exception e)
					{
						Debug.WriteLine(e);
					}

					metricsFn = null;
					errorFn = null;
				};

				data.ImageOpened += (object sender, RoutedEventArgs a) =>
				{
					try
					{
						loaded = true;

						using (var ctx = new FlowRuntime.DeferredContext(owner.runtime))
							metricsFn((double)data.PixelWidth, (double)data.PixelHeight);
					}
					catch (Exception e)
					{
						Debug.WriteLine(e);
					}

					if (widgets != null)
					{
						foreach (var img in widgets)
							img.Visibility = Visibility.Visible;

						widgets = null;
					}

					metricsFn = null;
					errorFn = null;
				};
			}

			public async Task load()
			{
				using (var stream = await file.OpenReadAsync())
				{
					await data.SetSourceAsync(stream);
				}
			}

			public void addCallbacks(Func2 metricsFn1, Func1 errorFn1)
			{
				if (loaded)
					metricsFn1((double)data.PixelWidth, (double)data.PixelHeight);
				else
				{
					metricsFn += metricsFn1;
					errorFn += errorFn1;
				}
			}

			public void displayOn(Image img)
			{
				if (!loaded)
				{
					if (widgets == null)
						widgets = new List<Image>();

					img.Visibility = Visibility.Collapsed;
					widgets.Add(img);
				}

				img.Source = data;
			}
		}

		private class PictureClip : Clip {
			public readonly Image image;

			public PictureClip(RenderSupportXAML owner) : base(owner)
			{
				image = new Image();
				node.Children.Add(image);
			}
		}

		public override Object makePicture(String name, bool cache, Func2 metricsFn, Func1 errorFn, bool onlyDownload)
		{
			PictureClip img = new PictureClip(this);

			loadPicture(img, name, cache, metricsFn, errorFn, onlyDownload);

			return img;
		}

		private async void loadPicture(PictureClip img, String name, bool cache, Func2 metricsFn, Func1 errorFn, bool onlyDownload)
		{
			try
			{
				// TODO: We are trimming leading slashes since some apps provide absolute paths and are expecting them
				// to act as relative urls. Remove this when the confusion is settled.
				Uri link = new Uri(base_uri, name.TrimStart('/'));

				IStorageFile file = await media.getCachedObjectAsync(link);

				if (img.isDead || !runtime.IsRunning) return;

				if (onlyDownload)
				{
					metricsFn(1.0, 1.0);
					return;
				}

				CachedPicture picture;
				bool first = false;

				if (picture_cache.TryGetValue(file, out picture))
				{
					picture.addCallbacks(metricsFn, errorFn);
				}
				else
				{
					first = true;
					picture = new CachedPicture(this, link, file, metricsFn, errorFn);
				}

				picture.displayOn(img.image);

				if (first)
					await picture.load();
			}
			catch (Exception e)
			{
				try
				{
					using (var ctx = new FlowRuntime.DeferredContext(runtime))
						errorFn(e.ToString());
				}
				catch (Exception e2)
				{
					Debug.WriteLine(e2);
				}
			}
		}

		private class WebClip : Clip
		{
			public readonly WebView browser;

			Uri link;
			String domain;
			bool useCache, doneSent;
			Func1 cb, ondone;

			public override double scalex
			{
				get { return browser.Width / 100; }
				set { browser.Width = 100 * value; }
			}
			public override double scaley
			{
				get { return browser.Height / 100; }
				set { browser.Height = 100 * value; }
			}

			public WebClip(RenderSupportXAML owner, Uri link, String domain, bool useCache, Func1 cb, Func1 ondone)
				: base(owner)
			{
				UriBuilder tweak = new UriBuilder(link);
				link = tweak.Uri;

				this.link = link;
				this.domain = domain;
				this.useCache = useCache;
				this.cb = cb;
				this.ondone = ondone;

				browser = new WebView();
				node.Children.Add(browser);

				doneSent = false;
				browser.NavigationCompleted += browser_NavigationCompleted;

				//browser.AllowedScriptNotifyUris = WebView.AnyScriptNotifyUri;
				browser.Width = browser.Height = 100;
				browser.Navigate(link);

				browser.ScriptNotify += browser_ScriptNotify;
			}

			void browser_NavigationCompleted(WebView sender, WebViewNavigationCompletedEventArgs args)
			{
				if (!doneSent && !isDead)
				{
					if (args.IsSuccess)
						ondone("OK");
					else
						ondone("Error: " + args.WebErrorStatus.ToString());
				}
				doneSent = true;
			}

			void browser_ScriptNotify(object sender, NotifyEventArgs e)
			{
				var args = e.Value.Split(new char[] { '\t' });
				var outv = new string[args.Length];
				for (int i = 0; i < args.Length; i++)
					outv[i] = args[i];

				try
				{
					if (!isDead)
						cb(outv);
				}
				catch (Exception e2)
				{
					Debug.WriteLine(e2);
				}
			}

			public string webClipHostCall(string fn, string[] args)
			{
				string[] sargs = new string[args.Length];
				for (int i = 0; i < args.Length; i++)
					sargs[i] = (string)args[i];

				browser.InvokeScriptAsync(fn, sargs);
				return null;
			}
		}

		public override Object makeWebClip(String url, String domain, bool useCache, bool reloadBlock, Func1 cb, Func1 ondone)
		{
			return new WebClip(this, new Uri(base_uri, url.TrimStart('/')), domain, useCache, cb, ondone);
		}
		public override String webClipHostCall(Object clip, String fn, String[] args)
		{
			var view = (WebClip)clip;
			return view.webClipHostCall(fn, args);
		}

		public override Object[] makeCamera(String a, int o, int e, int u, double i, int d, int h, int t, Func1 n, Func1 s)
		{
			return null;
		}
		public override Object startRecord(Object cm, String a, String o)
		{
			return null;
		}
		public override Object stopRecord(Object cm)
		{
			return null;
		}
		public override Object getGraphics(Object clip)
		{
			return ((Clip)clip).graphics;
		}
		public override Object beginFill(Object gr, int c, double a)
		{
			((Graphics)gr).beginFill(c, a);
			return null;
		}
		public override Object setLineStyle(Object gr, double a, int o, double e)
		{
			return setLineStyle2(gr, a, o, e, false);
		}
		public override Object setLineStyle2(Object gr, double a, int o, double e, bool h)
		{
			((Graphics)gr).setLineStyle(a, o, e, h);
			return null;
		}
		public override Object makeMatrix(double w, double h, double r, double x, double y)
		{
			var group = new TransformGroup();
			if (w != 1.0 || h != 1.0)
			{
				var scale = new ScaleTransform();
				scale.ScaleX = w;
				scale.ScaleY = h;
				group.Children.Add(scale);
			}
			if (r != 0.0)
			{
				var rotation = new RotateTransform();
				rotation.Angle = r;
				group.Children.Add(rotation);
			}
			if (x != 0.0 || y != 0.0)
			{
				var move = new TranslateTransform();
				move.X = x;
				move.Y = y;
				group.Children.Add(move);
			}
			return group;
		}
		public override Object beginGradientFill(Object gr, Object[] color, Object[] alpha, Object[] offset, Object matrix, String type)
		{
			((Graphics)gr).beginGradientFill(color, alpha, offset, matrix, type);
			return null;
		}
		public override Object setLineGradientStroke(Object gr, Object[] color, Object[] alpha, Object[] offset, Object matrix)
		{
			((Graphics)gr).setLineGradientStroke(color, alpha, offset, matrix);
			return null;
		}
		public override Object moveTo(Object gr, double x, double y)
		{
			((Graphics)gr).moveTo(x, y);
			return null;
		}
		public override Object lineTo(Object gr, double x, double y)
		{
			((Graphics)gr).lineTo(x, y);
			return null;
		}
		public override Object curveTo(Object gr, double x, double y, double cx, double cy)
		{
			((Graphics)gr).curveTo(x, y, cx, cy);
			return null;
		}
		public override Object endFill(Object gr)
		{
			((Graphics)gr).endFill();
			return null;
		}

		public override Object cameraTakePhoto(int cameraId, string additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, string filename, int fitmode)
		{
			FileOpenPicker filePicker = new FileOpenPicker();
			filePicker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;
			filePicker.ViewMode = PickerViewMode.Thumbnail;
			filePicker.FileTypeFilter.Add(".png");
			filePicker.FileTypeFilter.Add(".jpeg");
			filePicker.FileTypeFilter.Add(".jpg");
			filePicker.ContinuationData["Action"] = "RenderSupport.cameraTakePhoto";
			filePicker.ContinuationData["additionalInfo"] = additionalInfo;
			filePicker.ContinuationData["desiredWidth"] = desiredWidth;
			filePicker.ContinuationData["desiredHeight"] = desiredHeight;
			filePicker.ContinuationData["filename"] = filename;
			filePicker.ContinuationData["fitmode"] = fitmode;
			filePicker.PickSingleFileAndContinue();

			// Application is then suspended and should be eventually routed to continueCameraTakePhoto

			return null;
		}

		// Resize the image to the desired resolution
		// "file" is the input image
		// "filename" is the output file
		// TODO: Respect the resize mode requested from flow. Right now we scale maximally keeping the aspect.
		private async Task<StorageFile> resizeImage(StorageFile file, int width, int height, string filename, int fitmode)
		{
			// Ensure the stream is disposed once the image is loaded
			WriteableBitmap output = new WriteableBitmap(width, height);
			using (IRandomAccessStream fileStream = await file.OpenAsync(FileAccessMode.Read))
			{
				BitmapDecoder decoder = await BitmapDecoder.CreateAsync(fileStream);

				uint originalWidth = decoder.PixelWidth;
				uint originalHeight = decoder.PixelHeight;

				double sw = width/(double)originalWidth;
				double sh = height/(double)originalHeight;

				double scale = Math.Min(sw, sh);

				uint scaledWidth = (uint)(scale * originalWidth);
				uint scaledHeight = (uint)(scale * originalHeight);

				BitmapTransform transform = new BitmapTransform()
				{
					ScaledWidth = scaledWidth,
					ScaledHeight = scaledHeight
				};
				PixelDataProvider pixelData = await decoder.GetPixelDataAsync(
					decoder.BitmapPixelFormat,
					decoder.BitmapAlphaMode,
					transform,
					ExifOrientationMode.IgnoreExifOrientation,
					ColorManagementMode.DoNotColorManage
				);

				// Create output file; replace if exists.
				StorageFolder storageFolder = ApplicationData.Current.LocalFolder;
				StorageFile resizedFile = await storageFolder.CreateFileAsync(filename, CreationCollisionOption.ReplaceExisting);

				// Save the resized image
				using (var stream = await resizedFile.OpenAsync(FileAccessMode.ReadWrite))
				{
					byte[] sourcePixels = pixelData.DetachPixelData();
					BitmapEncoder encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.JpegEncoderId, stream);
					encoder.SetPixelData(
						decoder.BitmapPixelFormat,
						decoder.BitmapAlphaMode,
						scaledWidth,
						scaledHeight,
						96, 96,
						sourcePixels
					);
					await encoder.FlushAsync();
				}

				return resizedFile;
			}
		}

		// We should be routed back here once the user picks an image or takes a photo
		public override async void continueCameraTakePhoto(IContinuationActivatedEventArgs args)
		{
			if (args.Kind == ActivationKind.PickFileContinuation)
			{
				var openPickerContinuationArgs = args as FileOpenPickerContinuationEventArgs;

				// Recover the "Action" info we stored in ContinuationData
				string action = (string)openPickerContinuationArgs.ContinuationData["Action"];

				if (action != "RenderSupport.cameraTakePhoto")
				{
					Debug.WriteLine("INVALID ACTION");
					return;
				}

				Native native = runtime.getNativeHost<Native>();
				string additionalInfo = (string)openPickerContinuationArgs.ContinuationData["additionalInfo"];

				if (openPickerContinuationArgs.Files.Count > 0)
				{
					StorageFile file = openPickerContinuationArgs.Files.First();

					int desiredWidth = (int)openPickerContinuationArgs.ContinuationData["desiredWidth"];
					int desiredHeight = (int)openPickerContinuationArgs.ContinuationData["desiredHeight"];
					string filename = (string)openPickerContinuationArgs.ContinuationData["filename"];
					int fitmode = (int)openPickerContinuationArgs.ContinuationData["fitmode"];

					StorageFile resized = await resizeImage(file, desiredWidth, desiredHeight, filename, fitmode);

					native.notifyCameraEvent(0, resized.Path, additionalInfo, 0, 0);
				}
				else
				{
					native.notifyCameraEvent(-1, "cameraTakePhoto cancelled", additionalInfo, 0, 0);
				}
			}
		}
	}
}

