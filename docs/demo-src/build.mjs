// Regenerates docs/demo.gif and docs/demo.mp4 from docs/demo-src/demo.html.
//
//   node docs/demo-src/build.mjs
//
// Needs Node 18+, Google Chrome and ffmpeg. puppeteer-core is installed into
// the system temp dir on first run, nothing is added to the repo.
// Env: CHROME (path to Chrome), FFMPEG (path to ffmpeg), FPS (default 12),
// COLORS (GIF palette size, default 128), KEEP_FRAMES=1 to keep the PNGs.

import { execFileSync } from "node:child_process"
import { existsSync, mkdirSync, rmSync, statSync } from "node:fs"
import { createRequire } from "node:module"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const docs = resolve(here, "..")
const work = join(tmpdir(), "agentcheck-demo")
const frames = join(work, "frames")
const fps = Number(process.env.FPS ?? 12)
const colors = Number(process.env.COLORS ?? 128)
const ffmpeg = process.env.FFMPEG ?? "ffmpeg"
const chrome =
  process.env.CHROME ??
  (process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "google-chrome")
const width = 960
const height = 600

mkdirSync(work, { recursive: true })
if (!existsSync(join(work, "node_modules", "puppeteer-core"))) {
  execFileSync("npm", ["install", "--silent", "--no-audit", "--no-fund", "--prefix", work, "puppeteer-core"], {
    stdio: "inherit",
  })
}
const puppeteer = createRequire(join(work, "package.json"))("puppeteer-core")

rmSync(frames, { recursive: true, force: true })
mkdirSync(frames, { recursive: true })

const browser = await puppeteer.launch({ executablePath: chrome, headless: true, args: ["--hide-scrollbars"] })
const page = await browser.newPage()
await page.setViewport({ width, height, deviceScaleFactor: 1 })
await page.goto(pathToFileURL(join(here, "demo.html")).href)
const duration = await page.evaluate("DURATION")
const total = Math.round(duration * fps)
for (let i = 0; i < total; i++) {
  await page.evaluate((t) => window.seek(t), i / fps)
  await page.screenshot({ path: join(frames, `f${String(i).padStart(4, "0")}.png`) })
}
await browser.close()

const input = ["-y", "-loglevel", "error", "-framerate", String(fps), "-i", join(frames, "f%04d.png")]
const gif = join(docs, "demo.gif")
const mp4 = join(docs, "demo.mp4")
execFileSync(ffmpeg, [
  ...input,
  "-filter_complex",
  `split[a][b];[a]palettegen=max_colors=${colors}:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle`,
  "-loop",
  "0",
  gif,
])
execFileSync(ffmpeg, [
  ...input,
  "-c:v",
  "libx264",
  "-crf",
  "20",
  "-preset",
  "slow",
  "-pix_fmt",
  "yuv420p",
  "-movflags",
  "+faststart",
  mp4,
])

if (!process.env.KEEP_FRAMES) rmSync(frames, { recursive: true, force: true })
const mb = (f) => `${(statSync(f).size / 1048576).toFixed(2)} MB`
console.log(`${total} frames at ${fps} fps, ${(total / fps).toFixed(1)}s`)
console.log(`demo.gif ${mb(gif)}, demo.mp4 ${mb(mp4)}`)
