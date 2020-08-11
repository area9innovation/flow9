/* Web Font Loader v1.6.28 - (c) Adobe Systems, Google. License: Apache 2.0 */
(function() {
    var CLOSURE_NO_DEPS = !0
      , COMPILED = !0
      , goog = goog || {};
    goog.global = this;
    goog.isDef = function(a) {
        return void 0 !== a
    }
    ;
    goog.exportPath_ = function(a, b, c) {
        a = a.split(".");
        c = c || goog.global;
        a[0]in c || !c.execScript || c.execScript("var " + a[0]);
        for (var d; a.length && (d = a.shift()); )
            !a.length && goog.isDef(b) ? c[d] = b : c = c[d] ? c[d] : c[d] = {}
    }
    ;
    goog.define = function(a, b) {
        var c = b;
        COMPILED || (goog.global.CLOSURE_UNCOMPILED_DEFINES && Object.prototype.hasOwnProperty.call(goog.global.CLOSURE_UNCOMPILED_DEFINES, a) ? c = goog.global.CLOSURE_UNCOMPILED_DEFINES[a] : goog.global.CLOSURE_DEFINES && Object.prototype.hasOwnProperty.call(goog.global.CLOSURE_DEFINES, a) && (c = goog.global.CLOSURE_DEFINES[a]));
        goog.exportPath_(a, c)
    }
    ;
    goog.DEBUG = !1;
    goog.LOCALE = "en";
    goog.TRUSTED_SITE = !0;
    goog.STRICT_MODE_COMPATIBLE = !1;
    goog.DISALLOW_TEST_ONLY_CODE = COMPILED && !goog.DEBUG;
    goog.ENABLE_CHROME_APP_SAFE_SCRIPT_LOADING = !1;
    goog.provide = function(a) {
        if (!COMPILED && goog.isProvided_(a))
            throw Error('Namespace "' + a + '" already declared.');
        goog.constructNamespace_(a)
    }
    ;
    goog.constructNamespace_ = function(a, b) {
        if (!COMPILED) {
            delete goog.implicitNamespaces_[a];
            for (var c = a; (c = c.substring(0, c.lastIndexOf("."))) && !goog.getObjectByName(c); )
                goog.implicitNamespaces_[c] = !0
        }
        goog.exportPath_(a, b)
    }
    ;
    goog.VALID_MODULE_RE_ = /^[a-zA-Z_$][a-zA-Z0-9._$]*$/;
    goog.module = function(a) {
        if (!goog.isString(a) || !a || -1 == a.search(goog.VALID_MODULE_RE_))
            throw Error("Invalid module identifier");
        if (!goog.isInModuleLoader_())
            throw Error("Module " + a + " has been loaded incorrectly.");
        if (goog.moduleLoaderState_.moduleName)
            throw Error("goog.module may only be called once per module.");
        goog.moduleLoaderState_.moduleName = a;
        if (!COMPILED) {
            if (goog.isProvided_(a))
                throw Error('Namespace "' + a + '" already declared.');
            delete goog.implicitNamespaces_[a]
        }
    }
    ;
    goog.module.get = function(a) {
        return goog.module.getInternal_(a)
    }
    ;
    goog.module.getInternal_ = function(a) {
        if (!COMPILED)
            return goog.isProvided_(a) ? a in goog.loadedModules_ ? goog.loadedModules_[a] : goog.getObjectByName(a) : null
    }
    ;
    goog.moduleLoaderState_ = null;
    goog.isInModuleLoader_ = function() {
        return null != goog.moduleLoaderState_
    }
    ;
    goog.module.declareLegacyNamespace = function() {
        if (!COMPILED && !goog.isInModuleLoader_())
            throw Error("goog.module.declareLegacyNamespace must be called from within a goog.module");
        if (!COMPILED && !goog.moduleLoaderState_.moduleName)
            throw Error("goog.module must be called prior to goog.module.declareLegacyNamespace.");
        goog.moduleLoaderState_.declareLegacyNamespace = !0
    }
    ;
    goog.setTestOnly = function(a) {
        if (goog.DISALLOW_TEST_ONLY_CODE)
            throw a = a || "",
            Error("Importing test-only code into non-debug environment" + (a ? ": " + a : "."));
    }
    ;
    goog.forwardDeclare = function(a) {}
    ;
    COMPILED || (goog.isProvided_ = function(a) {
        return a in goog.loadedModules_ || !goog.implicitNamespaces_[a] && goog.isDefAndNotNull(goog.getObjectByName(a))
    }
    ,
    goog.implicitNamespaces_ = {
        "goog.module": !0
    });
    goog.getObjectByName = function(a, b) {
        for (var c = a.split("."), d = b || goog.global, e; e = c.shift(); )
            if (goog.isDefAndNotNull(d[e]))
                d = d[e];
            else
                return null;
        return d
    }
    ;
    goog.globalize = function(a, b) {
        var c = b || goog.global, d;
        for (d in a)
            c[d] = a[d]
    }
    ;
    goog.addDependency = function(a, b, c, d) {
        if (goog.DEPENDENCIES_ENABLED) {
            var e;
            a = a.replace(/\\/g, "/");
            for (var f = goog.dependencies_, g = 0; e = b[g]; g++)
                f.nameToPath[e] = a,
                f.pathIsModule[a] = !!d;
            for (d = 0; b = c[d]; d++)
                a in f.requires || (f.requires[a] = {}),
                f.requires[a][b] = !0
        }
    }
    ;
    goog.ENABLE_DEBUG_LOADER = !0;
    goog.logToConsole_ = function(a) {
        goog.global.console && goog.global.console.error(a)
    }
    ;
    goog.require = function(a) {
        if (!COMPILED) {
            goog.ENABLE_DEBUG_LOADER && goog.IS_OLD_IE_ && goog.maybeProcessDeferredDep_(a);
            if (goog.isProvided_(a))
                return goog.isInModuleLoader_() ? goog.module.getInternal_(a) : null;
            if (goog.ENABLE_DEBUG_LOADER) {
                var b = goog.getPathFromDeps_(a);
                if (b)
                    return goog.writeScripts_(b),
                    null
            }
            a = "goog.require could not find: " + a;
            goog.logToConsole_(a);
            throw Error(a);
        }
    }
    ;
    goog.basePath = "";
    goog.nullFunction = function() {}
    ;
    goog.abstractMethod = function() {
        throw Error("unimplemented abstract method");
    }
    ;
    goog.addSingletonGetter = function(a) {
        a.getInstance = function() {
            if (a.instance_)
                return a.instance_;
            goog.DEBUG && (goog.instantiatedSingletons_[goog.instantiatedSingletons_.length] = a);
            return a.instance_ = new a
        }
    }
    ;
    goog.instantiatedSingletons_ = [];
    goog.LOAD_MODULE_USING_EVAL = !0;
    goog.SEAL_MODULE_EXPORTS = goog.DEBUG;
    goog.loadedModules_ = {};
    goog.DEPENDENCIES_ENABLED = !COMPILED && goog.ENABLE_DEBUG_LOADER;
    goog.DEPENDENCIES_ENABLED && (goog.dependencies_ = {
        pathIsModule: {},
        nameToPath: {},
        requires: {},
        visited: {},
        written: {},
        deferred: {}
    },
    goog.inHtmlDocument_ = function() {
        var a = goog.global.document;
        return null != a && "write"in a
    }
    ,
    goog.findBasePath_ = function() {
        if (goog.isDef(goog.global.CLOSURE_BASE_PATH))
            goog.basePath = goog.global.CLOSURE_BASE_PATH;
        else if (goog.inHtmlDocument_())
            for (var a = goog.global.document.getElementsByTagName("SCRIPT"), b = a.length - 1; 0 <= b; --b) {
                var c = a[b].src
                  , d = c.lastIndexOf("?")
                  , d = -1 == d ? c.length : d;
                if ("base.js" == c.substr(d - 7, 7)) {
                    goog.basePath = c.substr(0, d - 7);
                    break
                }
            }
    }
    ,
    goog.importScript_ = function(a, b) {
        (goog.global.CLOSURE_IMPORT_SCRIPT || goog.writeScriptTag_)(a, b) && (goog.dependencies_.written[a] = !0)
    }
    ,
    goog.IS_OLD_IE_ = !(goog.global.atob || !goog.global.document || !goog.global.document.all),
    goog.importModule_ = function(a) {
        goog.importScript_("", 'goog.retrieveAndExecModule_("' + a + '");') && (goog.dependencies_.written[a] = !0)
    }
    ,
    goog.queuedModules_ = [],
    goog.wrapModule_ = function(a, b) {
        return goog.LOAD_MODULE_USING_EVAL && goog.isDef(goog.global.JSON) ? "goog.loadModule(" + goog.global.JSON.stringify(b + "\n//# sourceURL=" + a + "\n") + ");" : 'goog.loadModule(function(exports) {"use strict";' + b + "\n;return exports});\n//# sourceURL=" + a + "\n"
    }
    ,
    goog.loadQueuedModules_ = function() {
        var a = goog.queuedModules_.length;
        if (0 < a) {
            var b = goog.queuedModules_;
            goog.queuedModules_ = [];
            for (var c = 0; c < a; c++)
                goog.maybeProcessDeferredPath_(b[c])
        }
    }
    ,
    goog.maybeProcessDeferredDep_ = function(a) {
        goog.isDeferredModule_(a) && goog.allDepsAreAvailable_(a) && (a = goog.getPathFromDeps_(a),
        goog.maybeProcessDeferredPath_(goog.basePath + a))
    }
    ,
    goog.isDeferredModule_ = function(a) {
        return (a = goog.getPathFromDeps_(a)) && goog.dependencies_.pathIsModule[a] ? goog.basePath + a in goog.dependencies_.deferred : !1
    }
    ,
    goog.allDepsAreAvailable_ = function(a) {
        if ((a = goog.getPathFromDeps_(a)) && a in goog.dependencies_.requires)
            for (var b in goog.dependencies_.requires[a])
                if (!goog.isProvided_(b) && !goog.isDeferredModule_(b))
                    return !1;
        return !0
    }
    ,
    goog.maybeProcessDeferredPath_ = function(a) {
        if (a in goog.dependencies_.deferred) {
            var b = goog.dependencies_.deferred[a];
            delete goog.dependencies_.deferred[a];
            goog.globalEval(b)
        }
    }
    ,
    goog.loadModuleFromUrl = function(a) {
        goog.retrieveAndExecModule_(a)
    }
    ,
    goog.loadModule = function(a) {
        var b = goog.moduleLoaderState_;
        try {
            goog.moduleLoaderState_ = {
                moduleName: void 0,
                declareLegacyNamespace: !1
            };
            var c;
            if (goog.isFunction(a))
                c = a.call(goog.global, {});
            else if (goog.isString(a))
                c = goog.loadModuleFromSource_.call(goog.global, a);
            else
                throw Error("Invalid module definition");
            var d = goog.moduleLoaderState_.moduleName;
            if (!goog.isString(d) || !d)
                throw Error('Invalid module name "' + d + '"');
            goog.moduleLoaderState_.declareLegacyNamespace ? goog.constructNamespace_(d, c) : goog.SEAL_MODULE_EXPORTS && Object.seal && Object.seal(c);
            goog.loadedModules_[d] = c
        } finally {
            goog.moduleLoaderState_ = b
        }
    }
    ,
    goog.loadModuleFromSource_ = function(a) {
        eval(a);
        return {}
    }
    ,
    goog.writeScriptSrcNode_ = function(a) {
        goog.global.document.write('<script type="text/javascript" src="' + a + '">\x3c/script>')
    }
    ,
    goog.appendScriptSrcNode_ = function(a) {
        var b = goog.global.document
          , c = b.createElement("script");
        c.type = "text/javascript";
        c.src = a;
        c.defer = !1;
        c.async = !1;
        b.head.appendChild(c)
    }
    ,
    goog.writeScriptTag_ = function(a, b) {
        if (goog.inHtmlDocument_()) {
            var c = goog.global.document;
            if (!goog.ENABLE_CHROME_APP_SAFE_SCRIPT_LOADING && "complete" == c.readyState) {
                if (/\bdeps.js$/.test(a))
                    return !1;
                throw Error('Cannot write "' + a + '" after document load');
            }
            var d = goog.IS_OLD_IE_;
            void 0 === b ? d ? (d = " onreadystatechange='goog.onScriptLoad_(this, " + ++goog.lastNonModuleScriptIndex_ + ")' ",
            c.write('<script type="text/javascript" src="' + a + '"' + d + ">\x3c/script>")) : goog.ENABLE_CHROME_APP_SAFE_SCRIPT_LOADING ? goog.appendScriptSrcNode_(a) : goog.writeScriptSrcNode_(a) : c.write('<script type="text/javascript">' + b + "\x3c/script>");
            return !0
        }
        return !1
    }
    ,
    goog.lastNonModuleScriptIndex_ = 0,
    goog.onScriptLoad_ = function(a, b) {
        "complete" == a.readyState && goog.lastNonModuleScriptIndex_ == b && goog.loadQueuedModules_();
        return !0
    }
    ,
    goog.writeScripts_ = function(a) {
        function b(a) {
            if (!(a in e.written || a in e.visited)) {
                e.visited[a] = !0;
                if (a in e.requires)
                    for (var f in e.requires[a])
                        if (!goog.isProvided_(f))
                            if (f in e.nameToPath)
                                b(e.nameToPath[f]);
                            else
                                throw Error("Undefined nameToPath for " + f);
                a in d || (d[a] = !0,
                c.push(a))
            }
        }
        var c = []
          , d = {}
          , e = goog.dependencies_;
        b(a);
        for (a = 0; a < c.length; a++) {
            var f = c[a];
            goog.dependencies_.written[f] = !0
        }
        var g = goog.moduleLoaderState_;
        goog.moduleLoaderState_ = null;
        for (a = 0; a < c.length; a++)
            if (f = c[a])
                e.pathIsModule[f] ? goog.importModule_(goog.basePath + f) : goog.importScript_(goog.basePath + f);
            else
                throw goog.moduleLoaderState_ = g,
                Error("Undefined script input");
        goog.moduleLoaderState_ = g
    }
    ,
    goog.getPathFromDeps_ = function(a) {
        return a in goog.dependencies_.nameToPath ? goog.dependencies_.nameToPath[a] : null
    }
    ,
    goog.findBasePath_(),
    goog.global.CLOSURE_NO_DEPS || goog.importScript_(goog.basePath + "deps.js"));
    goog.normalizePath_ = function(a) {
        a = a.split("/");
        for (var b = 0; b < a.length; )
            "." == a[b] ? a.splice(b, 1) : b && ".." == a[b] && a[b - 1] && ".." != a[b - 1] ? a.splice(--b, 2) : b++;
        return a.join("/")
    }
    ;
    goog.loadFileSync_ = function(a) {
        if (goog.global.CLOSURE_LOAD_FILE_SYNC)
            return goog.global.CLOSURE_LOAD_FILE_SYNC(a);
        var b = new goog.global.XMLHttpRequest;
        b.open("get", a, !1);
        b.send();
        return b.responseText
    }
    ;
    goog.retrieveAndExecModule_ = function(a) {
        if (!COMPILED) {
            var b = a;
            a = goog.normalizePath_(a);
            var c = goog.global.CLOSURE_IMPORT_SCRIPT || goog.writeScriptTag_
              , d = goog.loadFileSync_(a);
            if (null != d)
                d = goog.wrapModule_(a, d),
                goog.IS_OLD_IE_ ? (goog.dependencies_.deferred[b] = d,
                goog.queuedModules_.push(b)) : c(a, d);
            else
                throw Error("load of " + a + "failed");
        }
    }
    ;
    goog.typeOf = function(a) {
        var b = typeof a;
        if ("object" == b)
            if (a) {
                if (a instanceof Array)
                    return "array";
                if (a instanceof Object)
                    return b;
                var c = Object.prototype.toString.call(a);
                if ("[object Window]" == c)
                    return "object";
                if ("[object Array]" == c || "number" == typeof a.length && "undefined" != typeof a.splice && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("splice"))
                    return "array";
                if ("[object Function]" == c || "undefined" != typeof a.call && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("call"))
                    return "function"
            } else
                return "null";
        else if ("function" == b && "undefined" == typeof a.call)
            return "object";
        return b
    }
    ;
    goog.isNull = function(a) {
        return null === a
    }
    ;
    goog.isDefAndNotNull = function(a) {
        return null != a
    }
    ;
    goog.isArray = function(a) {
        return "array" == goog.typeOf(a)
    }
    ;
    goog.isArrayLike = function(a) {
        var b = goog.typeOf(a);
        return "array" == b || "object" == b && "number" == typeof a.length
    }
    ;
    goog.isDateLike = function(a) {
        return goog.isObject(a) && "function" == typeof a.getFullYear
    }
    ;
    goog.isString = function(a) {
        return "string" == typeof a
    }
    ;
    goog.isBoolean = function(a) {
        return "boolean" == typeof a
    }
    ;
    goog.isNumber = function(a) {
        return "number" == typeof a
    }
    ;
    goog.isFunction = function(a) {
        return "function" == goog.typeOf(a)
    }
    ;
    goog.isObject = function(a) {
        var b = typeof a;
        return "object" == b && null != a || "function" == b
    }
    ;
    goog.getUid = function(a) {
        return a[goog.UID_PROPERTY_] || (a[goog.UID_PROPERTY_] = ++goog.uidCounter_)
    }
    ;
    goog.hasUid = function(a) {
        return !!a[goog.UID_PROPERTY_]
    }
    ;
    goog.removeUid = function(a) {
        null !== a && "removeAttribute"in a && a.removeAttribute(goog.UID_PROPERTY_);
        try {
            delete a[goog.UID_PROPERTY_]
        } catch (b) {}
    }
    ;
    goog.UID_PROPERTY_ = "closure_uid_" + (1E9 * Math.random() >>> 0);
    goog.uidCounter_ = 0;
    goog.getHashCode = goog.getUid;
    goog.removeHashCode = goog.removeUid;
    goog.cloneObject = function(a) {
        var b = goog.typeOf(a);
        if ("object" == b || "array" == b) {
            if (a.clone)
                return a.clone();
            var b = "array" == b ? [] : {}, c;
            for (c in a)
                b[c] = goog.cloneObject(a[c]);
            return b
        }
        return a
    }
    ;
    goog.bindNative_ = function(a, b, c) {
        return a.call.apply(a.bind, arguments)
    }
    ;
    goog.bindJs_ = function(a, b, c) {
        if (!a)
            throw Error();
        if (2 < arguments.length) {
            var d = Array.prototype.slice.call(arguments, 2);
            return function() {
                var c = Array.prototype.slice.call(arguments);
                Array.prototype.unshift.apply(c, d);
                return a.apply(b, c)
            }
        }
        return function() {
            return a.apply(b, arguments)
        }
    }
    ;
    goog.bind = function(a, b, c) {
        Function.prototype.bind && -1 != Function.prototype.bind.toString().indexOf("native code") ? goog.bind = goog.bindNative_ : goog.bind = goog.bindJs_;
        return goog.bind.apply(null, arguments)
    }
    ;
    goog.partial = function(a, b) {
        var c = Array.prototype.slice.call(arguments, 1);
        return function() {
            var b = c.slice();
            b.push.apply(b, arguments);
            return a.apply(this, b)
        }
    }
    ;
    goog.mixin = function(a, b) {
        for (var c in b)
            a[c] = b[c]
    }
    ;
    goog.now = goog.TRUSTED_SITE && Date.now || function() {
        return +new Date
    }
    ;
    goog.globalEval = function(a) {
        if (goog.global.execScript)
            goog.global.execScript(a, "JavaScript");
        else if (goog.global.eval) {
            if (null == goog.evalWorksForGlobals_)
                if (goog.global.eval("var _evalTest_ = 1;"),
                "undefined" != typeof goog.global._evalTest_) {
                    try {
                        delete goog.global._evalTest_
                    } catch (d) {}
                    goog.evalWorksForGlobals_ = !0
                } else
                    goog.evalWorksForGlobals_ = !1;
            if (goog.evalWorksForGlobals_)
                goog.global.eval(a);
            else {
                var b = goog.global.document
                  , c = b.createElement("SCRIPT");
                c.type = "text/javascript";
                c.defer = !1;
                c.appendChild(b.createTextNode(a));
                b.body.appendChild(c);
                b.body.removeChild(c)
            }
        } else
            throw Error("goog.globalEval not available");
    }
    ;
    goog.evalWorksForGlobals_ = null;
    goog.getCssName = function(a, b) {
        var c = function(a) {
            return goog.cssNameMapping_[a] || a
        }
          , d = function(a) {
            a = a.split("-");
            for (var b = [], d = 0; d < a.length; d++)
                b.push(c(a[d]));
            return b.join("-")
        }
          , d = goog.cssNameMapping_ ? "BY_WHOLE" == goog.cssNameMappingStyle_ ? c : d : function(a) {
            return a
        }
        ;
        return b ? a + "-" + d(b) : d(a)
    }
    ;
    goog.setCssNameMapping = function(a, b) {
        goog.cssNameMapping_ = a;
        goog.cssNameMappingStyle_ = b
    }
    ;
    !COMPILED && goog.global.CLOSURE_CSS_NAME_MAPPING && (goog.cssNameMapping_ = goog.global.CLOSURE_CSS_NAME_MAPPING);
    goog.getMsg = function(a, b) {
        b && (a = a.replace(/\{\$([^}]+)}/g, function(a, d) {
            return null != b && d in b ? b[d] : a
        }));
        return a
    }
    ;
    goog.getMsgWithFallback = function(a, b) {
        return a
    }
    ;
    goog.exportSymbol = function(a, b, c) {
        goog.exportPath_(a, b, c)
    }
    ;
    goog.exportProperty = function(a, b, c) {
        a[b] = c
    }
    ;
    goog.inherits = function(a, b) {
        function c() {}
        c.prototype = b.prototype;
        a.superClass_ = b.prototype;
        a.prototype = new c;
        a.prototype.constructor = a;
        a.base = function(a, c, f) {
            for (var g = Array(arguments.length - 2), h = 2; h < arguments.length; h++)
                g[h - 2] = arguments[h];
            return b.prototype[c].apply(a, g)
        }
    }
    ;
    goog.base = function(a, b, c) {
        var d = arguments.callee.caller;
        if (goog.STRICT_MODE_COMPATIBLE || goog.DEBUG && !d)
            throw Error("arguments.caller not defined.  goog.base() cannot be used with strict mode code. See http://www.ecma-international.org/ecma-262/5.1/#sec-C");
        if (d.superClass_) {
            for (var e = Array(arguments.length - 1), f = 1; f < arguments.length; f++)
                e[f - 1] = arguments[f];
            return d.superClass_.constructor.apply(a, e)
        }
        e = Array(arguments.length - 2);
        for (f = 2; f < arguments.length; f++)
            e[f - 2] = arguments[f];
        for (var f = !1, g = a.constructor; g; g = g.superClass_ && g.superClass_.constructor)
            if (g.prototype[b] === d)
                f = !0;
            else if (f)
                return g.prototype[b].apply(a, e);
        if (a[b] === d)
            return a.constructor.prototype[b].apply(a, e);
        throw Error("goog.base called from a method of one name to a method of a different name");
    }
    ;
    goog.scope = function(a) {
        a.call(goog.global)
    }
    ;
    COMPILED || (goog.global.COMPILED = COMPILED);
    goog.defineClass = function(a, b) {
        var c = b.constructor
          , d = b.statics;
        c && c != Object.prototype.constructor || (c = function() {
            throw Error("cannot instantiate an interface (no constructor defined).");
        }
        );
        c = goog.defineClass.createSealingConstructor_(c, a);
        a && goog.inherits(c, a);
        delete b.constructor;
        delete b.statics;
        goog.defineClass.applyProperties_(c.prototype, b);
        null != d && (d instanceof Function ? d(c) : goog.defineClass.applyProperties_(c, d));
        return c
    }
    ;
    goog.defineClass.SEAL_CLASS_INSTANCES = goog.DEBUG;
    goog.defineClass.createSealingConstructor_ = function(a, b) {
        if (goog.defineClass.SEAL_CLASS_INSTANCES && Object.seal instanceof Function) {
            if (b && b.prototype && b.prototype[goog.UNSEALABLE_CONSTRUCTOR_PROPERTY_])
                return a;
            var c = function() {
                var b = a.apply(this, arguments) || this;
                b[goog.UID_PROPERTY_] = b[goog.UID_PROPERTY_];
                this.constructor === c && Object.seal(b);
                return b
            };
            return c
        }
        return a
    }
    ;
    goog.defineClass.OBJECT_PROTOTYPE_FIELDS_ = "constructor hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString toString valueOf".split(" ");
    goog.defineClass.applyProperties_ = function(a, b) {
        for (var c in b)
            Object.prototype.hasOwnProperty.call(b, c) && (a[c] = b[c]);
        for (var d = 0; d < goog.defineClass.OBJECT_PROTOTYPE_FIELDS_.length; d++)
            c = goog.defineClass.OBJECT_PROTOTYPE_FIELDS_[d],
            Object.prototype.hasOwnProperty.call(b, c) && (a[c] = b[c])
    }
    ;
    goog.tagUnsealableClass = function(a) {
        !COMPILED && goog.defineClass.SEAL_CLASS_INSTANCES && (a.prototype[goog.UNSEALABLE_CONSTRUCTOR_PROPERTY_] = !0)
    }
    ;
    goog.UNSEALABLE_CONSTRUCTOR_PROPERTY_ = "goog_defineClass_legacy_unsealable";
    var webfont = {
        DomHelper: function(a, b) {
            this.mainWindow_ = a;
            this.loadWindow_ = b || a;
            this.document_ = this.loadWindow_.document
        }
    };
    webfont.DomHelper.CAN_WAIT_STYLESHEET = !!window.FontFace;
    webfont.DomHelper.prototype.createElement = function(a, b, c) {
        a = this.document_.createElement(a);
        if (b)
            for (var d in b)
                b.hasOwnProperty(d) && ("style" == d ? this.setStyle(a, b[d]) : a.setAttribute(d, b[d]));
        c && a.appendChild(this.document_.createTextNode(c));
        return a
    }
    ;
    webfont.DomHelper.prototype.insertInto = function(a, b) {
        var c = this.document_.getElementsByTagName(a)[0];
        c || (c = document.documentElement);
        c.insertBefore(b, c.lastChild);
        return !0
    }
    ;
    webfont.DomHelper.prototype.whenBodyExists = function(a) {
        var b = this;
        b.document_.body ? a() : b.document_.addEventListener ? b.document_.addEventListener("DOMContentLoaded", a) : b.document_.attachEvent("onreadystatechange", function() {
            "interactive" != b.document_.readyState && "complete" != b.document_.readyState || a()
        })
    }
    ;
    webfont.DomHelper.prototype.removeElement = function(a) {
        return a.parentNode ? (a.parentNode.removeChild(a),
        !0) : !1
    }
    ;
    webfont.DomHelper.prototype.appendClassName = function(a, b) {
        this.updateClassName(a, [b])
    }
    ;
    webfont.DomHelper.prototype.removeClassName = function(a, b) {
        this.updateClassName(a, null, [b])
    }
    ;
    webfont.DomHelper.prototype.updateClassName = function(a, b, c) {
        b = b || [];
        c = c || [];
        for (var d = a.className.split(/\s+/), e = 0; e < b.length; e += 1) {
            for (var f = !1, g = 0; g < d.length; g += 1)
                if (b[e] === d[g]) {
                    f = !0;
                    break
                }
            f || d.push(b[e])
        }
        b = [];
        for (e = 0; e < d.length; e += 1) {
            f = !1;
            for (g = 0; g < c.length; g += 1)
                if (d[e] === c[g]) {
                    f = !0;
                    break
                }
            f || b.push(d[e])
        }
        a.className = b.join(" ").replace(/\s+/g, " ").replace(/^\s+|\s+$/, "")
    }
    ;
    webfont.DomHelper.prototype.hasClassName = function(a, b) {
        for (var c = a.className.split(/\s+/), d = 0, e = c.length; d < e; d++)
            if (c[d] == b)
                return !0;
        return !1
    }
    ;
    webfont.DomHelper.prototype.setStyle = function(a, b) {
        a.style.cssText = b
    }
    ;
    webfont.DomHelper.prototype.getMainWindow = function() {
        return this.mainWindow_
    }
    ;
    webfont.DomHelper.prototype.getLoadWindow = function() {
        return this.loadWindow_
    }
    ;
    webfont.DomHelper.prototype.getHostName = function() {
        return this.getLoadWindow().location.hostname || this.getMainWindow().location.hostname
    }
    ;
    webfont.DomHelper.prototype.createStyle = function(a) {
        var b = this.createElement("style");
        b.setAttribute("type", "text/css");
        b.styleSheet ? b.styleSheet.cssText = a : b.appendChild(document.createTextNode(a));
        return b
    }
    ;
    webfont.DomHelper.prototype.loadStylesheet = function(a, b, c) {
        function d() {
            n && k && l && (n(m),
            n = null)
        }
        function e(b) {
            for (var c = 0; c < h.length; c++)
                if (h[c].href && -1 !== h[c].href.indexOf(a))
                    return b();
            setTimeout(function() {
                e(b)
            }, 0)
        }
        function f(b) {
            for (var c = 0; c < h.length; c++)
                if (h[c].href && -1 !== h[c].href.indexOf(a) && h[c].media) {
                    var d = h[c].media;
                    if ("all" === d || d.mediaText && "all" === d.mediaText)
                        return b()
                }
            setTimeout(function() {
                f(b)
            }, 0)
        }
        var g = this.createElement("link", {
            rel: "stylesheet",
            href: a,
            media: c ? "only x" : "all"
        })
          , h = this.document_.styleSheets
          , k = !1
          , l = !c
          , m = null
          , n = b || null;
        webfont.DomHelper.CAN_WAIT_STYLESHEET ? (g.onload = function() {
            k = !0;
            d()
        }
        ,
        g.onerror = function() {
            k = !0;
            m = Error("Stylesheet failed to load");
            d()
        }
        ) : setTimeout(function() {
            k = !0;
            d()
        }, 0);
        this.insertInto("head", g);
        c && e(function() {
            g.media = "all";
            f(function() {
                l = !0;
                d()
            })
        });
        return g
    }
    ;
    webfont.DomHelper.prototype.loadScript = function(a, b, c) {
        var d = this.document_.getElementsByTagName("head")[0];
        if (d) {
            var e = this.createElement("script", {
                src: a
            })
              , f = !1;
            e.onload = e.onreadystatechange = function() {
                f || this.readyState && "loaded" != this.readyState && "complete" != this.readyState || (f = !0,
                b && b(null),
                e.onload = e.onreadystatechange = null,
                "HEAD" == e.parentNode.tagName && d.removeChild(e))
            }
            ;
            d.appendChild(e);
            setTimeout(function() {
                f || (f = !0,
                b && b(Error("Script load timeout")))
            }, c || 5E3);
            return e
        }
        return null
    }
    ;
    webfont.StyleSheetWaiter = function() {
        this.waitingCount_ = 0;
        this.onReady_ = null
    }
    ;
    webfont.StyleSheetWaiter.prototype.startWaitingLoad = function() {
        var a = this;
        a.waitingCount_++;
        return function(b) {
            a.waitingCount_--;
            a.fireIfReady_()
        }
    }
    ;
    webfont.StyleSheetWaiter.prototype.waitWhileNeededThen = function(a) {
        this.onReady_ = a;
        this.fireIfReady_()
    }
    ;
    webfont.StyleSheetWaiter.prototype.fireIfReady_ = function() {
        0 == this.waitingCount_ && this.onReady_ && (this.onReady_(),
        this.onReady_ = null)
    }
    ;
    webfont.CssClassName = function(a) {
        this.joinChar_ = a || webfont.CssClassName.DEFAULT_JOIN_CHAR
    }
    ;
    webfont.CssClassName.DEFAULT_JOIN_CHAR = "-";
    webfont.CssClassName.prototype.sanitize = function(a) {
        return a.replace(/[\W_]+/g, "").toLowerCase()
    }
    ;
    webfont.CssClassName.prototype.build = function(a) {
        for (var b = [], c = 0; c < arguments.length; c++)
            b.push(this.sanitize(arguments[c]));
        return b.join(this.joinChar_)
    }
    ;
    webfont.Font = function(a, b) {
        this.name_ = a;
        this.weight_ = 4;
        this.style_ = "n";
        var c = (b || "n4").match(/^([nio])([1-9])$/i);
        c && (this.style_ = c[1],
        this.weight_ = parseInt(c[2], 10))
    }
    ;
    webfont.Font.prototype.getName = function() {
        return this.name_
    }
    ;
    webfont.Font.prototype.getCssName = function() {
        return this.quote_(this.name_)
    }
    ;
    webfont.Font.prototype.toCssString = function() {
        return this.getCssStyle() + " " + this.getCssWeight() + " 300px " + this.getCssName()
    }
    ;
    webfont.Font.prototype.quote_ = function(a) {
        var b = [];
        a = a.split(/,\s*/);
        for (var c = 0; c < a.length; c++) {
            var d = a[c].replace(/['"]/g, "");
            -1 != d.indexOf(" ") || /^\d/.test(d) ? b.push("'" + d + "'") : b.push(d)
        }
        return b.join(",")
    }
    ;
    webfont.Font.prototype.getVariation = function() {
        return this.style_ + this.weight_
    }
    ;
    webfont.Font.prototype.getCssVariation = function() {
        return "font-style:" + this.getCssStyle() + ";font-weight:" + this.getCssWeight() + ";"
    }
    ;
    webfont.Font.prototype.getCssWeight = function() {
        return this.weight_ + "00"
    }
    ;
    webfont.Font.prototype.getCssStyle = function() {
        var a = "normal";
        "o" === this.style_ ? a = "oblique" : "i" === this.style_ && (a = "italic");
        return a
    }
    ;
    webfont.Font.parseCssVariation = function(a) {
        var b = 4
          , c = "n"
          , d = null;
        a && ((d = a.match(/(normal|oblique|italic)/i)) && d[1] && (c = d[1].substr(0, 1).toLowerCase()),
        (d = a.match(/([1-9]00|normal|bold)/i)) && d[1] && (/bold/i.test(d[1]) ? b = 7 : /[1-9]00/.test(d[1]) && (b = parseInt(d[1].substr(0, 1), 10))));
        return c + b
    }
    ;
    webfont.EventDispatcher = function(a, b) {
        this.domHelper_ = a;
        this.htmlElement_ = a.getLoadWindow().document.documentElement;
        this.callbacks_ = b;
        this.namespace_ = webfont.EventDispatcher.DEFAULT_NAMESPACE;
        this.cssClassName_ = new webfont.CssClassName("-");
        this.dispatchEvents_ = !1 !== b.events;
        this.setClasses_ = !1 !== b.classes
    }
    ;
    webfont.EventDispatcher.DEFAULT_NAMESPACE = "wf";
    webfont.EventDispatcher.LOADING = "loading";
    webfont.EventDispatcher.ACTIVE = "active";
    webfont.EventDispatcher.INACTIVE = "inactive";
    webfont.EventDispatcher.FONT = "font";
    webfont.EventDispatcher.prototype.dispatchLoading = function() {
        this.setClasses_ && this.domHelper_.updateClassName(this.htmlElement_, [this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.LOADING)]);
        this.dispatch_(webfont.EventDispatcher.LOADING)
    }
    ;
    webfont.EventDispatcher.prototype.dispatchFontLoading = function(a) {
        this.setClasses_ && this.domHelper_.updateClassName(this.htmlElement_, [this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.LOADING)]);
        this.dispatch_(webfont.EventDispatcher.FONT + webfont.EventDispatcher.LOADING, a)
    }
    ;
    webfont.EventDispatcher.prototype.dispatchFontActive = function(a) {
        this.setClasses_ && this.domHelper_.updateClassName(this.htmlElement_, [this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.ACTIVE)], [this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.LOADING), this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.INACTIVE)]);
        this.dispatch_(webfont.EventDispatcher.FONT + webfont.EventDispatcher.ACTIVE, a)
    }
    ;
    webfont.EventDispatcher.prototype.dispatchFontInactive = function(a) {
        if (this.setClasses_) {
            var b = this.domHelper_.hasClassName(this.htmlElement_, this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.ACTIVE))
              , c = []
              , d = [this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.LOADING)];
            b || c.push(this.cssClassName_.build(this.namespace_, a.getName(), a.getVariation().toString(), webfont.EventDispatcher.INACTIVE));
            this.domHelper_.updateClassName(this.htmlElement_, c, d)
        }
        this.dispatch_(webfont.EventDispatcher.FONT + webfont.EventDispatcher.INACTIVE, a)
    }
    ;
    webfont.EventDispatcher.prototype.dispatchInactive = function() {
        if (this.setClasses_) {
            var a = this.domHelper_.hasClassName(this.htmlElement_, this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.ACTIVE))
              , b = []
              , c = [this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.LOADING)];
            a || b.push(this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.INACTIVE));
            this.domHelper_.updateClassName(this.htmlElement_, b, c)
        }
        this.dispatch_(webfont.EventDispatcher.INACTIVE)
    }
    ;
    webfont.EventDispatcher.prototype.dispatchActive = function() {
        this.setClasses_ && this.domHelper_.updateClassName(this.htmlElement_, [this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.ACTIVE)], [this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.LOADING), this.cssClassName_.build(this.namespace_, webfont.EventDispatcher.INACTIVE)]);
        this.dispatch_(webfont.EventDispatcher.ACTIVE)
    }
    ;
    webfont.EventDispatcher.prototype.dispatch_ = function(a, b) {
        if (this.dispatchEvents_ && this.callbacks_[a])
            if (b)
                this.callbacks_[a](b.getName(), b.getVariation());
            else
                this.callbacks_[a]()
    }
    ;
    webfont.FontModule = function() {}
    ;
    webfont.FontModule.prototype.load = function(a) {}
    ;
    webfont.FontModuleLoader = function() {
        this.modules_ = {}
    }
    ;
    webfont.FontModuleLoader.prototype.addModuleFactory = function(a, b) {
        this.modules_[a] = b
    }
    ;
    webfont.FontModuleLoader.prototype.getModules = function(a, b) {
        var c = [], d;
        for (d in a)
            if (a.hasOwnProperty(d)) {
                var e = this.modules_[d];
                e && c.push(e(a[d], b))
            }
        return c
    }
    ;
    webfont.FontRuler = function(a, b) {
        this.domHelper_ = a;
        this.fontTestString_ = b;
        this.el_ = this.domHelper_.createElement("span", {
            "aria-hidden": "true"
        }, this.fontTestString_)
    }
    ;
    webfont.FontRuler.prototype.setFont = function(a) {
        this.domHelper_.setStyle(this.el_, this.computeStyleString_(a))
    }
    ;
    webfont.FontRuler.prototype.insert = function() {
        this.domHelper_.insertInto("body", this.el_)
    }
    ;
    webfont.FontRuler.prototype.computeStyleString_ = function(a) {
        return "display:block;position:absolute;top:-9999px;left:-9999px;font-size:300px;width:auto;height:auto;line-height:normal;margin:0;padding:0;font-variant:normal;white-space:nowrap;font-family:" + a.getCssName() + ";" + a.getCssVariation()
    }
    ;
    webfont.FontRuler.prototype.getWidth = function() {
        return this.el_.offsetWidth
    }
    ;
    webfont.FontRuler.prototype.remove = function() {
        this.domHelper_.removeElement(this.el_)
    }
    ;
    webfont.NativeFontWatchRunner = function(a, b, c, d, e, f) {
        this.activeCallback_ = a;
        this.inactiveCallback_ = b;
        this.font_ = d;
        this.domHelper_ = c;
        this.timeout_ = e || 3E3;
        this.fontTestString_ = f || void 0
    }
    ;
    webfont.NativeFontWatchRunner.prototype.start = function() {
        var a = this.domHelper_.getLoadWindow().document
          , b = this
          , c = goog.now()
          , d = new Promise(function(d, e) {
            var f = function() {
                goog.now() - c >= b.timeout_ ? e() : a.fonts.load(b.font_.toCssString(), b.fontTestString_).then(function(a) {
                    1 <= a.length ? d() : setTimeout(f, 25)
                }, function() {
                    e()
                })
            };
            f()
        }
        )
          , e = null
          , f = new Promise(function(a, c) {
            e = setTimeout(c, b.timeout_)
        }
        );
        Promise.race([f, d]).then(function() {
            e && (clearTimeout(e),
            e = null);
            b.activeCallback_(b.font_)
        }, function() {
			console.log("WebFont.inactive: " + b.font_.toCssString() + ", testString: '" + b.fontTestString_ + "'");
            b.inactiveCallback_(b.font_)
        })
    }
    ;
    webfont.FontWatchRunner = function(a, b, c, d, e, f, g) {
        this.activeCallback_ = a;
        this.inactiveCallback_ = b;
        this.domHelper_ = c;
        this.font_ = d;
        this.fontTestString_ = g || webfont.FontWatchRunner.DEFAULT_TEST_STRING;
        this.lastResortWidths_ = {};
        this.timeout_ = e || 3E3;
        this.metricCompatibleFonts_ = f || null;
        this.lastResortRulerB_ = this.lastResortRulerA_ = this.fontRulerB_ = this.fontRulerA_ = null;
        this.setupRulers_()
    }
    ;
    webfont.FontWatchRunner.LastResortFonts = {
        SERIF: "serif",
        SANS_SERIF: "sans-serif"
    };
    webfont.FontWatchRunner.DEFAULT_TEST_STRING = "BESbswy";
    webfont.FontWatchRunner.HAS_WEBKIT_FALLBACK_BUG = null;
    webfont.FontWatchRunner.getUserAgent = function() {
        return window.navigator.userAgent
    }
    ;
    webfont.FontWatchRunner.hasWebKitFallbackBug = function() {
        if (null === webfont.FontWatchRunner.HAS_WEBKIT_FALLBACK_BUG) {
            var a = /AppleWebKit\/([0-9]+)(?:\.([0-9]+))/.exec(webfont.FontWatchRunner.getUserAgent());
            webfont.FontWatchRunner.HAS_WEBKIT_FALLBACK_BUG = !!a && (536 > parseInt(a[1], 10) || 536 === parseInt(a[1], 10) && 11 >= parseInt(a[2], 10))
        }
        return webfont.FontWatchRunner.HAS_WEBKIT_FALLBACK_BUG
    }
    ;
    webfont.FontWatchRunner.prototype.setupRulers_ = function() {
        this.fontRulerA_ = new webfont.FontRuler(this.domHelper_,this.fontTestString_);
        this.fontRulerB_ = new webfont.FontRuler(this.domHelper_,this.fontTestString_);
        this.lastResortRulerA_ = new webfont.FontRuler(this.domHelper_,this.fontTestString_);
        this.lastResortRulerB_ = new webfont.FontRuler(this.domHelper_,this.fontTestString_);
        this.fontRulerA_.setFont(new webfont.Font(this.font_.getName() + "," + webfont.FontWatchRunner.LastResortFonts.SERIF,this.font_.getVariation()));
        this.fontRulerB_.setFont(new webfont.Font(this.font_.getName() + "," + webfont.FontWatchRunner.LastResortFonts.SANS_SERIF,this.font_.getVariation()));
        this.lastResortRulerA_.setFont(new webfont.Font(webfont.FontWatchRunner.LastResortFonts.SERIF,this.font_.getVariation()));
        this.lastResortRulerB_.setFont(new webfont.Font(webfont.FontWatchRunner.LastResortFonts.SANS_SERIF,this.font_.getVariation()));
        this.fontRulerA_.insert();
        this.fontRulerB_.insert();
        this.lastResortRulerA_.insert();
        this.lastResortRulerB_.insert()
    }
    ;
    webfont.FontWatchRunner.prototype.start = function() {
        this.lastResortWidths_[webfont.FontWatchRunner.LastResortFonts.SERIF] = this.lastResortRulerA_.getWidth();
        this.lastResortWidths_[webfont.FontWatchRunner.LastResortFonts.SANS_SERIF] = this.lastResortRulerB_.getWidth();
        this.started_ = goog.now();
        this.check_()
    }
    ;
    webfont.FontWatchRunner.prototype.widthMatches_ = function(a, b) {
        return a === this.lastResortWidths_[b]
    }
    ;
    webfont.FontWatchRunner.prototype.widthsMatchLastResortWidths_ = function(a, b) {
        for (var c in webfont.FontWatchRunner.LastResortFonts)
            if (webfont.FontWatchRunner.LastResortFonts.hasOwnProperty(c) && this.widthMatches_(a, webfont.FontWatchRunner.LastResortFonts[c]) && this.widthMatches_(b, webfont.FontWatchRunner.LastResortFonts[c]))
                return !0;
        return !1
    }
    ;
    webfont.FontWatchRunner.prototype.hasTimedOut_ = function() {
        return goog.now() - this.started_ >= this.timeout_
    }
    ;
    webfont.FontWatchRunner.prototype.isFallbackFont_ = function(a, b) {
        return this.widthMatches_(a, webfont.FontWatchRunner.LastResortFonts.SERIF) && this.widthMatches_(b, webfont.FontWatchRunner.LastResortFonts.SANS_SERIF)
    }
    ;
    webfont.FontWatchRunner.prototype.isLastResortFont_ = function(a, b) {
        return webfont.FontWatchRunner.hasWebKitFallbackBug() && this.widthsMatchLastResortWidths_(a, b)
    }
    ;
    webfont.FontWatchRunner.prototype.isMetricCompatibleFont_ = function() {
        return null === this.metricCompatibleFonts_ || this.metricCompatibleFonts_.hasOwnProperty(this.font_.getName())
    }
    ;
    webfont.FontWatchRunner.prototype.check_ = function() {
        var a = this.fontRulerA_.getWidth()
          , b = this.fontRulerB_.getWidth();
        this.isFallbackFont_(a, b) || this.isLastResortFont_(a, b) ? this.hasTimedOut_() ? this.isLastResortFont_(a, b) && this.isMetricCompatibleFont_() ? this.finish_(this.activeCallback_) : this.finish_(this.inactiveCallback_) : this.asyncCheck_() : this.finish_(this.activeCallback_)
    }
    ;
    webfont.FontWatchRunner.prototype.asyncCheck_ = function() {
        setTimeout(goog.bind(function() {
            this.check_()
        }, this), 50)
    }
    ;
    webfont.FontWatchRunner.prototype.finish_ = function(a) {
        setTimeout(goog.bind(function() {
            this.fontRulerA_.remove();
            this.fontRulerB_.remove();
            this.lastResortRulerA_.remove();
            this.lastResortRulerB_.remove();
            a(this.font_)
        }, this), 0)
    }
    ;
    webfont.FontWatcher = function(a, b, c) {
        this.domHelper_ = a;
        this.eventDispatcher_ = b;
        this.currentlyWatched_ = 0;
        this.success_ = this.last_ = !1;
        this.timeout_ = c
    }
    ;
    webfont.FontWatcher.SHOULD_USE_NATIVE_LOADER = null;
    webfont.FontWatcher.getUserAgent = function() {
        return window.navigator.userAgent
    }
    ;
    webfont.FontWatcher.getVendor = function() {
        return window.navigator.vendor
    }
    ;
    webfont.FontWatcher.shouldUseNativeLoader = function() {
        if (null === webfont.FontWatcher.SHOULD_USE_NATIVE_LOADER)
            if (window.FontFace) {
                var a = /Gecko.*Firefox\/(\d+)/.exec(webfont.FontWatcher.getUserAgent())
                  , b = /OS X.*Version\/10\..*Safari/.exec(webfont.FontWatcher.getUserAgent()) && /Apple/.exec(webfont.FontWatcher.getVendor());
                webfont.FontWatcher.SHOULD_USE_NATIVE_LOADER = a ? 42 < parseInt(a[1], 10) : b ? !1 : !0
            } else
                webfont.FontWatcher.SHOULD_USE_NATIVE_LOADER = !1;
        return webfont.FontWatcher.SHOULD_USE_NATIVE_LOADER
    }
    ;
    webfont.FontWatcher.prototype.watchFonts = function(a, b, c, d) {
        b = b || {};
        if (0 === a.length && d)
            this.eventDispatcher_.dispatchInactive();
        else {
            this.currentlyWatched_ += a.length;
            d && (this.last_ = d);
            var e = [];
            for (d = 0; d < a.length; d++) {
                var f = a[d]
                  , g = b[f.getName()];
                this.eventDispatcher_.dispatchFontLoading(f);
                var h = null
                  , h = webfont.FontWatcher.shouldUseNativeLoader() ? new webfont.NativeFontWatchRunner(goog.bind(this.fontActive_, this),goog.bind(this.fontInactive_, this),this.domHelper_,f,this.timeout_,g) : new webfont.FontWatchRunner(goog.bind(this.fontActive_, this),goog.bind(this.fontInactive_, this),this.domHelper_,f,this.timeout_,c,g);
                e.push(h)
            }
            for (d = 0; d < e.length; d++)
                e[d].start()
        }
    }
    ;
    webfont.FontWatcher.prototype.fontActive_ = function(a) {
        this.eventDispatcher_.dispatchFontActive(a);
        this.success_ = !0;
        this.decreaseCurrentlyWatched_()
    }
    ;
    webfont.FontWatcher.prototype.fontInactive_ = function(a) {
        this.eventDispatcher_.dispatchFontInactive(a);
        this.decreaseCurrentlyWatched_()
    }
    ;
    webfont.FontWatcher.prototype.decreaseCurrentlyWatched_ = function() {
        0 == --this.currentlyWatched_ && this.last_ && (this.success_ ? this.eventDispatcher_.dispatchActive() : this.eventDispatcher_.dispatchInactive())
    }
    ;
    webfont.WebFont = function(a) {
        this.mainWindow_ = a;
        this.fontModuleLoader_ = new webfont.FontModuleLoader;
        this.moduleLoading_ = 0;
        this.classes_ = this.events_ = !0
    }
    ;
    webfont.WebFont.prototype.addModule = function(a, b) {
        this.fontModuleLoader_.addModuleFactory(a, b)
    }
    ;
    webfont.WebFont.prototype.load = function(a) {
		console.log("WebFont.load called with config: " + JSON.stringify(a));
        this.domHelper_ = new webfont.DomHelper(this.mainWindow_,a.context || this.mainWindow_);
        this.events_ = !1 !== a.events;
        this.classes_ = !1 !== a.classes;
        var b = new webfont.EventDispatcher(this.domHelper_,a);
        this.load_(b, a)
    }
    ;
    webfont.WebFont.prototype.onModuleReady_ = function(a, b, c, d, e) {
        var f = 0 == --this.moduleLoading_;
        (this.classes_ || this.events_) && setTimeout(function() {
            b.watchFonts(c, d || null, e || null, f)
        }, 0)
    }
    ;
    webfont.WebFont.prototype.load_ = function(a, b) {
        var c = []
          , d = b.timeout
          , e = this;
        a.dispatchLoading();
        var c = this.fontModuleLoader_.getModules(b, this.domHelper_)
          , f = new webfont.FontWatcher(this.domHelper_,a,d);
        this.moduleLoading_ = c.length;
        for (var d = 0, g = c.length; d < g; d++)
            c[d].load(function(b, c, d) {
                e.onModuleReady_(a, f, b, c, d)
            })
    }
    ;
    webfont.modules = {};
    webfont.modules.Monotype = function(a, b) {
        this.domHelper_ = a;
        this.configuration_ = b
    }
    ;
    webfont.modules.Monotype.NAME = "monotype";
    webfont.modules.Monotype.HOOK = "__mti_fntLst";
    webfont.modules.Monotype.SCRIPTID = "__MonotypeAPIScript__";
    webfont.modules.Monotype.CONFIGURATION = "__MonotypeConfiguration__";
    webfont.modules.Monotype.prototype.getScriptSrc = function(a, b) {
        return (this.configuration_.api || "https://fast.fonts.net/jsapi") + "/" + a + ".js" + (b ? "?v=" + b : "")
    }
    ;
    webfont.modules.Monotype.prototype.load = function(a) {
        function b() {
            if (f[webfont.modules.Monotype.HOOK + d]) {
                var c = f[webfont.modules.Monotype.HOOK + d](), e = [], k;
                if (c)
                    for (var l = 0; l < c.length; l++) {
                        var m = c[l].fontfamily;
                        void 0 != c[l].fontStyle && void 0 != c[l].fontWeight ? (k = c[l].fontStyle + c[l].fontWeight,
                        e.push(new webfont.Font(m,k))) : e.push(new webfont.Font(m))
                    }
                a(e)
            } else
                setTimeout(function() {
                    b()
                }, 50)
        }
        var c = this
          , d = c.configuration_.projectId
          , e = c.configuration_.version;
        if (d) {
            var f = c.domHelper_.getLoadWindow();
            this.domHelper_.loadScript(c.getScriptSrc(d, e), function(e) {
                e ? a([]) : (f[webfont.modules.Monotype.CONFIGURATION + d] = function() {
                    return c.configuration_
                }
                ,
                b())
            }).id = webfont.modules.Monotype.SCRIPTID + d
        } else
            a([])
    }
    ;
    webfont.modules.Custom = function(a, b) {
        this.domHelper_ = a;
        this.configuration_ = b
    }
    ;
    webfont.modules.Custom.NAME = "custom";
    webfont.modules.Custom.prototype.load = function(a) {
        var b, c, d = this.configuration_.urls || [], e = this.configuration_.families || [], f = this.configuration_.testStrings || {}, g = new webfont.StyleSheetWaiter;
        b = 0;
        for (c = d.length; b < c; b++)
            this.domHelper_.loadStylesheet(d[b], g.startWaitingLoad());
        var h = [];
        b = 0;
        for (c = e.length; b < c; b++)
            if (d = e[b].split(":"),
            d[1])
                for (var k = d[1].split(","), l = 0; l < k.length; l += 1)
                    h.push(new webfont.Font(d[0],k[l]));
            else
                h.push(new webfont.Font(d[0]));
        g.waitWhileNeededThen(function() {
            a(h, f)
        })
    }
    ;
    webfont.modules.google = {};
    webfont.modules.google.FontApiUrlBuilder = function(a, b) {
        this.apiUrl_ = a ? a : webfont.modules.google.FontApiUrlBuilder.DEFAULT_API_URL;
        this.fontFamilies_ = [];
        this.subsets_ = [];
        this.text_ = b || ""
    }
    ;
    webfont.modules.google.FontApiUrlBuilder.DEFAULT_API_URL = "https://fonts.googleapis.com/css";
    webfont.modules.google.FontApiUrlBuilder.prototype.setFontFamilies = function(a) {
        this.parseFontFamilies_(a)
    }
    ;
    webfont.modules.google.FontApiUrlBuilder.prototype.parseFontFamilies_ = function(a) {
        for (var b = a.length, c = 0; c < b; c++) {
            var d = a[c].split(":");
            3 == d.length && this.subsets_.push(d.pop());
            var e = "";
            2 == d.length && "" != d[1] && (e = ":");
            this.fontFamilies_.push(d.join(e))
        }
    }
    ;
    webfont.modules.google.FontApiUrlBuilder.prototype.webSafe = function(a) {
        return a.replace(/ /g, "+")
    }
    ;
    webfont.modules.google.FontApiUrlBuilder.prototype.build = function() {
        if (0 == this.fontFamilies_.length)
            throw Error("No fonts to load!");
        if (-1 != this.apiUrl_.indexOf("kit="))
            return this.apiUrl_;
        for (var a = this.fontFamilies_.length, b = [], c = 0; c < a; c++)
            b.push(this.webSafe(this.fontFamilies_[c]));
        a = this.apiUrl_ + "?family=" + b.join("%7C");
        0 < this.subsets_.length && (a += "&subset=" + this.subsets_.join(","));
        0 < this.text_.length && (a += "&text=" + encodeURIComponent(this.text_));
        return a
    }
    ;
    webfont.modules.google.FontApiParser = function(a) {
        this.fontFamilies_ = a;
        this.parsedFonts_ = [];
        this.fontTestStrings_ = {}
    }
    ;
    webfont.modules.google.FontApiParser.INT_FONTS = {
        latin: webfont.FontWatchRunner.DEFAULT_TEST_STRING,
        "latin-ext": "\u00e7\u00f6\u00fc\u011f\u015f",
        cyrillic: "\u0439\u044f\u0416",
        greek: "\u03b1\u03b2\u03a3",
        khmer: "\u1780\u1781\u1782",
        Hanuman: "\u1780\u1781\u1782"
    };
    webfont.modules.google.FontApiParser.WEIGHTS = {
        thin: "1",
        extralight: "2",
        "extra-light": "2",
        ultralight: "2",
        "ultra-light": "2",
        light: "3",
        regular: "4",
        book: "4",
        medium: "5",
        "semi-bold": "6",
        semibold: "6",
        "demi-bold": "6",
        demibold: "6",
        bold: "7",
        "extra-bold": "8",
        extrabold: "8",
        "ultra-bold": "8",
        ultrabold: "8",
        black: "9",
        heavy: "9",
        l: "3",
        r: "4",
        b: "7"
    };
    webfont.modules.google.FontApiParser.STYLES = {
        i: "i",
        italic: "i",
        n: "n",
        normal: "n"
    };
    webfont.modules.google.FontApiParser.VARIATION_MATCH = /^(thin|(?:(?:extra|ultra)-?)?light|regular|book|medium|(?:(?:semi|demi|extra|ultra)-?)?bold|black|heavy|l|r|b|[1-9]00)?(n|i|normal|italic)?$/;
    webfont.modules.google.FontApiParser.prototype.parse = function() {
        for (var a = this.fontFamilies_.length, b = 0; b < a; b++) {
            var c = this.fontFamilies_[b].split(":")
              , d = c[0].replace(/\+/g, " ")
              , e = ["n4"];
            if (2 <= c.length) {
                var f = this.parseVariations_(c[1]);
                0 < f.length && (e = f);
                3 == c.length && (c = this.parseSubsets_(c[2]),
                0 < c.length && (c = webfont.modules.google.FontApiParser.INT_FONTS[c[0]]) && (this.fontTestStrings_[d] = c))
            }
            this.fontTestStrings_[d] || (c = webfont.modules.google.FontApiParser.INT_FONTS[d]) && (this.fontTestStrings_[d] = c);
            for (c = 0; c < e.length; c += 1)
                this.parsedFonts_.push(new webfont.Font(d,e[c]))
        }
    }
    ;
    webfont.modules.google.FontApiParser.prototype.generateFontVariationDescription_ = function(a) {
        if (!a.match(/^[\w-]+$/))
            return "";
        a = a.toLowerCase();
        var b = webfont.modules.google.FontApiParser.VARIATION_MATCH.exec(a);
        if (null == b)
            return "";
        a = this.normalizeStyle_(b[2]);
        b = this.normalizeWeight_(b[1]);
        return [a, b].join("")
    }
    ;
    webfont.modules.google.FontApiParser.prototype.normalizeStyle_ = function(a) {
        return null == a || "" == a ? "n" : webfont.modules.google.FontApiParser.STYLES[a]
    }
    ;
    webfont.modules.google.FontApiParser.prototype.normalizeWeight_ = function(a) {
        if (null == a || "" == a)
            return "4";
        var b = webfont.modules.google.FontApiParser.WEIGHTS[a];
        return b ? b : isNaN(a) ? "4" : a.substr(0, 1)
    }
    ;
    webfont.modules.google.FontApiParser.prototype.parseVariations_ = function(a) {
        var b = [];
        if (!a)
            return b;
        a = a.split(",");
        for (var c = a.length, d = 0; d < c; d++) {
            var e = this.generateFontVariationDescription_(a[d]);
            e && b.push(e)
        }
        return b
    }
    ;
    webfont.modules.google.FontApiParser.prototype.parseSubsets_ = function(a) {
        var b = [];
        return a ? a.split(",") : b
    }
    ;
    webfont.modules.google.FontApiParser.prototype.getFonts = function() {
        return this.parsedFonts_
    }
    ;
    webfont.modules.google.FontApiParser.prototype.getFontTestStrings = function() {
        return this.fontTestStrings_
    }
    ;
    webfont.modules.google.GoogleFontApi = function(a, b) {
        this.domHelper_ = a;
        this.configuration_ = b
    }
    ;
    webfont.modules.google.GoogleFontApi.NAME = "google";
    webfont.modules.google.GoogleFontApi.METRICS_COMPATIBLE_FONTS = {
        Arimo: !0,
        Cousine: !0,
        Tinos: !0
    };
    webfont.modules.google.GoogleFontApi.prototype.load = function(a) {
        var b = new webfont.StyleSheetWaiter
          , c = this.domHelper_
          , d = new webfont.modules.google.FontApiUrlBuilder(this.configuration_.api,this.configuration_.text)
          , e = this.configuration_.families;
        d.setFontFamilies(e);
        var f = new webfont.modules.google.FontApiParser(e);
        f.parse();
        c.loadStylesheet(d.build(), b.startWaitingLoad());
        b.waitWhileNeededThen(function() {
            a(f.getFonts(), f.getFontTestStrings(), webfont.modules.google.GoogleFontApi.METRICS_COMPATIBLE_FONTS)
        })
    }
    ;
    webfont.modules.Typekit = function(a, b) {
        this.domHelper_ = a;
        this.configuration_ = b
    }
    ;
    webfont.modules.Typekit.NAME = "typekit";
    webfont.modules.Typekit.prototype.getScriptSrc = function(a) {
        return (this.configuration_.api || "https://use.typekit.net") + "/" + a + ".js"
    }
    ;
    webfont.modules.Typekit.prototype.load = function(a) {
        var b = this.configuration_.id
          , c = this.domHelper_.getLoadWindow();
        b ? this.domHelper_.loadScript(this.getScriptSrc(b), function(b) {
            if (b)
                a([]);
            else if (c.Typekit && c.Typekit.config && c.Typekit.config.fn) {
                b = c.Typekit.config.fn;
                for (var e = [], f = 0; f < b.length; f += 2)
                    for (var g = b[f], h = b[f + 1], k = 0; k < h.length; k++)
                        e.push(new webfont.Font(g,h[k]));
                try {
                    c.Typekit.load({
                        events: !1,
                        classes: !1,
                        async: !0
                    })
                } catch (l) {}
                a(e)
            }
        }, 2E3) : a([])
    }
    ;
    webfont.modules.Fontdeck = function(a, b) {
        this.domHelper_ = a;
        this.configuration_ = b;
        this.fonts_ = []
    }
    ;
    webfont.modules.Fontdeck.NAME = "fontdeck";
    webfont.modules.Fontdeck.HOOK = "__webfontfontdeckmodule__";
    webfont.modules.Fontdeck.API = "https://f.fontdeck.com/s/css/js/";
    webfont.modules.Fontdeck.prototype.getScriptSrc = function(a) {
        var b = this.domHelper_.getHostName();
        return (this.configuration_.api || webfont.modules.Fontdeck.API) + b + "/" + a + ".js"
    }
    ;
    webfont.modules.Fontdeck.prototype.load = function(a) {
        var b = this.configuration_.id
          , c = this.domHelper_.getLoadWindow()
          , d = this;
        b ? (c[webfont.modules.Fontdeck.HOOK] || (c[webfont.modules.Fontdeck.HOOK] = {}),
        c[webfont.modules.Fontdeck.HOOK][b] = function(b, c) {
            for (var g = 0, h = c.fonts.length; g < h; ++g) {
                var k = c.fonts[g];
                d.fonts_.push(new webfont.Font(k.name,webfont.Font.parseCssVariation("font-weight:" + k.weight + ";font-style:" + k.style)))
            }
            a(d.fonts_)
        }
        ,
        this.domHelper_.loadScript(this.getScriptSrc(b), function(b) {
            b && a([])
        })) : a([])
    }
    ;
    var INCLUDE_CUSTOM_MODULE = !0
      , INCLUDE_FONTDECK_MODULE = !0
      , INCLUDE_MONOTYPE_MODULE = !0
      , INCLUDE_TYPEKIT_MODULE = !0
      , INCLUDE_GOOGLE_MODULE = !0
      , WEBFONT = "WebFont"
      , WEBFONT_CONFIG = "WebFontConfig"
      , webFontLoader = new webfont.WebFont(window);
    INCLUDE_CUSTOM_MODULE && webFontLoader.addModule(webfont.modules.Custom.NAME, function(a, b) {
        return new webfont.modules.Custom(b,a)
    });
    INCLUDE_FONTDECK_MODULE && webFontLoader.addModule(webfont.modules.Fontdeck.NAME, function(a, b) {
        return new webfont.modules.Fontdeck(b,a)
    });
    INCLUDE_MONOTYPE_MODULE && webFontLoader.addModule(webfont.modules.Monotype.NAME, function(a, b) {
        return new webfont.modules.Monotype(b,a)
    });
    INCLUDE_TYPEKIT_MODULE && webFontLoader.addModule(webfont.modules.Typekit.NAME, function(a, b) {
        return new webfont.modules.Typekit(b,a)
    });
    INCLUDE_GOOGLE_MODULE && webFontLoader.addModule(webfont.modules.google.GoogleFontApi.NAME, function(a, b) {
        return new webfont.modules.google.GoogleFontApi(b,a)
    });
    var exports = {
        load: goog.bind(webFontLoader.load, webFontLoader)
    };
    "function" === typeof define && define.amd ? define(function() {
        return exports
    }) : "undefined" !== typeof module && module.exports ? module.exports = exports : (window[WEBFONT] = exports,
    window[WEBFONT_CONFIG] && webFontLoader.load(window[WEBFONT_CONFIG]));
}());
