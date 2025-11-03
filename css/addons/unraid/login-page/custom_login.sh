#!/bin/bash
TYPE="retro-terminal"
THEME="green.css"

# Source assets directly from GitHub via jsDelivr (serves proper CSS/JS content types)
BASE_URL="https://cdn.jsdelivr.net/gh/JoeStratton/theme.park@master"

ADD_JS="true"
JS="custom_text_header.js"
DISABLE_THEME="false"

## FAQ

  # If you update the source after the script has been run,
  # you must disable the whole theme with the DISABLE_THEME="true" env first and re-run it again after with "false".

  # If you are on an Unraid version older than 6.10 you need to update the LOGIN_PAGE variable to "/usr/local/emhttp/login.php"

echo -e "Variables set:\n\
TYPE          = ${TYPE}\n\
THEME         = ${THEME}\n\
BASE_URL      = ${BASE_URL}\n\
ADD_JS        = ${ADD_JS}\n\
JS            = ${JS}\n\
DISABLE_THEME = ${DISABLE_THEME}\n"

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

# Add stylesheets if not present (anchor before </head>)
if ! grep -q "data-tp='theme'" ${LOGIN_PAGE}; then
  echo "Adding stylesheet"
  sed -i -e "\@</head>@i\    <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css'>" ${LOGIN_PAGE}
  sed -i -e "\@</head>@i\    <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}'>" ${LOGIN_PAGE}
  echo 'Stylesheet set to' ${THEME}
fi

# Ensure stylesheet hrefs point to the correct source
sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}'>" ${LOGIN_PAGE}
sed -i "/<link data-tp='base' rel='stylesheet' href='/c <link data-tp='base' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${TYPE}-base.css'>" ${LOGIN_PAGE}

# Adding/Removing javascript (use a stable data attribute marker)
if [ ${ADD_JS} = "true" ]; then
  if grep -q "data-tp='themepark-js'" ${LOGIN_PAGE}; then
    echo "Updating Javascript"
    sed -i "/<script .*data-tp='themepark-js'.*src='/c <script data-tp='themepark-js' type='text/javascript' src='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/js/${JS}'></script>" ${LOGIN_PAGE}
  else
    echo "Adding Javascript"
    sed -i -e "\@</body>@i\    <script data-tp='themepark-js' type='text/javascript' src='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/js/${JS}'></script>" ${LOGIN_PAGE}
  fi
else
  if grep -q "data-tp='themepark-js'" ${LOGIN_PAGE}; then
    echo "Removing Javascript.."
    sed -i "/<script .*data-tp='themepark-js'.*src='/d" ${LOGIN_PAGE}
  fi
fi

# Finally, if the selected theme file changed, ensure it is reflected
if ! grep -q ${TYPE}"/"${THEME} ${LOGIN_PAGE}; then
  echo "Ensuring selected stylesheet is active"
  sed -i "/<link data-tp='theme' rel='stylesheet' href='/c <link data-tp='theme' rel='stylesheet' href='${BASE_URL}/css/addons/unraid/login-page/${TYPE}/${THEME}'>" ${LOGIN_PAGE}
  echo 'Stylesheet set to' ${THEME}
fi
