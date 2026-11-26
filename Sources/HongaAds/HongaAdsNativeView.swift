#if canImport(UIKit)
import UIKit

/// As cores do cartão nativo. Por omissão são as do sistema (`.systemBackground`,
/// `.label`, `.secondaryLabel`, `.separator`) e o `tintColor` da view — é isso
/// que faz o cartão parecer da app onde entra, no modo claro e no escuro.
public struct CoresNativo {
    public var superficie: UIColor
    public var contorno: UIColor
    public var texto: UIColor
    public var textoSecundario: UIColor
    /// A cor do botão quando a marca não tem cor ou não tem contraste. nil usa o `tintColor`.
    public var primaria: UIColor?
    /// nil escolhe branco ou preto, o que se ler melhor sobre a `primaria`.
    public var sobrePrimaria: UIColor?

    public init(
        superficie: UIColor = .systemBackground,
        contorno: UIColor = .separator,
        texto: UIColor = .label,
        textoSecundario: UIColor = .secondaryLabel,
        primaria: UIColor? = nil,
        sobrePrimaria: UIColor? = nil
    ) {
        self.superficie = superficie
        self.contorno = contorno
        self.texto = texto
        self.textoSecundario = textoSecundario
        self.primaria = primaria
        self.sobrePrimaria = sobrePrimaria
    }
}

/// Anúncio nativo Honga Ads: desenhado **por peças** com componentes da app
/// (fotografia sem texto, título, descrição, botão, logótipo e anunciante) e a
/// etiqueta «Patrocinado», em vez de uma imagem pronta. Para os espaços dentro
/// de listas ou de conteúdo.
///
/// ```swift
/// let nativo = HongaAdsNativeView()
/// nativo.loadAd(unitId: "hy-unit-xxxxxxxx")
/// stack.addArrangedSubview(nativo)
/// ```
///
/// O cartão é plano (sem gradientes nem sombras) e usa as cores do sistema e a
/// letra dinâmica. A fotografia desenha-se recortada à caixa; sem fotografia
/// fica o logótipo, o título, a descrição e o botão sobre a cor de superfície.
/// A cor da marca só entra no botão, e só quando tem contraste com a superfície.
///
/// Um anúncio sem peças sai como imagem pronta, como no `HongaAdsBannerView`.
/// Em no-fill ou erro a view colapsa (isHidden). A impressão e o clique são os
/// do banner.
public final class HongaAdsNativeView: UIView {

    /// As duas formas do cartão.
    public enum Forma {
        /// A fotografia em cima, a toda a largura, e o texto por baixo.
        case destaque
        /// Uma linha de lista: a fotografia pequena à esquerda e o texto ao lado.
        case linha
    }

    /// A etiqueta obrigatória de um anúncio desenhado por peças.
    public static let etiquetaPatrocinado = "Patrocinado"

    /// Definir antes de `loadAd`.
    public var forma: Forma = .destaque

    /// As cores do cartão. Definir antes de `loadAd`.
    public var cores = CoresNativo()

    /// O nome da letra da app para os textos do cartão. nil usa a do sistema. Definir antes de `loadAd`.
    public var nomeDaLetra: String?

    /// Os cantos do cartão.
    public var raio: CGFloat = 12

    private let cartao = UIStackView()

    private let badgeTeste = UILabel()

    private var resultado: ServeResultado?

    private var pecas: PecasNativo?

    private var botao: UILabel?

    private var foto: UIImageView?

    private var fotoPedida = false

    private var impressaoEnviada = false

    private var tarefa: Task<Void, Never>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        montar()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        montar()
    }

    private func montar() {
        cartao.translatesAutoresizingMaskIntoConstraints = false
        cartao.layer.borderWidth = 1
        cartao.layer.masksToBounds = true
        addSubview(cartao)

        badgeTeste.text = "Teste"
        badgeTeste.font = .boldSystemFont(ofSize: 10)
        badgeTeste.textColor = .black
        badgeTeste.backgroundColor = UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)
        badgeTeste.isHidden = true
        badgeTeste.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeTeste)

        NSLayoutConstraint.activate([
            cartao.topAnchor.constraint(equalTo: topAnchor),
            cartao.bottomAnchor.constraint(equalTo: bottomAnchor),
            cartao.leadingAnchor.constraint(equalTo: leadingAnchor),
            cartao.trailingAnchor.constraint(equalTo: trailingAnchor),
            badgeTeste.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            badgeTeste.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .link
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(aoTocar)))
    }

    public func loadAd(unitId: String) {
        let cliente = HongaAds.exigirInicializacao()

        tarefa?.cancel()
        impressaoEnviada = false

        tarefa = Task { [weak self] in
            guard let servido = await cliente.serve(unitUid: unitId, aceitaNativo: true) else {
                await MainActor.run { self?.isHidden = true }
                return
            }

            if let pecas = servido.anuncio.nativo {
                await MainActor.run {
                    guard let self else { return }
                    self.resultado = servido
                    self.isHidden = false
                    self.desenhar(pecas)
                    self.badgeTeste.isHidden = !servido.anuncio.teste
                }
            } else {
                // Sem peças: a imagem pronta, como no banner.
                guard let asset = servido.anuncio.assets.first,
                      let bitmap = await Imagens.carregar(asset.url) else {
                    await MainActor.run { self?.isHidden = true }
                    return
                }

                await MainActor.run {
                    guard let self else { return }
                    self.resultado = servido
                    self.isHidden = false
                    self.desenharImagemPronta(bitmap, nome: servido.anuncio.nome)
                    self.badgeTeste.isHidden = !servido.anuncio.teste
                }
            }

            // Impressão após 1s de exibição — a view tem de continuar na
            // janela (aproximação da viewability web 50%/1s).
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                guard let self, self.window != nil, !self.isHidden, !self.impressaoEnviada else { return }
                self.impressaoEnviada = true
                Task { await cliente.impression(token: servido.impressionToken) }
            }
        }
    }

    private func limpar() {
        cartao.arrangedSubviews.forEach { $0.removeFromSuperview() }
        pecas = nil
        botao = nil
        foto = nil
        fotoPedida = false
    }

    private func desenharImagemPronta(_ bitmap: UIImage, nome: String?) {
        limpar()
        cartao.axis = .vertical
        cartao.layer.borderWidth = 0
        cartao.layer.cornerRadius = 0
        cartao.backgroundColor = .clear
        cartao.isLayoutMarginsRelativeArrangement = false

        let imagem = UIImageView(image: bitmap)
        imagem.contentMode = .scaleAspectFit
        if bitmap.size.width > 0 {
            imagem.heightAnchor.constraint(equalTo: imagem.widthAnchor, multiplier: bitmap.size.height / bitmap.size.width).isActive = true
        }
        cartao.addArrangedSubview(imagem)
        accessibilityLabel = nome ?? "Anúncio"
    }

    private func desenhar(_ pecas: PecasNativo) {
        limpar()
        self.pecas = pecas

        let emLinha = forma == .linha

        cartao.axis = emLinha ? .horizontal : .vertical
        cartao.alignment = emLinha ? .top : .fill
        cartao.spacing = emLinha ? 12 : 0
        cartao.backgroundColor = cores.superficie
        cartao.layer.borderWidth = 1
        cartao.layer.cornerRadius = raio
        cartao.isLayoutMarginsRelativeArrangement = emLinha
        cartao.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        if let imagem = pecas.imagem {
            let vista = UIImageView()
            vista.contentMode = .scaleAspectFill
            vista.clipsToBounds = true
            vista.backgroundColor = cores.contorno
            vista.translatesAutoresizingMaskIntoConstraints = false

            if emLinha {
                vista.layer.cornerRadius = 8
                vista.widthAnchor.constraint(equalToConstant: 72).isActive = true
                vista.heightAnchor.constraint(equalToConstant: 72).isActive = true
            } else {
                // Uma fotografia mais alta do que 4:3 é recortada: é um cartão de lista.
                var racio: CGFloat = 1.91
                if let largura = imagem.largura, let altura = imagem.altura, altura > 0 {
                    racio = CGFloat(largura) / CGFloat(altura)
                }
                racio = min(max(racio, 4.0 / 3.0), 1.91)
                vista.heightAnchor.constraint(equalTo: vista.widthAnchor, multiplier: 1 / racio).isActive = true
            }

            cartao.addArrangedSubview(vista)
            foto = vista
        }

        let coluna = UIStackView()
        coluna.axis = .vertical
        coluna.alignment = .leading
        coluna.spacing = 6
        coluna.isLayoutMarginsRelativeArrangement = !emLinha
        coluna.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let cabecalho = UIStackView()
        cabecalho.axis = .horizontal
        cabecalho.alignment = .center
        cabecalho.spacing = 6

        if pecas.anunciante != nil, let endereco = pecas.logoUrl {
            let logo = UIImageView()
            logo.contentMode = .scaleAspectFill
            logo.clipsToBounds = true
            logo.layer.cornerRadius = 9
            logo.isHidden = true
            logo.widthAnchor.constraint(equalToConstant: 18).isActive = true
            logo.heightAnchor.constraint(equalToConstant: 18).isActive = true
            cabecalho.addArrangedSubview(logo)

            Task { [weak logo] in
                guard let bitmap = await Imagens.carregar(endereco) else { return }
                await MainActor.run {
                    logo?.image = bitmap
                    logo?.isHidden = false
                }
            }
        }

        let nome = rotulo(pecas.anunciante ?? "", estilo: .caption1, cor: cores.textoSecundario, linhas: 1)
        nome.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nome.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cabecalho.addArrangedSubview(nome)

        let etiqueta = rotulo(Self.etiquetaPatrocinado, estilo: .caption2, cor: cores.textoSecundario, linhas: 1)
        etiqueta.setContentHuggingPriority(.required, for: .horizontal)
        etiqueta.setContentCompressionResistancePriority(.required, for: .horizontal)
        cabecalho.addArrangedSubview(etiqueta)

        coluna.addArrangedSubview(cabecalho)
        cabecalho.widthAnchor.constraint(equalTo: coluna.layoutMarginsGuide.widthAnchor).isActive = true

        coluna.addArrangedSubview(rotulo(pecas.titulo, estilo: .subheadline, cor: cores.texto, linhas: 2, negrito: true))

        if let descricao = pecas.descricao {
            coluna.addArrangedSubview(rotulo(descricao, estilo: .footnote, cor: cores.textoSecundario, linhas: emLinha ? 1 : 2))
        }

        if let cta = pecas.cta {
            let etiquetaDoBotao = RotuloComMargem()
            etiquetaDoBotao.text = cta.texto
            etiquetaDoBotao.font = letra(.footnote, negrito: true)
            etiquetaDoBotao.adjustsFontForContentSizeCategory = true
            etiquetaDoBotao.numberOfLines = 1
            etiquetaDoBotao.layer.cornerRadius = 8
            etiquetaDoBotao.layer.masksToBounds = true
            coluna.addArrangedSubview(etiquetaDoBotao)
            coluna.setCustomSpacing(8, after: coluna.arrangedSubviews[coluna.arrangedSubviews.count - 2])
            botao = etiquetaDoBotao
        }

        cartao.addArrangedSubview(coluna)

        accessibilityLabel = [Self.etiquetaPatrocinado, pecas.titulo, pecas.anunciante].compactMap { $0 }.joined(separator: ". ")

        pintar()
        setNeedsLayout()
    }

    /// As cores que dependem do modo claro/escuro: o contorno (um `CGColor`
    /// não se actualiza sozinho) e o botão, cujo contraste com a superfície
    /// muda com o tema.
    private func pintar() {
        cartao.layer.borderColor = cores.contorno.resolvedColor(with: traitCollection).cgColor

        guard let botao, let pecas else { return }

        let superficie = Self.rgb(cores.superficie.resolvedColor(with: traitCollection))
        let primaria = cores.primaria ?? tintColor ?? .systemBlue

        if let marca = Pecas.rgbDeHex(pecas.corMarca), Pecas.marcaTemContraste(marca, superficie: superficie) {
            botao.backgroundColor = UIColor(
                red: CGFloat((marca >> 16) & 0xFF) / 255,
                green: CGFloat((marca >> 8) & 0xFF) / 255,
                blue: CGFloat(marca & 0xFF) / 255,
                alpha: 1
            )
            botao.textColor = Pecas.textoClaroSobre(marca) ? .white : .black
        } else {
            botao.backgroundColor = primaria
            botao.textColor = cores.sobrePrimaria
                ?? (Pecas.textoClaroSobre(Self.rgb(primaria.resolvedColor(with: traitCollection))) ? .white : .black)
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        pintar()
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()
        pintar()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // Só depois de medida se sabe a largura da caixa — e com ela a
        // variante mais pequena que chegue.
        guard !fotoPedida, let foto, let imagem = pecas?.imagem, foto.bounds.width > 0 else { return }
        fotoPedida = true

        let escala = window?.screen.scale ?? traitCollection.displayScale
        let endereco = imagem.urlPara(larguraPx: Int((foto.bounds.width * max(escala, 1)).rounded(.up)))

        Task { [weak foto] in
            let bitmap = await Imagens.carregar(endereco)
            await MainActor.run {
                if let bitmap {
                    foto?.image = bitmap
                } else {
                    foto?.isHidden = true
                }
            }
        }
    }

    private func letra(_ estilo: UIFont.TextStyle, negrito: Bool = false) -> UIFont {
        let tamanho = UIFont.preferredFont(forTextStyle: estilo).pointSize
        let base: UIFont
        if let nomeDaLetra, let propria = UIFont(name: nomeDaLetra, size: tamanho) {
            base = propria
        } else {
            base = .systemFont(ofSize: tamanho, weight: negrito ? .semibold : .regular)
        }

        return UIFontMetrics(forTextStyle: estilo).scaledFont(for: base)
    }

    private func rotulo(_ texto: String, estilo: UIFont.TextStyle, cor: UIColor, linhas: Int, negrito: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = texto
        label.font = letra(estilo, negrito: negrito)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = cor
        label.numberOfLines = linhas
        label.lineBreakMode = .byTruncatingTail

        return label
    }

    private static func rgb(_ cor: UIColor) -> Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard cor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0xFFFFFF }
        func canal(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }

        return (canal(r) << 16) | (canal(g) << 8) | canal(b)
    }

    @objc private func aoTocar() {
        guard let resultado else { return }
        let cliente = HongaAds.exigirInicializacao()

        Task {
            guard let destino = await cliente.click(token: resultado.clickToken),
                  let url = URL(string: destino) else { return }

            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }

    deinit {
        tarefa?.cancel()
    }
}

/// O botão: um rótulo com margem à volta do texto. O toque é o do cartão inteiro.
private final class RotuloComMargem: UILabel {

    private let margem = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: margem))
    }

    override var intrinsicContentSize: CGSize {
        let tamanho = super.intrinsicContentSize

        return CGSize(width: tamanho.width + margem.left + margem.right, height: tamanho.height + margem.top + margem.bottom)
    }
}
#endif
