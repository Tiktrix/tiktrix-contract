#!/usr/bin/env node

const path = process.argv[2];
if (!path) {
  console.error('Please provide a path');
  process.exit(1);
}

process.env.SOURCE_PATH = path;
require('child_process').spawn('npx', ['thirdweb', 'publish', '-k', process.env.THIRDWEB_API_KEY], { 
  stdio: 'inherit',
  shell: true
}); 