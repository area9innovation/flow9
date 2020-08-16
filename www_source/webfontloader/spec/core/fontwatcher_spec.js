describe('FontWatcher', function () {
  var FontWatcher = webfont.FontWatcher,
      FontWatchRunner = webfont.FontWatchRunner,
      NativeFontWatchRunner = webfont.NativeFontWatchRunner,
      Font = webfont.Font,
      DomHelper = webfont.DomHelper,
      Version = webfont.Version,
      domHelper = new DomHelper(window),
      eventDispatcher = {},
      testStrings = null,
      timeout = null,
      font1 = null,
      font2 = null,
      font3 = null,
      font4 = null,
      activeFonts = [];

  beforeEach(function () {
    font1 = new Font('font1');
    font2 = new Font('font2');
    font3 = new Font('font3');
    font4 = new Font('font4');
    activeFonts = [];
    testStrings = jasmine.createSpy('testStrings');
    timeout = jasmine.createSpy('timeout');
    eventDispatcher.dispatchLoading = jasmine.createSpy('dispatchLoading');
    eventDispatcher.dispatchFontLoading = jasmine.createSpy('dispatchFontLoading');
    eventDispatcher.dispatchFontActive = jasmine.createSpy('dispatchFontActive');
    eventDispatcher.dispatchFontInactive = jasmine.createSpy('dispatchFontInactive');
    eventDispatcher.dispatchActive = jasmine.createSpy('dispatchActive');
    eventDispatcher.dispatchInactive = jasmine.createSpy('dispatchInactive');

    var fakeStart = function (font, fontTestString) {
      var found = false;

      testStrings(this.fontTestString_);
      timeout(this.timeout_);

      for (var i = 0; i < activeFonts.length; i += 1) {
        if (activeFonts[i].getName() === this.font_.getName()) {
          found = true;
          break;
        }
      }

      if (found) {
        this.activeCallback_(this.font_);
      } else {
        this.inactiveCallback_(this.font_);
      }
    };

    spyOn(FontWatchRunner.prototype, 'start').andCallFake(fakeStart);
    spyOn(NativeFontWatchRunner.prototype, 'start').andCallFake(fakeStart);
  });

  if (!!window.FontFace) {
    describe('use native font loading API', function () {
      beforeEach(function () {
        FontWatcher.SHOULD_USE_NATIVE_LOADER = null;
      });

      it('works on Chrome', function () {
        spyOn(FontWatcher, 'getUserAgent').andReturn('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.86 Safari/537.36');
        expect(FontWatcher.shouldUseNativeLoader()).toEqual(true);
      });

      it('is disabled on Firefox <= 42', function () {
        spyOn(FontWatcher, 'getUserAgent').andReturn('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:42.0) Gecko/20100101 Firefox/42.0')
        expect(FontWatcher.shouldUseNativeLoader()).toEqual(false);
      });

      it('is enabled on Firefox > 43', function () {
        spyOn(FontWatcher, 'getUserAgent').andReturn('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:43.0) Gecko/20100101 Firefox/43.0');
        expect(FontWatcher.shouldUseNativeLoader()).toEqual(true);
      });

      it('is disabled on Safari > 10', function () {
        spyOn(FontWatcher, 'getUserAgent').andReturn('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/602.2.14 (KHTML, like Gecko) Version/10.0.1 Safari/602.2.14');
        spyOn(FontWatcher, 'getVendor').andReturn('Apple');
        expect(FontWatcher.shouldUseNativeLoader()).toEqual(false);
      });
    });
  }

  describe('watch zero fonts', function () {
    it('should call inactive when there are no fonts to load', function () {
      activeFonts = [];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([], {}, null, true);
      expect(eventDispatcher.dispatchInactive).toHaveBeenCalled();
    });

    it('should not call inactive when there are no fonts to load, but this is not the last set', function () {
      activeFonts = [];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([], {}, null, false);
      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
    });
  });

  describe('watch one font not last', function () {
    it('should not call font inactive, inactive or active', function () {
      activeFonts = [font1];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1], {}, null, false);
      expect(eventDispatcher.dispatchFontInactive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchActive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
    });
  });

  describe('watch one font active', function () {
    it('should call font active and active', function () {
      activeFonts = [font1];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontActive).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontInactive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchActive).toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
    });
  });

  describe('watch one font inactive', function () {
    it('should call inactive', function () {
      activeFonts = [];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontActive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchFontInactive).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchActive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).toHaveBeenCalled();
    });
  });

  describe('watch multiple fonts active', function () {
    it('should call font active and active', function () {
      activeFonts = [font1, font2, font3];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1, font2, font3], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontActive).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontInactive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchActive).toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
    });
  });

  describe('watch multiple fonts inactive', function () {
    it('should call inactive', function () {
      activeFonts = [];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1, font2, font3], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchFontActive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchFontInactive).toHaveBeenCalledWith(font1);
      expect(eventDispatcher.dispatchActive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).toHaveBeenCalled();
    });
  });

  describe('watch multiple fonts mixed', function () {
    it('should call the correct callbacks', function () {
      activeFonts = [font1, font3];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1, font2, font3], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading.callCount).toEqual(3);
      expect(eventDispatcher.dispatchFontLoading.calls[0].args[0]).toEqual(font1);
      expect(eventDispatcher.dispatchFontLoading.calls[1].args[0]).toEqual(font2);
      expect(eventDispatcher.dispatchFontLoading.calls[2].args[0]).toEqual(font3);

      expect(eventDispatcher.dispatchFontActive.callCount).toEqual(2);
      expect(eventDispatcher.dispatchFontActive.calls[0].args[0]).toEqual(font1);
      expect(eventDispatcher.dispatchFontActive.calls[1].args[0]).toEqual(font3);

      expect(eventDispatcher.dispatchFontInactive.callCount).toEqual(1);
      expect(eventDispatcher.dispatchFontInactive.calls[0].args[0]).toEqual(font2);

      expect(eventDispatcher.dispatchActive).toHaveBeenCalled();
      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
    });
  });

  describe('watch multiple fonts with descriptions', function () {
    it('should call the correct callbacks', function () {
      var font5 = new Font('font4', 'i7'),
          font6 = new Font('font5'),
          font7 = new Font('font6'),
          font8 = new Font('font7', 'i4'),
          font9 = new Font('font8', 'n7');

      activeFonts = [font5, font6];
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font5, font6, font7, font8, font9], {}, null, true);
      expect(eventDispatcher.dispatchFontLoading.callCount).toEqual(5);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font5);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font6);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font7);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font8);
      expect(eventDispatcher.dispatchFontLoading).toHaveBeenCalledWith(font9);

      expect(eventDispatcher.dispatchFontActive.callCount).toEqual(2);
      expect(eventDispatcher.dispatchFontActive).toHaveBeenCalledWith(font5);
      expect(eventDispatcher.dispatchFontActive).toHaveBeenCalledWith(font6);

      expect(eventDispatcher.dispatchFontInactive.callCount).toEqual(3);
      expect(eventDispatcher.dispatchFontInactive).toHaveBeenCalledWith(font7);
      expect(eventDispatcher.dispatchFontInactive).toHaveBeenCalledWith(font8);
      expect(eventDispatcher.dispatchFontInactive).toHaveBeenCalledWith(font9);

      expect(eventDispatcher.dispatchInactive).not.toHaveBeenCalled();
      expect(eventDispatcher.dispatchActive).toHaveBeenCalled();
    });
  });

  describe('watch multiple fonts with test strings', function () {
    it('should use the correct tests strings', function () {
      activeFonts = [font1, font2];

      var defaultTestString = FontWatcher.SHOULD_USE_NATIVE_LOADER ? undefined : FontWatchRunner.DEFAULT_TEST_STRING;
      var fontWatcher = new FontWatcher(domHelper, eventDispatcher);

      fontWatcher.watchFonts([font1, font2, font3, font4], {
        'font1': 'testString1',
        'font2': null,
        'font3': 'testString2',
        'font4': null
      }, null, true);

      expect(testStrings.callCount).toEqual(4);
      expect(testStrings.calls[0].args[0]).toEqual('testString1');
      expect(testStrings.calls[1].args[0]).toEqual(defaultTestString);
      expect(testStrings.calls[2].args[0]).toEqual('testString2');
      expect(testStrings.calls[3].args[0]).toEqual(defaultTestString);
    });
  });

  it('should pass on the timeout to FontWatchRunner', function () {
    var fontWatcher = new FontWatcher(domHelper, eventDispatcher, 4000);

    fontWatcher.watchFonts([font1], {}, null, true);

    expect(timeout).toHaveBeenCalledWith(4000);
  });
});
