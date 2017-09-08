#include <libsoup/soup.h>

#ifndef PATH_SEPARATOR
#  define PATH_SEPARATOR "/"
#endif

#ifndef WWW_PREFIX
#  define WWW_PREFIX "www."
#endif

#define SOUP_URI_ERROR (-1)

gint
soup_uri_match (SoupURI*, SoupURI*, gboolean);

gint
soup_uri_is_external (SoupURI*, SoupURI*, gboolean);

gint
g_hostname_utf8_cmp (const gchar*, const gchar*);

gchar*
soup_uri_get_www_mirror (SoupURI*);

gchar*
soup_uri_hostname_lowercase (SoupURI*);

