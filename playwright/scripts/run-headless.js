// Headless browser automation with persistent profile
const { chromium } = require('playwright');

async function main() {
  const profileDir = process.env.HOME + '/.playwright-profiles/jeff';
  
  const browser = await chromium.launchPersistentContext(profileDir, { 
    headless: true,
    args: ['--no-sandbox']
  });

  const page = await browser.newPage();
  
  const url = process.argv[2] || 'https://google.com';
  await page.goto(url);
  
  console.log('URL:', url);
  console.log('Title:', await page.title());
  
  // Add your automation logic here
  
  await browser.close();
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
