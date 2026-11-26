# Honga Ads — SDK iOS (Swift)

SDK nativo iOS da rede de publishers Honga Yetu: banner, nativo, interstitial e rewarded. Swift Package sem dependências (URLSession + UIKit).

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

// Nativo (desde a 0.2.0) — desenhado por peças, para listas e conteúdo
let nativo = HongaAdsNativeView()
nativo.forma = .linha // por omissão .destaque
nativo.loadAd(unitId: "hy-unit-xxxxxxxx")
stack.addArrangedSubview(nativo)

// Interstitial (ciclo load/show)
if let ad = await InterstitialAd.load(unitId: "hy-unit-yyyy") {
    ad.show(from: viewController) // nil = no-fill
}

// Rewarded — onReward só dispara após confirmação server-side.
if let ad = await RewardedAd.load(unitId: "hy-unit-zzzz") {
    ad.show(from: viewController) { _ in darRecompensa() }
}
```

## Anúncio nativo (desde a 0.2.0)

O `HongaAdsNativeView` desenha o anúncio com as suas **peças** (fotografia sem texto, título, descrição, botão, logótipo e anunciante) e a etiqueta «Patrocinado», em vez de uma imagem pronta.

- Usa as cores do sistema (`.systemBackground`, `.label`, `.secondaryLabel`, `.separator`) e o `tintColor` da view, no modo claro e no escuro, e a letra dinâmica. Para dizer as tuas: `nativo.cores = CoresNativo(...)`; a letra: `nativo.nomeDaLetra`; os cantos: `nativo.raio`.
- É plano: sem gradientes nem sombras. A fotografia é recortada à caixa e pede-se na largura mais pequena que chegue.
- A cor da marca só entra no botão, e só quando tem contraste (3:1) com a superfície; senão usa-se a `primaria` (o `tintColor`).
- Um anúncio sem peças sai como imagem pronta, como no banner. No-fill esconde a view.
- A etiqueta «Patrocinado» é obrigatória e não tem opção para a esconder.
- A impressão e o clique são os do banner.

O banner, o interstitial e o rewarded não mudam: continuam com a imagem ou o vídeo prontos.

## Comportamento

- **Impressões**: registadas após 1s de exibição (banner/interstitial); no rewarded, no fim da visualização mínima (15s), medida e validada pelo servidor.
- **Tokens de uso único**: cada anúncio mostrado consome os tokens — `load()` de novo para o próximo.
- **No-fill / falhas de rede**: nunca bloqueiam a app — o banner colapsa e o `load` devolve `nil`.
- **Ambiente test**: com chaves `hy_test_` os criativos vêm marcados como teste e não geram custo nem receita.

## Build

```bash
xcodebuild -scheme HongaAds -destination 'generic/platform=iOS' build
```
