/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright 2015 - Collabora Ltd.
 */

#ifndef SOUP_XMLRPC_H
#define SOUP_XMLRPC_H 1

#include <libsoup/soup-types.h>
#include <libsoup/soup-xmlrpc-old.h>

G_BEGIN_DECLS

/* XML-RPC client */
SOUP_AVAILABLE_IN_2_52
char       *soup_xmlrpc_build_request   (const char *method_name,
					 GVariant   *params,
					 GError    **error);
SOUP_AVAILABLE_IN_2_52
SoupMessage *soup_xmlrpc_message_new    (const char *uri,
					 const char *method_name,
					 GVariant   *params,
					 GError    **error);
SOUP_AVAILABLE_IN_2_52
GVariant    *soup_xmlrpc_parse_response (const char *method_response,
					 int         length,
					 const char *signature,
					 GError    **error);

/* XML-RPC server */
typedef struct _SoupXMLRPCParams SoupXMLRPCParams;
SOUP_AVAILABLE_IN_2_52
void         soup_xmlrpc_params_free          (SoupXMLRPCParams  *self);
SOUP_AVAILABLE_IN_2_52
GVariant    *soup_xmlrpc_params_parse         (SoupXMLRPCParams  *self,
					       const char        *signature,
					       GError           **error);
SOUP_AVAILABLE_IN_2_52
char       *soup_xmlrpc_parse_request         (const char        *method_call,
					       int                length,
					       SoupXMLRPCParams **params,
					       GError           **error);
SOUP_AVAILABLE_IN_2_52
char       *soup_xmlrpc_build_response        (GVariant          *value,
					       GError           **error);
SOUP_AVAILABLE_IN_2_4
char       *soup_xmlrpc_build_fault           (int                fault_code,
					       const char        *fault_format,
					       ...) G_GNUC_PRINTF (2, 3);
SOUP_AVAILABLE_IN_2_52
gboolean     soup_xmlrpc_message_set_response (SoupMessage       *msg,
					       GVariant          *value,
					       GError           **error);
SOUP_AVAILABLE_IN_2_52
void         soup_xmlrpc_message_set_fault    (SoupMessage       *msg,
					       int                fault_code,
					       const char        *fault_format,
					       ...) G_GNUC_PRINTF (3, 4);

/* Utils */
SOUP_AVAILABLE_IN_2_52
GVariant *soup_xmlrpc_variant_new_datetime (SoupDate *date);

SOUP_AVAILABLE_IN_2_52
SoupDate *soup_xmlrpc_variant_get_datetime (GVariant *variant,
					    GError  **error);

/* Errors */
#define SOUP_XMLRPC_ERROR soup_xmlrpc_error_quark()
SOUP_AVAILABLE_IN_2_4
GQuark soup_xmlrpc_error_quark (void);

typedef enum {
	SOUP_XMLRPC_ERROR_ARGUMENTS,
	SOUP_XMLRPC_ERROR_RETVAL
} SoupXMLRPCError;

#define SOUP_XMLRPC_FAULT soup_xmlrpc_fault_quark()
SOUP_AVAILABLE_IN_2_4
GQuark soup_xmlrpc_fault_quark (void);

typedef enum {
	SOUP_XMLRPC_FAULT_PARSE_ERROR_NOT_WELL_FORMED = -32700,
	SOUP_XMLRPC_FAULT_PARSE_ERROR_UNSUPPORTED_ENCODING = -32701,
	SOUP_XMLRPC_FAULT_PARSE_ERROR_INVALID_CHARACTER_FOR_ENCODING = -32702,
	SOUP_XMLRPC_FAULT_SERVER_ERROR_INVALID_XML_RPC = -32600,
	SOUP_XMLRPC_FAULT_SERVER_ERROR_REQUESTED_METHOD_NOT_FOUND = -32601,
	SOUP_XMLRPC_FAULT_SERVER_ERROR_INVALID_METHOD_PARAMETERS = -32602,
	SOUP_XMLRPC_FAULT_SERVER_ERROR_INTERNAL_XML_RPC_ERROR = -32603,
	SOUP_XMLRPC_FAULT_APPLICATION_ERROR = -32500,
	SOUP_XMLRPC_FAULT_SYSTEM_ERROR = -32400,
	SOUP_XMLRPC_FAULT_TRANSPORT_ERROR = -32300
} SoupXMLRPCFault;

G_END_DECLS

#endif /* SOUP_XMLRPC_H */
