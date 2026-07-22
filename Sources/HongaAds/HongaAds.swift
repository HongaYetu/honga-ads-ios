import Foundation

/// Ponto de entrada do SDK Honga Ads. Inicializar uma vez (App/AppDelegate):
///
/// ```swift
/// HongaAds.initialize(
///     publisherId: "hy-pub-xxxxxxxx",
///     apiKey: "hy_test_xxxx|secret" // hy_live_ em produção
/// )
/// ```
public enum HongaAds {

    static var cliente: AdsClient?

    public static func initialize(
        publisherId: String,
        apiKey: String,
        endpoint: String = "https://anuncios.hongayetu.com/api/v2/ads"
    ) {
        cliente = AdsClient(
            publisherId: publisherId,
            apiKey: apiKey,
            endpoint: endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint,
            deviceId: deviceIdPersistente()
        )
    }

    static func exigirInicializacao() -> AdsClient {
        guard let cliente else {
            fatalError("[HongaAds] Chame HongaAds.initialize() antes de carregar anúncios.")
        }

        return cliente
    }

    private static func deviceIdPersistente() -> String {
        let chave = "hga.device_id"

        if let existente = UserDefaults.standard.string(forKey: chave) {
            return existente
        }

        let novo = UUID().uuidString.lowercased()
        UserDefaults.standard.set(novo, forKey: chave)

        return novo
    }
}
