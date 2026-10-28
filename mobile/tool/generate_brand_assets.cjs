const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const mobile = path.resolve(__dirname, '..');
const source = path.join(mobile, 'assets/brand/source/naru-symbol.svg');
const catalog = 'ios/Runner/Assets.xcassets';
const android = 'android/app/src/main/res';
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

// 도형을 다시 그리지 않고 피그마 SVG 하나로 모든 플랫폼의 이미지를 만들어요.
async function render(relativePath, size, symbolFraction = 1, opaque = false) {
  const output = path.join(mobile, relativePath);
  const canvasSize = size * 4;
  const symbolSize = Math.round(canvasSize * symbolFraction);
  const symbol = await sharp(source, { density: (72 * symbolSize) / 144 })
    .resize(symbolSize, symbolSize)
    .png()
    .toBuffer();
  const offset = Math.round((canvasSize - symbolSize) / 2);
  const composite = await sharp({
    create: {
      width: canvasSize,
      height: canvasSize,
      channels: 4,
      background: { r: 255, g: 255, b: 255, alpha: opaque ? 1 : 0 },
    },
  }).composite([{ input: symbol, left: offset, top: offset }]).png().toBuffer();
  let image = sharp(composite).resize(size, size);
  if (opaque) image = image.removeAlpha();
  await fs.mkdir(path.dirname(output), { recursive: true });
  await image.png().toFile(output);
}

async function copy(from, to) {
  await fs.mkdir(path.dirname(path.join(mobile, to)), { recursive: true });
  await fs.copyFile(path.join(mobile, from), path.join(mobile, to));
}

async function main() {
  const launchImages = [];
  for (const scale of [1, 2, 3]) {
    const flutterFile = `assets/brand/${scale === 1 ? '' : `${scale}.0x/`}naru-symbol.png`;
    const filename = `LaunchImage${scale === 1 ? '' : `@${scale}x`}.png`;
    await render(flutterFile, 144 * scale);
    await copy(flutterFile, `${catalog}/LaunchImage.imageset/${filename}`);
    launchImages.push({ idiom: 'universal', filename, scale: `${scale}x` });
  }
  await fs.writeFile(path.join(mobile, `${catalog}/LaunchImage.imageset/Contents.json`),
    JSON.stringify({ images: launchImages, info: { version: 1, author: 'xcode' } }, null, 2) + '\n');

  // 128px 아이콘 안에 96px 심벌을 둔 승인 시안의 비율을 유지해요.
  // 모서리 마스크는 운영체제가 적용하므로 PNG는 흰색 정사각형으로 저장해요.
  await render('assets/brand/app-icon-1024.png', 1024, 0.75, true);
  const iosIcons = JSON.parse(await fs.readFile(path.join(mobile,
    `${catalog}/AppIcon.appiconset/Contents.json`), 'utf8'));
  const sizes = new Map(iosIcons.images.map(icon => [
    icon.filename, parseFloat(icon.size) * parseFloat(icon.scale),
  ]));
  for (const [filename, size] of sizes) {
    await render(`${catalog}/AppIcon.appiconset/${filename}`, size, 0.75, true);
  }

  for (const [density, scale] of Object.entries(densities)) {
    await render(`${android}/mipmap-${density}/ic_launcher.png`, 48 * scale, 0.75, true);
    // Adaptive icon의 108dp 캔버스 중 보이는 72dp 안에 심벌 54dp를 배치해요.
    await render(`${android}/mipmap-${density}/ic_launcher_foreground.png`, 108 * scale, 0.5);
    await render(`${android}/drawable-${density}/launch_symbol.png`, 144 * scale);
    // Android 12의 288dp 캔버스에서도 실제 심벌 크기는 Flutter와 같은 144dp예요.
    await render(`${android}/drawable-${density}/launch_symbol_android12.png`, 288 * scale, 0.5);
  }

  for (const size of [192, 512]) {
    await render(`web/icons/Icon-${size}.png`, size, 0.75, true);
    await copy(`web/icons/Icon-${size}.png`, `web/icons/Icon-maskable-${size}.png`);
  }
  await render('web/favicon.png', 32, 0.75, true);
  await copy('assets/brand/source/naru-symbol.svg', 'web/brand/naru-symbol.svg');
  console.log('naru: Flutter, iOS, Android, 웹 브랜드 애셋을 생성했어요.');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
