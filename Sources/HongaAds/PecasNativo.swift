import Foundation

/// As peças de um anúncio — a chave `nativo` do `/serve`.
///
/// O servidor manda a fotografia **sem texto**, o título, a descrição, o
/// botão, o logótipo e a cor da marca, e a app desenha o anúncio com os seus
/// próprios componentes, com a etiqueta «Patrocinado».
///
/// Só o `titulo` é garantido. Um campo em falta dá um cartão mais pobre,
/// nunca um erro.
public struct PecasNativo: Sendable {
    public let titulo: String
    public let descricao: String?
    public let cta: CtaNativo?
    public let imagem: ImagemNativo?
    public let logoUrl: String?
    public let anunciante: String?
    /// `#RRGGBB`. Só entra no botão ou num filete, e só quando tem contraste.
    public let corMarca: String?
}

/// O botão. O `texto` já vem em português e é o que se mostra; o `codigo` é
/// de uma lista fechada (`saber_mais`, `comprar`, …) e serve, quando muito,
/// para escolher um ícone — nunca para traduzir.
public struct CtaNativo: Sendable {
    public let codigo: String?
    public let texto: String
}

public struct VarianteImagemNativo: Sendable {
    public let largura: Int
    public let url: String
}

/// A fotografia sem texto por cima. As `variantes` vêm por ordem crescente de largura.
public struct ImagemNativo: Sendable {
    public let url: String
    public let largura: Int?
    public let altura: Int?
    public let variantes: [VarianteImagemNativo]

    /// O endereço a pedir para uma caixa com `larguraPx` píxeis de largura: a
    /// variante mais pequena que chegue. Nenhuma chega → a maior que houver.
    public func urlPara(larguraPx: Int) -> String {
        var candidatas = variantes
        if let largura { candidatas.append(VarianteImagemNativo(largura: largura, url: url)) }
        candidatas.sort { $0.largura < $1.largura }

        guard let maior = candidatas.last, larguraPx > 0 else { return url }

        return candidatas.first { $0.largura >= larguraPx }?.url ?? maior.url
    }
}

enum Pecas {

    private static func texto(_ valor: Any?) -> String? {
        guard let valor = valor as? String else { return nil }
        let limpo = valor.trimmingCharacters(in: .whitespacesAndNewlines)

        return limpo.isEmpty ? nil : limpo
    }

    private static func endereco(_ valor: Any?) -> String? {
        guard let url = texto(valor) else { return nil }
        let minusculas = url.lowercased()

        return minusculas.hasPrefix("https://") || minusculas.hasPrefix("http://") ? url : nil
    }

    private static func inteiro(_ valor: Any?) -> Int? {
        guard let numero = (valor as? NSNumber)?.intValue, numero > 0 else { return nil }

        return numero
    }

    /// Lê a chave `nativo`. Devolve nil — «desenha como hoje» — quando a chave
    /// não veio, veio a null ou não traz título. Cada peça lê-se à parte: uma
    /// `imagem` com forma inesperada perde a fotografia, não o título e o botão.
    static func ler(_ bruto: Any?) -> PecasNativo? {
        guard let json = bruto as? [String: Any], let titulo = texto(json["titulo"]) else {
            return nil
        }

        var cta: CtaNativo?
        if let c = json["cta"] as? [String: Any], let textoDoBotao = texto(c["texto"]) {
            // Um botão sem texto não se desenha: o código não se traduz no cliente.
            cta = CtaNativo(codigo: texto(c["codigo"]), texto: textoDoBotao)
        }

        var imagem: ImagemNativo?
        if let i = json["imagem"] as? [String: Any] {
            let variantes = ((i["variantes"] as? [[String: Any]]) ?? [])
                .compactMap { v -> VarianteImagemNativo? in
                    guard let url = endereco(v["url"]), let largura = inteiro(v["largura"]) else { return nil }

                    return VarianteImagemNativo(largura: largura, url: url)
                }
                .sorted { $0.largura < $1.largura }

            if let url = endereco(i["url"]) ?? variantes.last?.url {
                imagem = ImagemNativo(url: url, largura: inteiro(i["largura"]), altura: inteiro(i["altura"]), variantes: variantes)
            }
        }

        let cor = texto(json["cor_marca"])

        return PecasNativo(
            titulo: titulo,
            descricao: texto(json["descricao"]),
            cta: cta,
            imagem: imagem,
            logoUrl: endereco(json["logo_url"]),
            anunciante: texto(json["anunciante"]),
            corMarca: rgbDeHex(cor) != nil ? cor : nil
        )
    }

    /// `#RGB` ou `#RRGGBB` (com ou sem cardinal) → `0xRRGGBB`. nil se não for uma cor.
    static func rgbDeHex(_ hex: String?) -> Int? {
        guard var limpo = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if limpo.hasPrefix("#") { limpo.removeFirst() }
        if limpo.count == 3 { limpo = limpo.map { "\($0)\($0)" }.joined() }
        guard limpo.count == 6 else { return nil }

        return Int(limpo, radix: 16)
    }

    /// Luminância relativa (WCAG 2) de uma cor `0xRRGGBB`.
    static func luminancia(_ rgb: Int) -> Double {
        func canal(_ v: Int) -> Double {
            let c = Double(v) / 255.0

            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * canal((rgb >> 16) & 0xFF) + 0.7152 * canal((rgb >> 8) & 0xFF) + 0.0722 * canal(rgb & 0xFF)
    }

    /// Rácio de contraste (WCAG 2) entre duas cores `0xRRGGBB` — de 1 a 21.
    static func contraste(_ a: Int, _ b: Int) -> Double {
        let la = luminancia(a)
        let lb = luminancia(b)

        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// O mínimo para a cor da marca servir de botão sobre a superfície da app:
    /// 3:1. Abaixo disso usa-se a cor primária da app.
    static func marcaTemContraste(_ marca: Int, superficie: Int) -> Bool {
        contraste(marca, superficie) >= 3.0
    }

    /// Texto por cima de um fundo `0xRRGGBB`: branco ou preto, o que se ler melhor.
    static func textoClaroSobre(_ fundo: Int) -> Bool {
        contraste(0xFFFFFF, fundo) >= contraste(0x000000, fundo)
    }
}
