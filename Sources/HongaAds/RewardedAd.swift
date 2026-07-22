#if canImport(UIKit)
import UIKit

/// Rewarded (opt-in com recompensa). O callback de recompensa só dispara
/// depois de o servidor confirmar a visualização — nunca atribua a
/// recompensa por outra via.
///
/// ```swift
/// if let ad = await RewardedAd.load(unitId: "hy-unit-xxxx") {
///     ad.show(from: viewController) { _ in darRecompensa() }
/// }
/// ```
public final class RewardedAd {

    /// Segundos de visualização exigidos. Default 15 — alinhado com o servidor.
    public var minViewSegundos: Int = 15

    private let resultado: ServeResultado

    private var consumido = false

    private init(resultado: ServeResultado) {
        self.resultado = resultado
    }

    /// Carrega o próximo rewarded. `nil` = no-fill/erro.
    public static func load(unitId: String) async -> RewardedAd? {
        guard let resultado = await HongaAds.exigirInicializacao().serve(unitUid: unitId) else {
            return nil
        }

        return RewardedAd(resultado: resultado)
    }

    @MainActor
    public func show(
        from apresentador: UIViewController,
        onClose: (() -> Void)? = nil,
        onReward: @escaping (RewardResultado) -> Void
    ) {
        guard !consumido else { return }
        consumido = true

        let controlador = FullscreenAdViewController(
            resultado: resultado,
            rewarded: true,
            skipAfterSegundos: 0,
            minViewSegundos: minViewSegundos,
            onReward: onReward,
            onClose: onClose
        )

        apresentador.present(controlador, animated: true)
    }
}
#endif
