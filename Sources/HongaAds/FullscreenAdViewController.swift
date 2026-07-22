#if canImport(UIKit)
import UIKit

/// View controller fullscreen partilhado por interstitial e rewarded.
/// Interstitial: impressão após 1s, fechar após `skipAfterSegundos`.
/// Rewarded: contagem decrescente; no fim envia a impressão (o servidor
/// mede o tempo entre o serve e o redeem) e confirma a recompensa
/// server-side antes de disparar `onReward`.
final class FullscreenAdViewController: UIViewController {

    private let resultado: ServeResultado
    private let rewarded: Bool
    private let skipAfterSegundos: Double
    private let minViewSegundos: Int
    private let onReward: ((RewardResultado) -> Void)?
    private let onClose: (() -> Void)?

    private let imagem = UIImageView()
    private let botaoFechar = UIButton(type: .system)
    private let contagem = UILabel()

    private var recompensaProcessada = false

    init(
        resultado: ServeResultado,
        rewarded: Bool,
        skipAfterSegundos: Double,
        minViewSegundos: Int,
        onReward: ((RewardResultado) -> Void)?,
        onClose: (() -> Void)?
    ) {
        self.resultado = resultado
        self.rewarded = rewarded
        self.skipAfterSegundos = skipAfterSegundos
        self.minViewSegundos = minViewSegundos
        self.onReward = onReward
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) não suportado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.95)

        imagem.contentMode = .scaleAspectFit
        imagem.isUserInteractionEnabled = true
        imagem.translatesAutoresizingMaskIntoConstraints = false
        imagem.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(aoTocar)))
        view.addSubview(imagem)

        botaoFechar.setTitle("×", for: .normal)
        botaoFechar.titleLabel?.font = .systemFont(ofSize: 28)
        botaoFechar.tintColor = .white
        botaoFechar.backgroundColor = UIColor(white: 1, alpha: 0.2)
        botaoFechar.layer.cornerRadius = 18
        botaoFechar.isHidden = true
        botaoFechar.translatesAutoresizingMaskIntoConstraints = false
        botaoFechar.addTarget(self, action: #selector(fechar), for: .touchUpInside)
        view.addSubview(botaoFechar)

        contagem.textColor = .white
        contagem.font = .boldSystemFont(ofSize: 15)
        contagem.backgroundColor = UIColor(white: 1, alpha: 0.2)
        contagem.textAlignment = .center
        contagem.layer.cornerRadius = 14
        contagem.clipsToBounds = true
        contagem.isHidden = !rewarded
        contagem.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contagem)

        NSLayoutConstraint.activate([
            imagem.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imagem.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imagem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imagem.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.8),
            botaoFechar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            botaoFechar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            botaoFechar.widthAnchor.constraint(equalToConstant: 36),
            botaoFechar.heightAnchor.constraint(equalToConstant: 36),
            contagem.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            contagem.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contagem.widthAnchor.constraint(equalToConstant: 56),
            contagem.heightAnchor.constraint(equalToConstant: 28),
        ])

        if resultado.anuncio.teste {
            let badge = UILabel()
            badge.text = "Anúncio de teste"
            badge.font = .boldSystemFont(ofSize: 12)
            badge.textColor = .black
            badge.backgroundColor = UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)
            badge.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
                badge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ])
        }

        let asset = resultado.anuncio.assets.first

        Task { [weak self] in
            guard let asset, let bitmap = await Imagens.carregar(asset.url) else { return }
            await MainActor.run { self?.imagem.image = bitmap }
        }

        if rewarded {
            arrancarRewarded()
        } else {
            arrancarInterstitial()
        }
    }

    private func arrancarInterstitial() {
        let cliente = HongaAds.exigirInicializacao()
        let token = resultado.impressionToken

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await cliente.impression(token: token)
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.skipAfterSegundos ?? 5) * 1_000_000_000))
            await MainActor.run { self?.botaoFechar.isHidden = false }
        }
    }

    private func arrancarRewarded() {
        let cliente = HongaAds.exigirInicializacao()

        Task { [weak self] in
            guard let self else { return }

            var restantes = self.minViewSegundos

            while restantes > 0 {
                await MainActor.run { self.contagem.text = "\(restantes)s" }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restantes -= 1
            }

            await MainActor.run {
                self.contagem.isHidden = true
                self.botaoFechar.isHidden = false
            }

            guard !self.recompensaProcessada else { return }
            self.recompensaProcessada = true

            // Fim da visualização: a impressão marca o redeem e o servidor
            // valida o tempo decorrido antes de confirmar a recompensa.
            await cliente.impression(token: self.resultado.impressionToken)
            let confirmacao = await cliente.rewardConfirm(token: self.resultado.impressionToken)

            if confirmacao.recompensa {
                await MainActor.run { self.onReward?(confirmacao) }
            }
        }
    }

    @objc private func aoTocar() {
        let cliente = HongaAds.exigirInicializacao()
        let token = resultado.clickToken

        Task {
            guard let destino = await cliente.click(token: token),
                  let url = URL(string: destino) else { return }

            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }

    @objc private func fechar() {
        dismiss(animated: true) { [onClose] in
            onClose?()
        }
    }
}
#endif
