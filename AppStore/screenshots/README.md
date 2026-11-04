# Reciclar — App Store screenshots

Eight unedited screenshots of the running iOS app, Portuguese (pt-PT). Captured on the largest iPhone simulator (6.9-inch, 1320 × 2868, no alpha) by `.github/workflows/screenshots.yml`.

Locations and statistics come from the production API. For these captures only, the app is launched with `-StoreScreenshots`: the operator line is blank, and any container without a usable reading gets a recent capture reading so the picture never shows "Sem leitura". Real users do not get that overlay.

The workflow saves PNGs. It does not draw marketing captions. The caption for `02-espaco.png` is **Vê que ecopontos têm espaço**.

Upload in this order:

1. `01-mapa.png` — map around Barcelos.
2. `02-espaco.png` — Barcelos filtered to ecopontos with space. Caption: "Vê que ecopontos têm espaço".
3. `03-ecoponto.png` — ecoponto details, collection information and report button, without the operator line.
4. `04-reportar.png` — the two report choices.
5. `05-guia.png` — recycling guide for a glass-varnish jar, including its published sources.
6. `06-guia-mapa.png` — map filtered to glass.
7. `07-estatisticas.png` — catalog statistics.
8. `08-sem-cobertura.png` — an area with no ecopontos.

The capture test is `../CaptureTests/StoreCaptureTests.swift`. It uses `com.rgllm.reciclar`, does not submit reports, and keeps the status bar at 09:41 with a full battery. The map is centred on Barcelos (41.5388, -8.6151).

Source: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
