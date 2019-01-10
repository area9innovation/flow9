/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2007 Red Hat, Inc.
 */

#ifndef SOUP_VALUE_UTILS_H
#define SOUP_VALUE_UTILS_H 1

#include <libsoup/soup-types.h>
#include <gobject/gvaluecollector.h>

G_BEGIN_DECLS

#define SOUP_VALUE_SETV(val, type, args)				\
G_STMT_START {								\
	char *setv_error = NULL;					\
									\
	memset (val, 0, sizeof (GValue));				\
	g_value_init (val, type);					\
	G_VALUE_COLLECT (val, args, G_VALUE_NOCOPY_CONTENTS, &setv_error);	\
	g_free (setv_error);						\
} G_STMT_END

#define SOUP_VALUE_GETV(val, type, args)				\
G_STMT_START {								\
	char *getv_error = NULL;					\
									\
	G_VALUE_LCOPY (val, args, G_VALUE_NOCOPY_CONTENTS, &getv_error);	\
	g_free (getv_error);						\
} G_STMT_END

SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GHashTable  *soup_value_hash_new            (void);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GHashTable  *soup_value_hash_new_with_vals  (const char  *first_key,
					     ...) G_GNUC_NULL_TERMINATED;
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_hash_insert_value   (GHashTable  *hash,
					     const char  *key,
					     GValue      *value);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_hash_insert         (GHashTable  *hash,
					     const char  *key,
					     GType        type,
					     ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_hash_insert_vals    (GHashTable  *hash,
					     const char  *first_key,
					     ...) G_GNUC_NULL_TERMINATED;
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
gboolean     soup_value_hash_lookup         (GHashTable  *hash,
					     const char  *key,
					     GType        type,
					     ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
gboolean     soup_value_hash_lookup_vals    (GHashTable  *hash,
					     const char  *first_key,
					     ...) G_GNUC_NULL_TERMINATED;

SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GValueArray *soup_value_array_from_args     (va_list      args);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
gboolean     soup_value_array_to_args       (GValueArray *array,
					     va_list      args);

SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GValueArray *soup_value_array_new           (void);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GValueArray *soup_value_array_new_with_vals (GType        first_type,
					     ...) G_GNUC_NULL_TERMINATED;

SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_array_insert        (GValueArray *array,
					     guint        index_,
					     GType        type,
					     ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_array_append        (GValueArray *array,
					     GType        type,
					     ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
void         soup_value_array_append_vals   (GValueArray *array,
					     GType        first_type,
					     ...) G_GNUC_NULL_TERMINATED;
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
gboolean     soup_value_array_get_nth       (GValueArray *array,
					     guint        index_,
					     GType        type,
					     ...);


SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52
GType        soup_byte_array_get_type       (void);
#define SOUP_TYPE_BYTE_ARRAY (soup_byte_array_get_type ())

G_END_DECLS

#endif /* SOUP_VALUE_UTILS_H */
