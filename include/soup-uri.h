#include <libsoup/soup.h>

#ifndef PATH_SEPARATOR
#  define PATH_SEPARATOR "/"
#endif

#ifndef WWW_PREFIX
#  define WWW_PREFIX        "www."
#  define WWW_PREFIX_LENGTH 4
#endif

#define SOUP_URI_ERROR (-1)

#define SOUP_URI_MATCH_MIRROR    (1)
#define SOUP_URI_MATCH_SUBDOMAIN (2) /* implies SOUP_URI_MATCH_MIRROR */

gint
soup_uri_match (SoupURI*, SoupURI*, guint);

gint
soup_uri_is_external (SoupURI*, SoupURI*, guint);

gchar*
soup_uri_hostname_lowercase (SoupURI*);

gint
soup_uri_validate_for_scheme (const char*, const char*);

/* __END__ */

