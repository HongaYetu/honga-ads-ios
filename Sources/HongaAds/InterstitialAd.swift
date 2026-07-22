#if canImport(UIKit)
import UIKit

/// Interstitial (ecrã inteiro em pausas naturais da app). Ciclo load/show:
///
/// ```swift
/// if let ad = await InterstitialAd.load(unitId: "hy-unit-xxxx") {
///     ad.show(from: viewController)
/// } // nil = no-fill
/// ```
///
/// Cada instância é de uso único — os tokens são consumidos no show.
public final class InterstitialAd {

    /// Segundos até o botão fechar aparecer. Default 5.
    public var skipAfterSegundos: Double = 5

    private let resultado: ServeResultado

    private var consumido = false

    private init(resultado: ServeResultado) {
        self.resultado = resultado
    }

    /// Carrega o próximo interstitial. `nil` = no-fill/erro.
    public static func load(unitId: String) async -> InterstitialAd? {
        guard let resultado = await HongaAds.exigirInicializacao().serve(unitUid: unitId) else {
            return nil
        }

        return InterstitialAd(resultado: resultado)
    }

    @MainActor
    public func show(from apresentador: UIViewController, onClose: (() -> Void)? = nil) {
        guard !consumido else { return }
        consumido = true

        let controlador = FullscreenAdViewController(
            resultado: resultado,
            rewarded: false,
            skipAfterSegundos: skipAfterSegundos,
            minViewSegundos: 0,
            onReward: nil,
            onClose: onClose
        )

        apresentador.present(controlador, animated: true)
    }
}
#endif
