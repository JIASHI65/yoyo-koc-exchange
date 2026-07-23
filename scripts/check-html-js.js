const fs = require('fs');
const path = require('path');
const acorn = require('acorn');

const files = process.argv.slice(2);
if (!files.length) {
  console.error('Usage: node scripts/check-html-js.js <file1.html> <file2.html> ...');
  process.exit(1);
}

let bad = 0;
for (const file of files) {
  const abs = path.resolve(file);
  const html = fs.readFileSync(abs, 'utf8');
  const re = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  let idx = 0;
  let fileBad = false;
  while ((m = re.exec(html)) !== null) {
    idx += 1;
    const code = m[1];
    if (!code.trim()) continue;
    const tag = m[0].slice(0, m[0].indexOf('>') + 1);
    if (/type\s*=\s*["'](application\/json|text\/template)/i.test(tag)) continue;
    if (/\ssrc\s*=/.test(tag)) continue;
    try {
      acorn.parse(code, { ecmaVersion: 2020 });
    } catch (e) {
      const approxLine = html.slice(0, m.index).split('\n').length;
      console.error(`❌ ${file} script#${idx} (~line ${approxLine}): ${e.message}`);
      fileBad = true;
      bad += 1;
    }
  }
  if (!fileBad) {
    console.log(`✅ ${file}`);
  }
}

process.exit(bad ? 1 : 0);
