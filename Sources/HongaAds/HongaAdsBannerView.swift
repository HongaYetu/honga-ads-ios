#if canImport(UIKit)
import UIKit

/// Banner Honga Ads. Uso:
///
/// ```swift
/// let banner = HongaAdsBannerView()
/// banner.loadAd(unitId: "hy-unit-xxxxxxxx")
/// stack.addArrangedSubview(banner)
/// ```
///
/// Em no-fill ou erro a view colapsa (isHidden). A impressão é registada
/// após 1 segundo com a view na janela; o clique abre o destino do
/// anunciante no browser.
public final class HongaAdsBannerView: UIView {

    private let imagem = UIImageView()

    private let badgeTeste = UILabel()

    private var resultado: ServeResultado?

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
        imagem.contentMode = .scaleAspectFit
        imagem.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imagem)

        badgeTeste.text = "Teste"
        badgeTeste.font = .boldSystemFont(ofSize: 10)
        badgeTeste.textColor = .black
        badgeTeste.backgroundColor = UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)
        badgeTeste.isHidden = true
        badgeTeste.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeTeste)

        NSLayoutConstraint.activate([
            imagem.topAnchor.constraint(equalTo: topAnchor),
            imagem.bottomAnchor.constraint(equalTo: bottomAnchor),
            imagem.leadingAnchor.constraint(equalTo: leadingAnchor),
            imagem.trailingAnchor.constraint(equalTo: trailingAnchor),
            badgeTeste.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            badgeTeste.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
        ])

        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(aoTocar)))
    }

    public func loadAd(unitId: String) {
        let cliente = HongaAds.exigirInicializacao()

        tarefa?.cancel()
        impressaoEnviada = false

        tarefa = Task { [weak self] in
            guard let servido = await cliente.serve(unitUid: unitId) else {
                await MainActor.run { self?.isHidden = true }
                return
            }

            guard let asset = servido.anuncio.assets.first,
                  let bitmap = await Imagens.carregar(asset.url) else {
                await MainActor.run { self?.isHidden = true }
                return
            }

            await MainActor.run {
                guard let self else { return }
                self.resultado = servido
                self.isHidden = false
                self.imagem.image = bitmap
                self.badgeTeste.isHidden = !servido.anuncio.teste
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
#endif
