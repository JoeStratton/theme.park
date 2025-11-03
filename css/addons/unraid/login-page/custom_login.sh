#!/bin/bash
TYPE="retro-terminal"
THEME="blue.css"

# Source assets directly from GitHub via jsDelivr (serves proper CSS/JS content types)
BASE_URL="https://cdn.jsdelivr.net/gh/JoeStratton/theme.park@master"

# Raw GitHub for inlining content (bypasses CDN cache)
GITHUB_USER="JoeStratton"
GITHUB_REPO="theme.park"
GITHUB_BRANCH="master"
RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

ADD_JS="true"
JS="custom_text_header.js"
DISABLE_THEME="false"

# Cache-busting version (override by exporting VERSION before running)
VERSION="${VERSION:-$(date +%s)}"

# Custom logo source (override by exporting LOGO_SOURCE before running)
LOGO_SOURCE="${LOGO_SOURCE:-${RAW_BASE_URL}/images/unjoe_logo.png}"

## FAQ

  # If you update the source after the script has been run,
  # you must disable the whole theme with the DISABLE_THEME="true" env first and re-run it again after with "false".

  # If you are on an Unraid version older than 6.10 you need to update the LOGIN_PAGE variable to "/usr/local/emhttp/login.php"

echo -e "Variables set:\n\
TYPE          = ${TYPE}\n\
THEME         = ${THEME}\n\
BASE_URL      = ${BASE_URL}\n\
RAW_BASE_URL  = ${RAW_BASE_URL}\n\
ADD_JS        = ${ADD_JS}\n\
JS            = ${JS}\n\
DISABLE_THEME = ${DISABLE_THEME}\n\
VERSION       = ${VERSION}\n\
LOGO_SOURCE   = ${LOGO_SOURCE}\n"

echo "NOTE: Change the LOGIN_PAGE variable to /usr/local/emhttp/login.php if you are on a version older than 6.10"
LOGIN_PAGE="/usr/local/emhttp/webGui/include/.login.php"

IFS='"'
set $(cat /etc/unraid-version)
UNRAID_VERSION="$2"
IFS=$' \t\n'
echo "Unraid version: ${UNRAID_VERSION}"

# Restore login.php
if [ ${DISABLE_THEME} = "true" ]; then
  echo "Restoring backup of login.php"
  cp -p ${LOGIN_PAGE}.backup ${LOGIN_PAGE}
  exit 0
fi

# Backup login page if needed.
if [ ! -f ${LOGIN_PAGE}.backup ]; then
  echo "Creating backup of login.php"
  cp -p ${LOGIN_PAGE} ${LOGIN_PAGE}.backup
fi

# Cleanup any old Theme Park CSS/JS tags (so our links/scripts are last and win)
# Remove any existing link/script refs to /css/addons/unraid/login-page (regardless of domain and without markers)
sed -i "/<link[^>]*css\\/addons\\/unraid\\/login-page[^>]*>/d" ${LOGIN_PAGE}
sed -i "/<script[^>]*css\\/addons\\/unraid\\/login-page[^>]*><\\/script>/d" ${LOGIN_PAGE}

# Add stylesheets if not present (anchor before </head>)
if ! grep -q "data-tp='theme'" ${LOGIN_PAGE}; then
  echo "Adding stylesheet"
  sed -i -e "\\@</head>@i\    <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css?v=${VERSION}'>" ${LOGIN_PAGE}
  sed -i -e "\\@</head>@i\    <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>" ${LOGIN_PAGE}
  echo 'Stylesheet set to' ${THEME}
fi

# Ensure stylesheet hrefs point to the correct source (with cache-busting)
sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>" ${LOGIN_PAGE}
sed -i "/<link data-tp='base' rel='stylesheet' href='/c <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css?v=${VERSION}'>" ${LOGIN_PAGE}

# Build data URI for logo (fetch latest from GitHub raw)
echo "Fetching logo from ${LOGO_SOURCE}..."
LOGO_TMP=$(mktemp)
if curl -fsSL "${LOGO_SOURCE}" -o "${LOGO_TMP}" 2>&1; then
  if [ -s "${LOGO_TMP}" ]; then
    LOGO_DATA_URI="data:image/png;base64,$(base64 -w 0 < "${LOGO_TMP}" 2>/dev/null || base64 < "${LOGO_TMP}" | tr -d '\n')"
    echo "Logo fetched successfully, size: $(stat -c%s "${LOGO_TMP}" 2>/dev/null || echo "unknown") bytes"
  else
    echo "WARNING: Logo file is empty, using external URL instead"
    LOGO_DATA_URI="${LOGO_SOURCE}?v=${VERSION}"
  fi
else
  echo "WARNING: Failed to fetch logo (curl failed), using external URL instead"
  LOGO_DATA_URI="${LOGO_SOURCE}?v=${VERSION}"
fi
rm -f "${LOGO_TMP}"

# Remove any existing logo override block
sed -i "/<style data-tp='logo-override'>/,/<\\/style>/d" ${LOGIN_PAGE}
# Also remove old logo override without data-tp marker
sed -i "/<style.*logo-override/,/<\\/style>/d" ${LOGIN_PAGE}

# Insert style AFTER the theme link tag (so it comes later in cascade and overrides)
# Use temp file + awk to avoid sed command line length issues with large data URIs
TMP_STYLE=$(mktemp)
printf "    <style data-tp='logo-override'>:root { --logo: url('%s') center no-repeat !important; }</style>\n" "${LOGO_DATA_URI}" > "${TMP_STYLE}"
TMP_PAGE=$(mktemp)
# Insert after the theme link tag using awk
awk -v style_file="${TMP_STYLE}" 'FNR==NR{if(NR==1) {while((getline line < style_file) > 0) style_block=style_block line "\n"; close(style_file)} a[++n]=$0; next} /data-tp=.theme./{print; printf "%s", style_block; next} {print}' "${LOGIN_PAGE}" "${LOGIN_PAGE}" > "${TMP_PAGE}"
if [ $? -eq 0 ] && [ -s "${TMP_PAGE}" ]; then
  cp -p "${TMP_PAGE}" "${LOGIN_PAGE}"
  echo "Logo override inserted after theme stylesheets"
  # Verify it was inserted
  if grep -q "data-tp='logo-override'" ${LOGIN_PAGE}; then
    echo "Logo override verified in login page"
  else
    echo "ERROR: Logo override not found in login page after insertion"
  fi
else
  echo "WARNING: Failed to insert logo override using awk"
fi
rm -f "${TMP_STYLE}" "${TMP_PAGE}"

# Adding/Removing javascript (inline from GitHub raw using data URI)
if [ ${ADD_JS} = "true" ]; then
  JS_SOURCE_URL="${RAW_BASE_URL}/css/addons/unraid/login-page/${TYPE}/js/${JS}"
  echo "Fetching JS from ${JS_SOURCE_URL}..."
  JS_DATA=$(curl -fsSL "${JS_SOURCE_URL}" 2>/dev/null)
  if [ -z "${JS_DATA}" ]; then
    echo "WARNING: Failed to fetch JS, using external URL instead"
    JS_DATA_URI="${JS_SOURCE_URL}?v=${VERSION}"
  else
    JS_DATA_URI="data:text/javascript;base64,$(echo "${JS_DATA}" | base64 | tr -d '\n')"
    echo "JS fetched successfully"
  fi
  # Remove any existing themepark-js tag
  sed -i "/<script .*data-tp='themepark-js'.*src='/d" ${LOGIN_PAGE}
  # Insert script before </body> (FIXED: correct pattern)
  TMP_JS=$(mktemp)
  printf "    <script data-tp='themepark-js' type='text/javascript' src='%s'></script>\n" "${JS_DATA_URI}" > "${TMP_JS}"
  TMP_PAGE2=$(mktemp)
  awk 'FNR==NR{a[++n]=$0; next} /<\/body>/{for(i=1;i<=n;i++) print a[i]; print; next} {print}' "${TMP_JS}" "${LOGIN_PAGE}" > "${TMP_PAGE2}"
  if [ $? -eq 0 ]; then
    cp -p "${TMP_PAGE2}" "${LOGIN_PAGE}"
    echo "JS script inserted"
  else
    echo "WARNING: Failed to insert JS script"
  fi
  rm -f "${TMP_JS}" "${TMP_PAGE2}"
else
  if grep -q "data-tp='themepark-js'" ${LOGIN_PAGE}; then
    echo "Removing Javascript.."
    sed -i "/<script .*data-tp='themepark-js'.*src='/d" ${LOGIN_PAGE}
  fi
fi

rm -f "${TMP_STYLE}" "${TMP_PAGE}"

# Finally, if the selected theme file changed, ensure it is reflected
if ! grep -q ${TYPE}"/"${THEME} ${LOGIN_PAGE}; then
  echo "Ensuring selected stylesheet is active"
  sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>" ${LOGIN_PAGE}
  echo 'Stylesheet set to' ${THEME}
fi
