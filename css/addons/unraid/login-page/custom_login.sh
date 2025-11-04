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

# Add stylesheets if not present - insert after first existing <link> tag we find
if ! grep -q "data-tp='theme'" ${LOGIN_PAGE}; then
  echo "Adding stylesheet"
  TMP_CSS=$(mktemp)
  printf "    <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css?v=${VERSION}'>\n    <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>\n" > "${TMP_CSS}"
  TMP_PAGE_CSS=$(mktemp)
  # Insert after first <link> tag found
  if grep -q "<link" ${LOGIN_PAGE}; then
    awk 'FNR==NR{a[++n]=$0; next} /<link[^>]*>/{if(!inserted) {print; for(i=1;i<=n;i++) print a[i]; inserted=1; next}} {print}' "${TMP_CSS}" "${LOGIN_PAGE}" > "${TMP_PAGE_CSS}" 2>/dev/null
  else
    # No <link> found, skip insertion (will be handled by sed update below)
    cp "${LOGIN_PAGE}" "${TMP_PAGE_CSS}"
  fi
  if [ -s "${TMP_PAGE_CSS}" ]; then
    cp -p "${TMP_PAGE_CSS}" "${LOGIN_PAGE}"
    echo 'Stylesheet set to' ${THEME}
  else
    echo "WARNING: Failed to insert stylesheets"
  fi
  rm -f "${TMP_CSS}" "${TMP_PAGE_CSS}"
fi

# Ensure stylesheet hrefs point to the correct source (with cache-busting)
sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>" ${LOGIN_PAGE}
sed -i "/<link data-tp='base' rel='stylesheet' href='/c <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css?v=${VERSION}'>" ${LOGIN_PAGE}

# Use external URL for logo (large files work better as URLs than data URIs)
echo "Using logo URL: ${LOGO_SOURCE}"
LOGO_DATA_URI="${LOGO_SOURCE}?v=${VERSION}"

# Remove any existing logo override block
sed -i "/<style data-tp='logo-override'>/,/<\\/style>/d" ${LOGIN_PAGE}
# Also remove old logo override without data-tp marker
sed -i "/<style.*logo-override/,/<\\/style>/d" ${LOGIN_PAGE}

# Insert style right after the theme link tag (using same awk approach as JS insertion)
# This ensures it comes after theme CSS in cascade order
if grep -q "data-tp='theme'" ${LOGIN_PAGE}; then
  TMP_STYLE=$(mktemp)
  printf "    <style data-tp='logo-override'>:root { --logo: url('%s') center no-repeat !important; }</style>\n" "${LOGO_DATA_URI}" > "${TMP_STYLE}"
  TMP_PAGE=$(mktemp)
  # Match the theme link tag - look for line containing both data-tp='theme' and stylesheet
  awk -v style_file="${TMP_STYLE}" '
  BEGIN {
    while((getline line < style_file) > 0) style_block=style_block line "\n"
    close(style_file)
    inserted=0
  }
  /data-tp=.theme./ && /stylesheet/ && !inserted {
    print
    printf "%s", style_block
    inserted=1
    next
  }
  {print}
  END {
    if (!inserted) {
      print "ERROR: Failed to insert logo override" > "/dev/stderr"
      exit 1
    }
  }
  ' "${LOGIN_PAGE}" > "${TMP_PAGE}" 2>&1
  AWK_EXIT=$?
  if [ ${AWK_EXIT} -eq 0 ] && [ -s "${TMP_PAGE}" ]; then
    cp -p "${TMP_PAGE}" "${LOGIN_PAGE}"
    if grep -q "data-tp='logo-override'" ${LOGIN_PAGE}; then
      echo "Logo override inserted after theme stylesheet"
    else
      echo "WARNING: Logo override not found after insertion"
    fi
  else
    echo "WARNING: Failed to insert logo override (awk exit: ${AWK_EXIT})"
    [ -s "${TMP_PAGE}" ] && head -5 "${TMP_PAGE}"
  fi
  rm -f "${TMP_STYLE}" "${TMP_PAGE}"
else
  echo "WARNING: Theme tag not found, skipping logo override (would break PHP to append)"
fi

# Adding/Removing javascript (use external URL via jsDelivr, not data URI to avoid size issues)
if [ ${ADD_JS} = "true" ]; then
  JS_SOURCE_URL="${BASE_URL}/css/addons/unraid/login-page/${TYPE}/js/${JS}?v=${VERSION}"
  echo "Using JS URL: ${JS_SOURCE_URL}"
  # Remove any existing themepark-js tag
  sed -i "/<script .*data-tp='themepark-js'.*src='/d" ${LOGIN_PAGE}
  # Insert script after logo override, or after theme link, or after existing script tag
  TMP_JS=$(mktemp)
  printf "    <script data-tp='themepark-js' type='text/javascript' src='%s'></script>\n" "${JS_SOURCE_URL}" > "${TMP_JS}"
  TMP_PAGE2=$(mktemp)
  # Try to insert after logo override first, then theme link, then existing script
  if grep -q "data-tp='logo-override'" ${LOGIN_PAGE}; then
    # Insert after logo override style tag
    awk -v js_file="${TMP_JS}" '
    BEGIN {
      while((getline line < js_file) > 0) js_block=js_block line "\n"
      close(js_file)
      inserted=0
    }
    /data-tp=.logo-override./ && !inserted {
      print
      printf "%s", js_block
      inserted=1
      next
    }
    {print}
    END {
      if (!inserted) {
        print "ERROR: Failed to insert JS after logo override" > "/dev/stderr"
        exit 1
      }
    }
    ' "${LOGIN_PAGE}" > "${TMP_PAGE2}" 2>&1
  elif grep -q "data-tp='theme'" ${LOGIN_PAGE}; then
    # Insert after theme link tag
    awk -v js_file="${TMP_JS}" '
    BEGIN {
      while((getline line < js_file) > 0) js_block=js_block line "\n"
      close(js_file)
      inserted=0
    }
    /data-tp=.theme./ && /stylesheet/ && !inserted {
      print
      printf "%s", js_block
      inserted=1
      next
    }
    {print}
    END {
      if (!inserted) {
        print "ERROR: Failed to insert JS after theme" > "/dev/stderr"
        exit 1
      }
    }
    ' "${LOGIN_PAGE}" > "${TMP_PAGE2}" 2>&1
  elif grep -q "<script" ${LOGIN_PAGE}; then
    # Insert after first script tag
    awk -v js_file="${TMP_JS}" '
    BEGIN {
      while((getline line < js_file) > 0) js_block=js_block line "\n"
      close(js_file)
      inserted=0
    }
    /<script[^>]*>/ && !inserted {
      print
      printf "%s", js_block
      inserted=1
      next
    }
    {print}
    END {
      if (!inserted) {
        print "ERROR: Failed to insert JS after script tag" > "/dev/stderr"
        exit 1
      }
    }
    ' "${LOGIN_PAGE}" > "${TMP_PAGE2}" 2>&1
  else
    # No script or theme tag found, skip (don't break PHP by appending)
    cp "${LOGIN_PAGE}" "${TMP_PAGE2}"
    echo "WARNING: Could not find insertion point for JS"
  fi
  AWK_EXIT=$?
  if [ ${AWK_EXIT} -eq 0 ] && [ -s "${TMP_PAGE2}" ]; then
    cp -p "${TMP_PAGE2}" "${LOGIN_PAGE}"
    if grep -q "data-tp='themepark-js'" ${LOGIN_PAGE}; then
      echo "JS script inserted"
    else
      echo "WARNING: JS script not found after insertion"
    fi
  else
    echo "WARNING: Failed to insert JS script (awk exit: ${AWK_EXIT})"
    [ -s "${TMP_PAGE2}" ] && head -5 "${TMP_PAGE2}"
  fi
  rm -f "${TMP_JS}" "${TMP_PAGE2}"
else
  if grep -q "data-tp='themepark-js'" ${LOGIN_PAGE}; then
    echo "Removing Javascript.."
    sed -i "/<script .*data-tp='themepark-js'.*src='/d" ${LOGIN_PAGE}
  fi
fi

# Finally, if the selected theme file changed, ensure it is reflected
if ! grep -q ${TYPE}"/"${THEME} ${LOGIN_PAGE}; then
  echo "Ensuring selected stylesheet is active"
  sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}?v=${VERSION}'>" ${LOGIN_PAGE}
  echo 'Stylesheet set to' ${THEME}
fi
