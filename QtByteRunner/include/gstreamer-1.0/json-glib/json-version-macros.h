/* json-version-macros.h - JSON-GLib symbol versioning macros
 * 
 * This file is part of JSON-GLib
 * Copyright © 2014  Emmanuele Bassi
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __JSON_VERSION_MACROS_H__
#define __JSON_VERSION_MACROS_H__

#if !defined(__JSON_GLIB_INSIDE__) && !defined(JSON_COMPILATION)
#error "Only <json-glib/json-glib.h> can be included directly."
#endif

#include "json-version.h"

#ifndef _JSON_EXTERN
#define _JSON_EXTERN extern
#endif

#ifdef JSON_DISABLE_DEPRECATION_WARNINGS
#define JSON_DEPRECATED _JSON_EXTERN
#define JSON_DEPRECATED_FOR(f) _JSON_EXTERN
#define JSON_UNAVAILABLE(maj,min) _JSON_EXTERN
#else
#define JSON_DEPRECATED G_DEPRECATED _JSON_EXTERN
#define JSON_DEPRECATED_FOR(f) G_DEPRECATED_FOR(f) _JSON_EXTERN
#define JSON_UNAVAILABLE(maj,min) G_UNAVAILABLE(maj,min) _JSON_EXTERN
#endif

/* XXX: Each new cycle should add a new version symbol here */
#define JSON_VERSION_1_0        (G_ENCODE_VERSION (1, 0))

#define JSON_VERSION_1_2        (G_ENCODE_VERSION (1, 2))

/* evaluates to the current stable version; for development cycles,
 * this means the next stable target
 */
#if (JSON_MINOR_VERSION == 99)
#define JSON_VERSION_CUR_STABLE         (G_ENCODE_VERSION (JSON_MAJOR_VERSION + 1, 0))
#elif (JSON_MINOR_VERSION % 2)
#define JSON_VERSION_CUR_STABLE         (G_ENCODE_VERSION (JSON_MAJOR_VERSION, JSON_MINOR_VERSION + 1))
#else
#define JSON_VERSION_CUR_STABLE         (G_ENCODE_VERSION (JSON_MAJOR_VERSION, JSON_MINOR_VERSION))
#endif

/* evaluates to the previous stable version */
#if (JSON_MINOR_VERSION == 99)
#define JSON_VERSION_PREV_STABLE        (G_ENCODE_VERSION (JSON_MAJOR_VERSION + 1, 0))
#elif (JSON_MINOR_VERSION % 2)
#define JSON_VERSION_PREV_STABLE        (G_ENCODE_VERSION (JSON_MAJOR_VERSION, JSON_MINOR_VERSION - 1))
#else
#define JSON_VERSION_PREV_STABLE        (G_ENCODE_VERSION (JSON_MAJOR_VERSION, JSON_MINOR_VERSION - 2))
#endif

/**
 * JSON_VERSION_MIN_REQUIRED:
 *
 * A macro that should be defined by the user prior to including
 * the gdk.h header.
 * The definition should be one of the predefined JSON version
 * macros: %JSON_VERSION_1_0, %JSON_VERSION_1_2,...
 *
 * This macro defines the lower bound for the JSON-GLib API to use.
 *
 * If a function has been deprecated in a newer version of JSON-GLib,
 * it is possible to use this symbol to avoid the compiler warnings
 * without disabling warning for every deprecated function.
 *
 * Since: 1.0
 */
#ifndef JSON_VERSION_MIN_REQUIRED
# define JSON_VERSION_MIN_REQUIRED      (JSON_VERSION_CUR_STABLE)
#endif

/**
 * JSON_VERSION_MAX_ALLOWED:
 *
 * A macro that should be defined by the user prior to including
 * the json-glib.h header.

 * The definition should be one of the predefined JSON-GLib version
 * macros: %JSON_VERSION_1_0, %JSON_VERSION_1_2,...
 *
 * This macro defines the upper bound for the JSON API-GLib to use.
 *
 * If a function has been introduced in a newer version of JSON-GLib,
 * it is possible to use this symbol to get compiler warnings when
 * trying to use that function.
 *
 * Since: 1.0
 */
#ifndef JSON_VERSION_MAX_ALLOWED
# if JSON_VERSION_MIN_REQUIRED > JSON_VERSION_PREV_STABLE
#  define JSON_VERSION_MAX_ALLOWED      (JSON_VERSION_MIN_REQUIRED)
# else
#  define JSON_VERSION_MAX_ALLOWED      (JSON_VERSION_CUR_STABLE)
# endif
#endif

/* sanity checks */
#if JSON_VERSION_MAX_ALLOWED < JSON_VERSION_MIN_REQUIRED
#error "JSON_VERSION_MAX_ALLOWED must be >= JSON_VERSION_MIN_REQUIRED"
#endif
#if JSON_VERSION_MIN_REQUIRED < JSON_VERSION_1_0
#error "JSON_VERSION_MIN_REQUIRED must be >= JSON_VERSION_1_0"
#endif

/* XXX: Every new stable minor release should add a set of macros here */

#if JSON_VERSION_MIN_REQUIRED >= JSON_VERSION_1_0
# define JSON_DEPRECATED_IN_1_0                JSON_DEPRECATED
# define JSON_DEPRECATED_IN_1_0_FOR(f)         JSON_DEPRECATED_FOR(f)
#else
# define JSON_DEPRECATED_IN_1_0                _JSON_EXTERN
# define JSON_DEPRECATED_IN_1_0_FOR(f)         _JSON_EXTERN
#endif

#if JSON_VERSION_MAX_ALLOWED < JSON_VERSION_1_0
# define JSON_AVAILABLE_IN_1_0                 JSON_UNAVAILABLE(1, 0)
#else
# define JSON_AVAILABLE_IN_1_0                 _JSON_EXTERN
#endif

#if JSON_VERSION_MIN_REQUIRED >= JSON_VERSION_1_2
# define JSON_DEPRECATED_IN_1_2                JSON_DEPRECATED
# define JSON_DEPRECATED_IN_1_2_FOR(f)         JSON_DEPRECATED_FOR(f)
#else
# define JSON_DEPRECATED_IN_1_2                _JSON_EXTERN
# define JSON_DEPRECATED_IN_1_2_FOR(f)         _JSON_EXTERN
#endif

#if JSON_VERSION_MAX_ALLOWED < JSON_VERSION_1_2
# define JSON_AVAILABLE_IN_1_2                 JSON_UNAVAILABLE(1, 2)
#else
# define JSON_AVAILABLE_IN_1_2                 _JSON_EXTERN
#endif

#endif /* __JSON_VERSION_MACROS_H__ */
