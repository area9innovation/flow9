/* json-version.h - JSON-GLib versioning information
 * 
 * This file is part of JSON-GLib
 * Copyright (C) 2007  OpenedHand Ltd.
 * Copyright (C) 2009  Intel Corp.
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
 *
 * Author:
 *   Emmanuele Bassi  <ebassi@linux.intel.com>
 */

#ifndef __JSON_VERSION_H__
#define __JSON_VERSION_H__

#if !defined(__JSON_GLIB_INSIDE__) && !defined(JSON_COMPILATION)
#error "Only <json-glib/json-glib.h> can be included directly."
#endif

/**
 * SECTION:json-version
 * @short_description: JSON-GLib version checking
 *
 * JSON-GLib provides macros to check the version of the library
 * at compile-time
 */

/**
 * JSON_MAJOR_VERSION:
 *
 * Json major version component (e.g. 1 if %JSON_VERSION is 1.2.3)
 */
#define JSON_MAJOR_VERSION              (1)

/**
 * JSON_MINOR_VERSION:
 *
 * Json minor version component (e.g. 2 if %JSON_VERSION is 1.2.3)
 */
#define JSON_MINOR_VERSION              (2)

/**
 * JSON_MICRO_VERSION:
 *
 * Json micro version component (e.g. 3 if %JSON_VERSION is 1.2.3)
 */
#define JSON_MICRO_VERSION              (8)

/**
 * JSON_VERSION
 *
 * Json version.
 */
#define JSON_VERSION                    (1.2.8)

/**
 * JSON_VERSION_S:
 *
 * JSON-GLib version, encoded as a string, useful for printing and
 * concatenation.
 */
#define JSON_VERSION_S                  "1.2.8"

#define JSON_ENCODE_VERSION(major,minor,micro) \
        ((major) << 24 | (minor) << 16 | (micro) << 8)

/**
 * JSON_VERSION_HEX:
 *
 * JSON-GLib version, encoded as an hexadecimal number, useful for
 * integer comparisons.
 */
#define JSON_VERSION_HEX \
        (JSON_ENCODE_VERSION (JSON_MAJOR_VERSION, JSON_MINOR_VERSION, JSON_MICRO_VERSION))

/**
 * JSON_CHECK_VERSION:
 * @major: required major version
 * @minor: required minor version
 * @micro: required micro version
 *
 * Compile-time version checking. Evaluates to %TRUE if the version
 * of Json is greater than the required one.
 */
#define JSON_CHECK_VERSION(major,minor,micro)   \
        (JSON_MAJOR_VERSION > (major) || \
         (JSON_MAJOR_VERSION == (major) && JSON_MINOR_VERSION > (minor)) || \
         (JSON_MAJOR_VERSION == (major) && JSON_MINOR_VERSION == (minor) && \
          JSON_MICRO_VERSION >= (micro)))

#endif /* __JSON_VERSION_H__ */
