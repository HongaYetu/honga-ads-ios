import Foundation

public struct AdAsset: Sendable {
    public let tipo: String
    public let url: String
    public let largura: Int?
    public let altura: Int?
    public let textoTitulo: String?
    public let textoCta: String?
}

public struct Anuncio: Sendable {
    public let id: Int
    public let nome: String?
    /// true quando servido em ambiente test (criativo fictício, sem custo).
    public let teste: Bool
    public let assets: [AdAsset]
    /// As peças do anúncio (a chave `nativo` do `/serve`), para o desenhar
    /// com componentes da app. nil nos anúncios sem peças: vale o asset.
    public let nativo: PecasNativo?
}

public struct ServeResultado: Sendable {
    public let anuncio: Anuncio
    public let impressionToken: String
    public let clickToken: String
}

public struct RewardResultado: Sendable {
    public let recompensa: Bool
    public let motivo: String?
    public let teste: Bool
}

/// Cliente HTTP interno (URLSession, sem dependências). Todos os métodos
/// degradam em silêncio — uma falha de rede nunca rebenta a app do publisher.
final class AdsClient: @unchecked Sendable {

    private let publisherId: String
    private let apiKey: String
    private let endpoint: String
    private let deviceId: String

    init(publisherId: String, apiKey: String, endpoint: String, deviceId: String) {
        self.publisherId = publisherId
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.deviceId = deviceId
    }

    /// Pede um anúncio. Devolve nil em no-fill ou erro.
    func serve(unitUid: String, slotWidth: Int? = nil, slotHeight: Int? = nil, aceitaNativo: Bool = false) async -> ServeResultado? {
        var corpo: [String: Any] = [
            "ad_unit_uid": unitUid,
            "device_id": deviceId,
        ]
        if let slotWidth { corpo["slot_width"] = slotWidth }
        if let slotHeight { corpo["slot_height"] = slotHeight }
        // Só segue quando é verdade: o banner, o interstitial e o rewarded
        // fazem exactamente o pedido de sempre.
        if aceitaNativo { corpo["aceita_nativo"] = true }

        guard
            let resposta = await post("/serve", corpo: corpo),
            resposta["estado"] as? String == "ok",
            let data = resposta["data"] as? [String: Any],
            let anuncioJson = data["anuncio"] as? [String: Any],
            let tokens = data["tokens"] as? [String: Any],
            let impression = tokens["impression"] as? String,
            let click = tokens["click"] as? String
        else {
            return nil
        }

        let assets = ((anuncioJson["assets"] as? [[String: Any]]) ?? []).compactMap { asset -> AdAsset? in
            guard let url = asset["url"] as? String, !url.isEmpty else {
                return nil
            }

            return AdAsset(
                tipo: asset["tipo"] as? String ?? "imagem",
                url: url,
                largura: asset["largura"] as? Int,
                altura: asset["altura"] as? Int,
                textoTitulo: asset["texto_titulo"] as? String,
                textoCta: asset["texto_cta"] as? String
            )
        }

        // Só quem pediu peças as lê. Com `aceita_nativo`, um anúncio por peças
        // pode vir sem assets; sem peças nem assets não há nada para mostrar.
        let nativo = aceitaNativo ? Pecas.ler(anuncioJson["nativo"]) : nil

        guard !assets.isEmpty || nativo != nil else {
            return nil
        }

        return ServeResultado(
            anuncio: Anuncio(
                id: anuncioJson["id"] as? Int ?? 0,
                nome: anuncioJson["nome"] as? String,
                teste: anuncioJson["teste"] as? Bool ?? false,
                assets: assets,
                nativo: nativo
            ),
            impressionToken: impression,
            clickToken: click
        )
    }

    /// Regista a impressão — chamar apenas quando o anúncio está visível.
    func impression(token: String) async {
        _ = await post("/impression", corpo: ["token": token, "device_id": deviceId])
    }

    /// Regista o clique e devolve o destino do anunciante (ou nil).
    func click(token: String) async -> String? {
        guard let resposta = await post("/click", corpo: ["token": token, "device_id": deviceId]) else {
            return nil
        }

        return (resposta["data"] as? [String: Any])?["redirect_url"] as? String
    }

    /// Confirmação server-side do rewarded — a recompensa só deve ser
    /// atribuída quando `recompensa == true`.
    func rewardConfirm(token: String) async -> RewardResultado {
        guard let resposta = await post("/reward-confirm", corpo: ["token": token, "device_id": deviceId]) else {
            return RewardResultado(recompensa: false, motivo: "erro_rede", teste: false)
        }

        return RewardResultado(
            recompensa: resposta["recompensa"] as? Bool ?? false,
            motivo: resposta["motivo"] as? String,
            teste: resposta["teste"] as? Bool ?? false
        )
    }

    private func post(_ caminho: String, corpo: [String: Any]) async -> [String: Any]? {
        guard let url = URL(string: endpoint + caminho) else {
            return nil
        }

        var pedido = URLRequest(url: url, timeoutInterval: 8)
        pedido.httpMethod = "POST"
        pedido.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)
            let (dados, _) = try await URLSession.shared.data(for: pedido)

            return try JSONSerialization.jsonObject(with: dados) as? [String: Any]
        } catch {
            return nil
        }
    }
}
