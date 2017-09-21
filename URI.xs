#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "soup-uri.h"
#include <stdio.h>
#include <string.h>

/* TODO: use 
     gboolean
     g_utf8_validate (const gchar *str,
                      gssize max_len,
                      const gchar **end); */

/* TODO: write a piece of comment */
gint
soup_uri_match (SoupURI *parent, SoupURI *child, guint match_flags)
{
  GFile *file   = NULL;
  gchar *prefix = NULL;
  
  gboolean parent_is_ip = FALSE,
           child_is_ip  = FALSE;
  
  /* Returns immidiatly if scheme or port are differ */
  if (soup_uri_get_scheme(parent) != soup_uri_get_scheme(child) || 
      soup_uri_get_port(parent)   != soup_uri_get_port(child)) {
    return FALSE;
  }
  
  parent_is_ip = g_hostname_is_ip_address(soup_uri_get_host(parent));
  child_is_ip  = g_hostname_is_ip_address(soup_uri_get_host(child));
  
  /* Two normal hosts, the most common case */
  if (!parent_is_ip && !child_is_ip) {
    if (soup_uri_is_external(parent, child, match_flags)) {
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
  }
  /* Two ip addresses, rare case */
  else if (parent_is_ip && child_is_ip) {
    return soup_uri_host_equal((gconstpointer)parent,(gconstpointer)child);
  }
  
  /* We do not know how to 
     compare host against ip address */
  
  return FALSE;
}

gint
soup_uri_is_external (SoupURI *base, SoupURI *href, guint match_flags)
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
  
  switch (match_flags) {
    case SOUP_URI_MATCH_MIRROR:
      if (g_str_has_prefix((const gchar *)base_host, WWW_PREFIX)) {
        base_host_ref += WWW_PREFIX_LENGTH;
      }
      
      if (g_str_has_prefix((const gchar *)href_host, WWW_PREFIX)) {
        href_host_ref += WWW_PREFIX_LENGTH;
      }
      break;
    
    case SOUP_URI_MATCH_SUBDOMAIN:
      /* TODO: check GError */
      base_host_ref = (gchar *)soup_tld_get_base_domain(base_host, NULL);
      
      if (base_host_ref == NULL) {
        /* maybe private domain? */
        base_host_ref = base_host;
      }
      
      /* TODO: check GError */
      href_host_ref = (gchar *)soup_tld_get_base_domain(href_host, NULL);
      
      if (href_host_ref == NULL) {
        /* maybe private domain? */
        href_host_ref = href_host;
      }
      break;
    
    default:
      break;
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

/* Code of functions 
   form_decode and soup_uri_form_decode
   is derived from libsoup-2.4
 */
gboolean
form_decode (char *part)
{
  unsigned char *s, *d;
  s = d = (unsigned char *)part;
  
  do {
    if (*s == '%') {
      if (!g_ascii_isxdigit(s[1]) ||
          !g_ascii_isxdigit(s[2])) {
        return FALSE;
      }
      
      *d++ = HEXCHAR(s);
      s += 2;
    }
    else if (*s == '+') {
      *d++ = ' ';
    }
    else {
      *d++ = *s;
    }
  } while (*s++);
  
  return TRUE;
}

/* There is a replacement GHashTable -> HV */
HV*
soup_uri_form_decode (const char *encoded_form)
{
  HV *form_data_set = NULL;
  SV **ok = NULL;
  
  char **pairs, *eq, *name, *value;
  int i;
  
  form_data_set = (HV *)sv_2mortal((SV *)newHV());
  
  if (form_data_set == NULL) {
    warn("soup_uri_form_decode: failed to create new HV\n");
    return NULL;
  }
  
  pairs = g_strsplit(encoded_form, "&", -1);
  
  for (i = 0; pairs[i]; i++) {
    name = pairs[i];
    eq = strchr(name, '=');
    
    if (eq) {
      *eq = '\0';
      value = eq + 1;
    }
    else {
      value = NULL;
    }
    
    if (!value || !form_decode(name) || !form_decode(value)) {
      g_free(name);
      continue;
    }
    
    SV *sval;
    sval = sv_2mortal(newSVpv((const char *)value,0));
    
    ok = hv_store(form_data_set, name, strlen(name), sval, 0);
    
    if (ok != NULL && *ok == NULL) {
      warn("soup_uri_form_decode: cannot store key\n");
      continue;
    }
  }
  
  g_free(pairs);
  
  return form_data_set;
}

MODULE = Soup::URI		PACKAGE = Soup::URI

SV*
is_uri(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
	CODE:
		if (url != NULL) {
		  uri = soup_uri_new(url);
		  
		  if (uri != NULL) {
		    RETVAL = SOUP_URI_IS_VALID(uri) ? &PL_sv_yes : &PL_sv_no;
		    soup_uri_free(uri);
		  }
		  else {
		    RETVAL = &PL_sv_undef;
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
is_web_uri(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
	CODE:
		if (url != NULL) {
		  uri = soup_uri_new(url);
		  
		  if (uri != NULL) {
		    RETVAL = SOUP_URI_VALID_FOR_HTTP(uri) ? &PL_sv_yes : &PL_sv_no;
		    soup_uri_free(uri);
		  }
		  else {
		    RETVAL = &PL_sv_undef;
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
is_http_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_HTTP) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_https_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_HTTPS) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_ftp_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_FTP) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_data_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_DATA) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_resource_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_RESOURCE) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_file_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, SOUP_URI_SCHEME_FILE) > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_ftps_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, "ftps") > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
is_tel_uri(url)
		const char *url
	CODE:
		RETVAL = soup_uri_validate_for_scheme(url, "tel") > 0 ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

SV*
uri_match(url1, url2, match_flags = 0)
		const char   *url1
		const char   *url2
		unsigned int  match_flags
	INIT:
		gint matched;
		SoupURI *child = NULL,
		        *parent = NULL;
	CODE:
		if (url1 == NULL || url2 == NULL) {
		  RETVAL = &PL_sv_undef;
		}
		else {
		  parent = soup_uri_new(url1);
		  child  = soup_uri_new(url2);
		  
		  if (SOUP_URI_IS_VALID(parent) &&
		      SOUP_URI_IS_VALID(child)) {
		    matched = soup_uri_match(parent, child, match_flags);
		    
		    switch (matched) {
		      case 0:
		        RETVAL = &PL_sv_no;
		        break;
		      case 1:
		        RETVAL = &PL_sv_yes;
		        break;
		      default:
		        RETVAL = &PL_sv_undef;
		    }
		  }
		  else {
		    RETVAL = &PL_sv_undef;
		  }
		  
		  if (child != NULL)
		    soup_uri_free(child);
		  
		  if (parent != NULL)
		    soup_uri_free(parent);
		}
	OUTPUT:
		RETVAL

SV*
uri_base_domain(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
		const char *hostname;
		const char *domain;
	CODE:
		uri = soup_uri_new(url);
		
		if (uri != NULL) {
		  hostname = soup_uri_get_host(uri);
		  
		  if (hostname == NULL) {
		    RETVAL = &PL_sv_undef;
		  }
		  else {
                    /* TODO: check GError */
		    domain = soup_tld_get_base_domain(hostname, NULL);
		    
		    if (domain == NULL) {
		      RETVAL = &PL_sv_undef;
		    }
		    else {
		      RETVAL = sv_2mortal(newSVpv(domain, 0));
		    }
		  }
		  
		  soup_uri_free(uri);
		}
		else {
		  warn("get_base_domain: soup_uri_new failed\n");
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_encode(part, escape_extra = NULL)
		const char *part
		const char *escape_extra
	INIT:
		char *encoded = NULL;
	CODE:
		encoded = soup_uri_encode(part, escape_extra);
		
		if (encoded != NULL) {
		  RETVAL = sv_2mortal(newSVpv((const char *)encoded,0));
		  g_free(encoded);
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_decode(part)
		const char *part
	INIT:
		char *decoded = NULL;
	CODE:
		decoded = soup_uri_decode(part);
		
		if (decoded != NULL) {
		  RETVAL = sv_2mortal(newSVpv((const char *)decoded,0));
		  g_free(decoded);
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_normalize(part, unescape_extra = NULL)
		const char *part
		const char *unescape_extra
	INIT:
		char *normalized = NULL;
	CODE:
		normalized = soup_uri_normalize(part, unescape_extra);
		
		if (normalized != NULL) {
		  RETVAL = sv_2mortal(newSVpv((const char *)normalized,0));
		  g_free(normalized);
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
get_base_domain(hostname)
		const char *hostname
	INIT:
		const char *domain;
	CODE:
		if (hostname != NULL) {
		  /* TODO: check GError */
		  domain = soup_tld_get_base_domain(hostname, NULL);
		  RETVAL = sv_2mortal(newSVpv(domain,0));
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
has_public_suffix(domain)
		const char *domain
	INIT:
		
	CODE:
		if (domain != NULL) {
		  RETVAL = soup_tld_domain_is_public_suffix(domain) ? &PL_sv_yes : &PL_sv_no;
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_hash(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
		const char *host;
		guint result = 0;
	CODE:
		if (url != NULL) {
		  uri = soup_uri_new(url);
		  
		  if (uri != NULL) {
		    if (SOUP_URI_IS_VALID(uri)) {
		      host = soup_uri_get_host(uri);
		      
		      if (host != NULL) {
		        result = soup_uri_host_hash((gconstpointer)uri);
		        RETVAL = sv_2mortal(newSVuv((UV)result));
		      }
		      else {
		        warn("uri_hash: failed to parse hostname\n");
		        RETVAL = &PL_sv_undef;
		      }
		    }
		    else {
		      warn("uri_hash: URL is not valid\n");
		      RETVAL = &PL_sv_undef;
		    }
		    
		    soup_uri_free(uri);
		  }
		  else {
		   warn("uri_hash: failed to parse URL\n");
		   RETVAL = &PL_sv_undef;
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_is_root(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
	CODE:
		if (url != NULL) {
		  uri = soup_uri_new(url);
		  
		  if (uri != NULL) {
		    if (SOUP_URI_IS_VALID(uri)) {
		      RETVAL = g_ascii_strcasecmp(soup_uri_get_path(uri), PATH_SEPARATOR) == 0 ? 
		                  &PL_sv_yes : 
		                  &PL_sv_no;
		    }
		    else {
		      RETVAL = &PL_sv_undef;
		    }
		    
		    soup_uri_free(uri);
		  }
		  else {
		    RETVAL = &PL_sv_undef;
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_uses_default_port(url)
		const char *url
	INIT:
		SoupURI *uri = NULL;
	CODE:
		if (url != NULL) {
		  uri = soup_uri_new(url);
		  
		  if (uri != NULL) {
		    RETVAL = soup_uri_uses_default_port(uri) ? &PL_sv_yes : &PL_sv_no;
		    soup_uri_free(uri);
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL

SV*
uri_with_base(url, base)
		const char *url
		const char *base
	INIT:
		char *result = NULL;
		
		SoupURI *uri = NULL,
		        *parent = NULL;
	CODE:
		if (uri != NULL && base != NULL) {
		  parent = soup_uri_new(base);
		  
		  if (parent != NULL) {
		    uri = soup_uri_new_with_base(parent, url);
		    
		    if (uri != NULL) {
		      result = soup_uri_to_string(uri, FALSE);
		      
		      if (result != NULL) {
		        RETVAL = sv_2mortal(newSVpv(result, 0));
		        g_free(result);
		      }
		      
		      soup_uri_free(uri);
		    }
		    else {
		      warn("uri_with_base: failed to parse child URL\n");
		      RETVAL = &PL_sv_undef;
		    }
		    
		    soup_uri_free(parent);
		  }
		  else {
		    warn("uri_with_base: failed to parse base URL\n");
		    RETVAL = &PL_sv_undef;
		  }
		}
		else {
		  RETVAL = &PL_sv_undef;
		}
	OUTPUT:
		RETVAL
