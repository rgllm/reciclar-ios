# Reciclar — App Store screenshots

Five unedited screenshots of the running iOS app, using production data and Portuguese copy. Captured on an iPhone 17 Pro Max simulator (iOS 26.5). Each PNG is portrait, 1320 × 2868 pixels, without an alpha channel, for the App Store Connect 6.9-inch iPhone screenshot slot.

Upload in this order:

1. `pt-PT/iphone-6.9/01-mapa.png` — map around Barcelos.
2. `pt-PT/iphone-6.9/02-ecoponto.png` — ecoponto details and collection information.
3. `pt-PT/iphone-6.9/03-reciclagem.png` — recycling guide.
4. `pt-PT/iphone-6.9/04-separacao.png` — glass jar disposal instructions.
5. `pt-PT/iphone-6.9/05-estatisticas.png` — catalog statistics.

The capture tests are in `../CaptureTests/StoreCaptureTests.swift`. They use the real `com.rgllm.reciclar` application and do not submit reports. A separate temporary Xcode project was used to avoid changing the app's signing and release settings. The status bar is set to 09:41 and a full battery. Collection dates and measurements come from the API; no values were fabricated.

Source: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
