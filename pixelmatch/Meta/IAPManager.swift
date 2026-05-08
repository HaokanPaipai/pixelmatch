import StoreKit

// MARK: - Product IDs

enum IAPProduct: String, CaseIterable {
    // Coin packs
    case coins500    = "com.pixelmatch.coins.500"
    case coins1500   = "com.pixelmatch.coins.1500"
    case coins5000   = "com.pixelmatch.coins.5000"

    // Diamond packs
    case diamonds20  = "com.pixelmatch.diamonds.20"
    case diamonds80  = "com.pixelmatch.diamonds.80"
    case diamonds300 = "com.pixelmatch.diamonds.300"

    // Booster packs
    case starterPack = "com.pixelmatch.pack.starter"
    case megaPack    = "com.pixelmatch.pack.mega"

    // No-ads (remove ad banner permanently)
    case noAds       = "com.pixelmatch.noads"

    var displayName: String {
        switch self {
        case .coins500:    return "500 Coins"
        case .coins1500:   return "1,500 Coins"
        case .coins5000:   return "5,000 Coins"
        case .diamonds20:  return "20 Diamonds"
        case .diamonds80:  return "80 Diamonds"
        case .diamonds300: return "300 Diamonds"
        case .starterPack: return "Starter Pack"
        case .megaPack:    return "Mega Pack"
        case .noAds:       return "Remove Ads"
        }
    }

    var localPrice: String {
        switch self {
        case .coins500:    return "$0.99"
        case .coins1500:   return "$1.99"
        case .coins5000:   return "$4.99"
        case .diamonds20:  return "$0.99"
        case .diamonds80:  return "$2.99"
        case .diamonds300: return "$9.99"
        case .starterPack: return "$1.99"
        case .megaPack:    return "$6.99"
        case .noAds:       return "$2.99"
        }
    }

    func apply() {
        switch self {
        case .coins500:    PlayerData.shared.addCoins(500)
        case .coins1500:   PlayerData.shared.addCoins(1500)
        case .coins5000:   PlayerData.shared.addCoins(5000)
        case .diamonds20:  PlayerData.shared.addDiamonds(20)
        case .diamonds80:  PlayerData.shared.addDiamonds(80)
        case .diamonds300: PlayerData.shared.addDiamonds(300)
        case .starterPack:
            PlayerData.shared.addCoins(300)
            PlayerData.shared.addDiamonds(10)
            PlayerData.shared.hammerCount += 3
            PlayerData.shared.colorBombCount += 1
        case .megaPack:
            PlayerData.shared.addCoins(1000)
            PlayerData.shared.addDiamonds(50)
            PlayerData.shared.hammerCount += 10
            PlayerData.shared.shuffleCount += 5
            PlayerData.shared.colorBombCount += 3
            PlayerData.shared.extraMovesCount += 5
        case .noAds:
            PlayerData.shared.setNoAds()
        }
    }
}

// MARK: - IAP Manager

@MainActor
final class IAPManager: NSObject {
    static let shared = IAPManager()
    private override init() {
        super.init()
    }

    private var products: [Product] = []
    private var purchaseCompletion: ((Bool, String?) -> Void)?

    func loadProducts() async {
        do {
            let ids = Set(IAPProduct.allCases.map { $0.rawValue })
            products = try await Product.products(for: ids)
        } catch {
            print("IAP loadProducts error: \(error)")
        }
    }

    func purchase(_ productID: IAPProduct, completion: @escaping (Bool, String?) -> Void) {
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            // Product not loaded — apply locally using default price (dev mode)
            productID.apply()
            completion(true, nil)
            return
        }

        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified:
                        productID.apply()
                        completion(true, nil)
                    case .unverified:
                        completion(false, "Purchase could not be verified.")
                    }
                case .userCancelled:
                    completion(false, nil)
                case .pending:
                    completion(false, "Purchase is pending approval.")
                @unknown default:
                    completion(false, "Unknown purchase result.")
                }
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }

    func restorePurchases(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await AppStore.sync()
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result,
                       let product = IAPProduct(rawValue: transaction.productID) {
                        product.apply()
                    }
                }
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func localizedPrice(for productID: IAPProduct) -> String {
        products.first(where: { $0.id == productID.rawValue })?.displayPrice ?? productID.localPrice
    }
}
