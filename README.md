# Honga Ads — SDK iOS (Swift)

SDK nativo iOS da rede de publishers Honga Yetu: banner, interstitial e rewarded. Swift Package sem dependências (URLSession + UIKit).

Documentação completa: [dev.honga.com/docs/honga-ads](https://dev.honga.com/docs/honga-ads).

## Instalação (Swift Package Manager)

Em Xcode: **File → Add Package Dependencies** → `https://github.com/HongaYetu/honga-ads-ios`.

## Uso

```swift
import HongaAds

// App/AppDelegate — use uma chave hy_test_ durante a integração.
HongaAds.initialize(
    publisherId: "hy-pub-xxxxxxxx",
    apiKey: "hy_live_xxxx|secret"
)

// Banner
let banner = HongaAdsBannerView()
banner.loadAd(unitId: "hy-unit-xxxxxxxx")
stack.addArrangedSubview(banner)

// Interstitial (ciclo load/show)
if let ad = await InterstitialAd.load(unitId: "hy-unit-yyyy") {
    ad.show(from: viewController) // nil = no-fill
}

// Rewarded — onReward só dispara após confirmação server-side.
if let ad = await RewardedAd.load(unitId: "hy-unit-zzzz") {
    ad.show(from: viewController) { _ in darRecompensa() }
}
```

## Comportamento

- **Impressões**: registadas após 1s de exibição (banner/interstitial); no rewarded, no fim da visualização mínima (15s), medida e validada pelo servidor.
- **Tokens de uso único**: cada anúncio mostrado consome os tokens — `load()` de novo para o próximo.
- **No-fill / falhas de rede**: nunca bloqueiam a app — o banner colapsa e o `load` devolve `nil`.
- **Ambiente test**: com chaves `hy_test_` os criativos vêm marcados como teste e não geram custo nem receita.

## Build

```bash
xcodebuild -scheme HongaAds -destination 'generic/platform=iOS' build
```
