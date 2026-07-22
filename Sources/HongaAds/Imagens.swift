#if canImport(UIKit)
import UIKit

enum Imagens {

    static func carregar(_ url: String) async -> UIImage? {
        guard let endereco = URL(string: url) else {
            return nil
        }

        do {
            let (dados, _) = try await URLSession.shared.data(from: endereco)

            return UIImage(data: dados)
        } catch {
            return nil
        }
    }
}
#endif
