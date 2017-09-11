#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "soup-uri.h"

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

/* TODO: избавиться здесь от операций с памятью!
         Не добавлять "www.", а сдвигать указатель на 4 символа!
*/
gint
soup_uri_is_external (SoupURI *base, SoupURI *href, gboolean allow_mirror)
{
  gchar *base_host = NULL,
        *href_host = NULL;
  
  base_host = allow_mirror ? 
                 soup_uri_get_www_mirror(base) :
                    soup_uri_hostname_lowercase(base);
  
  if (base_host == NULL) {
    return SOUP_URI_ERROR;
  }
  
  href_host = allow_mirror ? 
                 soup_uri_get_www_mirror(href) :
                    soup_uri_hostname_lowercase(href);
  
  if (href_host == NULL) {
    g_free(base_host);
    return SOUP_URI_ERROR;
  }
  
  gint collate;
  collate = g_utf8_collate((const gchar *)base_host, (const gchar *)href_host);
  
  g_free(base_host);
  g_free(href_host);
  
  return collate != 0 ? TRUE : FALSE;
}

gchar*
soup_uri_get_www_mirror (SoupURI *uri)
{
  gchar *host   = NULL,
        *mirror = NULL;
  
  host = soup_uri_hostname_lowercase(uri);
  
  if (host == NULL) {
    return NULL;
  }
  
  if (g_str_has_prefix((const gchar *)host, WWW_PREFIX)) {
    mirror = host;
  }
  else {
    mirror = g_strconcat(WWW_PREFIX, (const gchar *)host, NULL);
    g_free(host);
  }
  
  return mirror;
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
