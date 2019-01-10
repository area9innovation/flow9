/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2007 Red Hat, Inc.
 */

#ifndef SOUP_XMLRPC_OLD_H
#define SOUP_XMLRPC_OLD_H 1

#include <libsoup/soup-types.h>

G_BEGIN_DECLS

/* XML-RPC client */
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_build_request)
char        *soup_xmlrpc_build_method_call       (const char   *method_name,
						  GValue       *params,
						  int           n_params);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_message_new)
SoupMessage *soup_xmlrpc_request_new             (const char   *uri,
						  const char   *method_name,
						  ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_parse_response)
gboolean     soup_xmlrpc_parse_method_response   (const char   *method_response,
						  int           length,
						  GValue       *value,
						  GError      **error);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_parse_response)
gboolean     soup_xmlrpc_extract_method_response (const char   *method_response,
						  int           length,
						  GError      **error,
						  GType         type,
						  ...);

/* XML-RPC server */
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_parse_request)
gboolean     soup_xmlrpc_parse_method_call       (const char   *method_call,
						  int           length,
						  char        **method_name,
						  GValueArray **params);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_parse_request)
gboolean     soup_xmlrpc_extract_method_call     (const char   *method_call,
						  int           length,
						  char        **method_name,
						  ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_build_response)
char        *soup_xmlrpc_build_method_response   (GValue       *value);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_message_set_response)
void         soup_xmlrpc_set_response            (SoupMessage  *msg,
						  GType         type,
						  ...);
SOUP_AVAILABLE_IN_2_4
SOUP_DEPRECATED_IN_2_52_FOR(soup_xmlrpc_message_set_fault)
void         soup_xmlrpc_set_fault               (SoupMessage  *msg,
						  int           fault_code,
						  const char   *fault_format,
						  ...) G_GNUC_PRINTF (3, 4);

G_END_DECLS

#endif /* SOUP_XMLRPC_OLD_H */
