import { readFileSync } from 'fs';

const en = JSON.parse(readFileSync('./messages/en.json', 'utf8'));
const ru = JSON.parse(readFileSync('./messages/ru.json', 'utf8'));

function findUntranslated(enObj, ruObj, path) {
  path = path || "";
  const results = [];
  for (const key in enObj) {
    const enVal = enObj[key];
    const ruVal = ruObj ? ruObj[key] : undefined;
    const fullPath = path ? path + "." + key : key;

    if (typeof enVal === "object" && enVal !== null && !Array.isArray(enVal)) {
      results.push(...findUntranslated(enVal, ruVal, fullPath));
    } else if (typeof enVal === "string" && enVal === ruVal && enVal.length > 5
      && !/^[0-9.×%]+$/.test(enVal) && !enVal.includes("φ")
      && !enVal.startsWith("http") && !enVal.endsWith(".md")
      && !enVal.includes("FPGA") && !enVal.includes("ASIC")
      && !enVal.includes("arXiv") && !enVal.includes("GitHub")) {
      results.push({ path: fullPath, value: enVal.substring(0, 100) });
    }
  }
  return results;
}

const untranslated = findUntranslated(en, ru);
console.log("НЕПЕРЕВЕДЁННЫЕ СТРОКИ (en === ru): " + untranslated.length);
untranslated.forEach(u => console.log("  " + u.path + ": " + JSON.stringify(u.value)));
