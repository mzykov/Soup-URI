#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "soup-uri.h"
#include <stdio.h>

/* TODO: use 
     gboolean
     g_utf8_validate (const gchar *str,
                      gssize max_len,
                      const gchar **end); */

/* TODO: write a piece of comment */
gint
soup_uri_match (SoupURI *parent, SoupURI *child, gboolean allow_mirror)
{
  GFile *file   = NULL;
  gchar *prefix = NULL;
  
  if (soup_uri_is_external(parent, child, allow_mirror)) {
    return FALSE;
  }
  
  if (g_str_has_suffix(soup_uri_get_path(parent), PATH_SEPARATOR)) {
    prefix = (gchar *)soup_uri_get_path(parent);
    
    if (g_str_has_prefix(soup_uri_get_path(child), (const gchar *)prefix)) {
      return TRUE;
    }
  }
  else {
    file   = g_file_new_for_path(soup_uri_get_path(parent));
    prefix = g_file_get_path(file);
    
    g_object_unref(file);
    
    if (prefix == NULL) {
      return SOUP_URI_ERROR;
    }
    
    gboolean matched = FALSE;
    matched = g_str_has_prefix(soup_uri_get_path(child), (const gchar *)prefix);
    
    g_free(prefix);
    return matched;
  }
  
  return FALSE;
}

gint
soup_uri_is_external (SoupURI *base, SoupURI *href, gboolean allow_mirror)
{
  gchar *base_host = NULL, *base_host_ref = NULL,
        *href_host = NULL, *href_host_ref = NULL;
  
  base_host = soup_uri_hostname_lowercase(base);
  
  if (base_host == NULL) {
    return SOUP_URI_ERROR;
  }
  
  base_host_ref = base_host;
  
  href_host = soup_uri_hostname_lowercase(href);
  
  if (href_host == NULL) {
    g_free(base_host);
    return SOUP_URI_ERROR;
  }
  
  href_host_ref = href_host;
  
  if (allow_mirror) {
    if (g_str_has_prefix((const gchar *)base_host, WWW_PREFIX)) {
      base_host_ref += WWW_PREFIX_LENGTH;
    }
    
    if (g_str_has_prefix((const gchar *)href_host, WWW_PREFIX)) {
      href_host_ref += WWW_PREFIX_LENGTH;
    }
  }
  
  gint collate;
  collate = g_utf8_collate((const gchar *)base_host_ref, (const gchar *)href_host_ref);
  
  g_free(base_host);
  g_free(href_host);
  
  return collate != 0 ? TRUE : FALSE;
}

gchar*
soup_uri_hostname_lowercase (SoupURI *uri)
{
  gchar *host = NULL,
        *utf8 = NULL,
        *utf8lo = NULL;
  
  glong utf8_len = 0;
  
  host = g_strdup(soup_uri_get_host(uri));
  
  if (host == NULL) {
    return NULL;
  }
  
  if (g_hostname_is_ascii_encoded((const gchar *)host)) {
    utf8 = g_hostname_to_unicode((const gchar *)host);
    g_free(host);
    
    if (utf8 == NULL) {
      return NULL;
    }
  } else {
    utf8 = host;
  }
  
  utf8lo = g_utf8_strdown((const gchar *)utf8, (gssize)(-1));
  g_free(utf8);
  
  if (utf8lo == NULL) {
    return NULL;
  }
  
  return utf8lo;
}

gint
soup_uri_validate_for_scheme (const char *uri, const char *scheme)
{
  SoupURI *URI = NULL;
  gint retval = SOUP_URI_ERROR;
  
  if (uri != NULL) {
    URI = soup_uri_new(uri);
    
    if (URI != NULL) {
      if (SOUP_URI_IS_VALID(URI) && URI->host) {
        if (URI->scheme == scheme) {
          retval = TRUE; /* libsoup standard scheme */
        }
        else {
          /* non-standard scheme */
          retval = g_ascii_strcasecmp(URI->scheme, scheme) == 0 ? TRUE : FALSE;
        }
      }
      
      soup_uri_free(URI);
    }
  }
  
  return retval;
}

MODULE = Soup::URI		PACKAGE = Soup::URI

int
is_uri(uri)
		const char *uri
	INIT:
		SoupURI *URI = NULL;
	CODE:
		if (uri != NULL) {
		  URI = soup_uri_new(uri);
		  
		  if (URI != NULL) {
		    RETVAL = SOUP_URI_IS_VALID(URI) ? TRUE : FALSE;
		    soup_uri_free(URI);
		  }
		  else {
		    RETVAL = FALSE;
		  }
		}
		else {
		  RETVAL = FALSE;
		}
	OUTPUT:
		RETVAL

int
is_web_uri(uri)
		const char *uri
	INIT:
		SoupURI *URI = NULL;
	CODE:
		if (uri != NULL) {
		  URI = soup_uri_new(uri);
		  
		  if (URI != NULL) {
		    RETVAL = SOUP_URI_VALID_FOR_HTTP(URI) ? TRUE: FALSE;
		    soup_uri_free(URI);
		  }
		  else {
		    RETVAL = FALSE;
		  }
		}
		else {
		  RETVAL = FALSE;
		}
	OUTPUT:
		RETVAL

int
is_http_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_HTTP) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_https_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_HTTPS) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_ftp_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_FTP) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_data_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_DATA) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_resource_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_RESOURCE) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_file_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, SOUP_URI_SCHEME_FILE) > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_ftps_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, "ftps") > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
is_tel_uri(uri)
		const char *uri
	CODE:
		RETVAL = soup_uri_validate_for_scheme(uri, "tel") > 0 ? TRUE: FALSE;
	OUTPUT:
		RETVAL

int
uri_match(uri1, uri2, allow_mirror = FALSE)
		const char *uri1
		const char *uri2
		bool        allow_mirror
	INIT:
		SoupURI *child = NULL,
		        *parent = NULL;
	CODE:
		if (uri1 == NULL || uri2 == NULL) {
		  RETVAL = SOUP_URI_ERROR;
		}
		else {
		  parent = soup_uri_new(uri1);
		  child  = soup_uri_new(uri2);
		  
		  if (SOUP_URI_IS_VALID(parent) &&
		      SOUP_URI_IS_VALID(child)) {
		    RETVAL = soup_uri_match(parent, child, allow_mirror);
		  }
		  else {
		    RETVAL = SOUP_URI_ERROR;
		  }
		  
		  if (child != NULL)
		    soup_uri_free(child);
		  
		  if (parent != NULL)
		    soup_uri_free(parent);
		}
	OUTPUT:
		RETVAL
