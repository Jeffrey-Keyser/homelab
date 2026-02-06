# Playwright Browser Automation

Persistent browser profiles for automated web access. Allows Milo to access authenticated sites without storing passwords.

## Quick Start

```bash
./install.sh
```

## How It Works

1. **Persistent Profile**: Browser data (cookies, localStorage, sessions) stored in `~/.playwright-profiles/jeff`
2. **Initial Login**: You log into sites once via noVNC web interface
3. **Automation**: Milo uses headless browser with your saved sessions

## Initial Login (After Install)

```bash
cd ~/playwright-automation
./open-browser.sh
```

Then open `http://beelink:6080/vnc.html` in your browser. Log into the sites you want to grant access to.

## Files

```
~/playwright-automation/
├── open-browser.sh      # Launch browser for login (noVNC)
├── run-headless.js      # Example headless automation
└── node_modules/

~/.playwright-profiles/jeff/   # Session data (chmod 700)
```

## Security

- Profile directory is `chmod 700` (only owner can access)
- No passwords stored — only session cookies
- Sessions backed up encrypted via beelink-backup
- You control which sites are logged in

## Usage from Milo

```javascript
const { chromium } = require('playwright');

const browser = await chromium.launchPersistentContext(
  '/home/jkeyser/.playwright-profiles/jeff',
  { headless: true }
);

const page = await browser.newPage();
await page.goto('https://authenticated-site.com');
// Already logged in!
```

## Disaster Recovery

1. Clone this repo
2. Run `./install.sh`
3. Restore `~/.playwright-profiles/` from backup
