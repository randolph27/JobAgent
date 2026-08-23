const { chromium } = require("playwright");
const fs = require("node:fs");
const path = require("node:path");

const url = process.env.JA022_REPORT_URL;
const outputRoot = process.env.JA022_OUTPUT_ROOT;
const widths = [1920, 1366, 800];
const browserCandidates = [
  process.env.PLAYWRIGHT_BROWSER_PATH,
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
].filter(Boolean);

const executablePath = browserCandidates.find((candidate) => fs.existsSync(candidate));
const issues = [];
const screenshots = [];

if (!executablePath) {
  throw new Error("Kein lokaler Chrome- oder Edge-Browser fuer den Viewport-Audit gefunden.");
}

async function main() {
  const browser = await chromium.launch({ headless: true, executablePath });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1400 } });
    for (const width of widths) {
      await page.setViewportSize({ width, height: 1400 });
      const response = await page.goto(url, { waitUntil: "networkidle" });
      if (!response || response.status() !== 200) {
        throw new Error(`Viewport ${width}: HTTP ${response ? response.status() : "NO_RESPONSE"}`);
      }
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.waitForTimeout(150);

      const audit = await page.evaluate(({ width }) => {
        const documentWidth = document.documentElement.scrollWidth;
        const issues = [];
        if (documentWidth > width + 1) {
          issues.push(`document_overflow:${documentWidth}`);
        }

        const wrappers = Array.from(document.querySelectorAll(".table-wrap"));
        for (const wrapper of wrappers) {
          const style = window.getComputedStyle(wrapper);
          if (style.overflowX !== "auto") {
            issues.push("table_wrap_overflow_contract_missing");
            continue;
          }
          if (wrapper.getBoundingClientRect().right > width + 1) {
            issues.push("table_wrap_outside_viewport");
          }
        }

        const longTextNodes = Array.from(document.querySelectorAll("td, th, p, li, a, h2, h3"))
          .filter((node) => (node.textContent || "").trim().length >= 80);

        for (const node of longTextNodes) {
          const style = window.getComputedStyle(node);
          if ((node.scrollWidth > node.clientWidth + 1) && !["anywhere", "break-word"].includes(style.overflowWrap)) {
            issues.push(`long_text_clip:${node.tagName.toLowerCase()}`);
            break;
          }
        }

        const sections = Array.from(document.querySelectorAll("h2")).map((node) => node.textContent?.trim() || "");
        return {
          width,
          issues,
          sections
        };
      }, { width });

      const screenshotPath = path.join(outputRoot, `ja-022-viewport-${width}.png`);
      await page.screenshot({ path: screenshotPath, fullPage: true });
      screenshots.push(screenshotPath);
      if (audit.issues.length > 0) {
        issues.push(audit);
      }
    }
  } finally {
    await browser.close();
  }

  const result = {
    status: issues.length === 0 ? "ok" : "failed",
    url,
    screenshots,
    issues
  };

  process.stdout.write(JSON.stringify(result, null, 2));
  if (issues.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
