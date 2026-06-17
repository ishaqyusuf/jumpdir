import fs from "node:fs";

const output = new URL("../assets/jumpdir-terminal.svg", import.meta.url);
const width = 1672;
const cropHeight = 941;
const canvasHeight = 1672;
const top = (canvasHeight - cropHeight) / 2;
const termX = 186;
const termY = top + 80;
const termW = 1300;
const termH = 760;

function escapeText(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function textRun(x, y, content, fill = "#f4f7f8", weight = 700, size = 34) {
  return `<text x="${x}" y="${y}" fill="${fill}" font-family="Menlo, Monaco, 'SF Mono', monospace" font-size="${size}" font-weight="${weight}" letter-spacing="0">${escapeText(content)}</text>`;
}

const lines = [
  textRun(termX + 52, termY + 156, "$", "#79d65b"),
  textRun(termX + 94, termY + 156, "jumpdir set ~/Documents/code ~/Desktop/projects"),
  textRun(termX + 52, termY + 212, "Saved 2 project roots.", "#79d65b", 500),

  textRun(termX + 52, termY + 304, "$", "#79d65b"),
  textRun(termX + 94, termY + 304, "jumpdir ls"),
  textRun(termX + 52, termY + 358, "my-app", "#f4f7f8", 600),
  textRun(termX + 446, termY + 358, "~/Documents/code/my-app", "#cbd5df", 500),
  textRun(termX + 52, termY + 410, "api-server", "#f4f7f8", 600),
  textRun(termX + 446, termY + 410, "~/Desktop/projects/api-server", "#cbd5df", 500),
  textRun(termX + 52, termY + 462, "site", "#f4f7f8", 600),
  textRun(termX + 446, termY + 462, "~/Documents/code/site", "#cbd5df", 500),

  textRun(termX + 52, termY + 572, "$", "#79d65b"),
  textRun(termX + 94, termY + 572, "jumpdir my-app dev"),
  textRun(termX + 52, termY + 628, "Running dev via pnpm in ~/Documents/code/my-app", "#f4f7f8", 500, 30),
  textRun(termX + 52, termY + 680, "> ready on ", "#79d65b", 700, 30),
  textRun(termX + 252, termY + 680, "http://localhost:3000", "#79d65b", 700, 30),
  textRun(termX + 52, termY + 732, "$", "#79d65b"),
  `<rect x="${termX + 96}" y="${termY + 706}" width="17" height="37" rx="2" fill="#f4f7f8" opacity=".95"/>`,
].join("\n");

const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${canvasHeight}" viewBox="0 0 ${width} ${canvasHeight}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="70%">
      <stop offset="0%" stop-color="#253035"/>
      <stop offset="58%" stop-color="#171d20"/>
      <stop offset="100%" stop-color="#0d1012"/>
    </radialGradient>
    <linearGradient id="terminal" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#111719"/>
      <stop offset="55%" stop-color="#060b0d"/>
      <stop offset="100%" stop-color="#020506"/>
    </linearGradient>
    <linearGradient id="titlebar" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#1c2326"/>
      <stop offset="100%" stop-color="#101619"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="36" stdDeviation="34" flood-color="#000000" flood-opacity=".52"/>
    </filter>
  </defs>
  <rect width="${width}" height="${canvasHeight}" fill="url(#bg)"/>
  <rect x="${termX}" y="${termY}" width="${termW}" height="${termH}" rx="24" fill="url(#terminal)" filter="url(#shadow)" stroke="#4e565a" stroke-width="2"/>
  <rect x="${termX}" y="${termY}" width="${termW}" height="82" rx="24" fill="url(#titlebar)"/>
  <path d="M ${termX} ${termY + 82} H ${termX + termW}" stroke="#253036" stroke-width="1"/>
  <circle cx="${termX + 45}" cy="${termY + 42}" r="14" fill="#ff5f57"/>
  <circle cx="${termX + 87}" cy="${termY + 42}" r="14" fill="#ffbd2e"/>
  <circle cx="${termX + 129}" cy="${termY + 42}" r="14" fill="#28c840"/>
  ${lines}
</svg>
`;

fs.writeFileSync(output, svg);
