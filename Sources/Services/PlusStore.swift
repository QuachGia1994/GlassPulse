import Foundation
import Observation
import StoreKit

enum PlusPlan: String, CaseIterable, Sendable {
    case weekly
    case monthly

    var productID: String {
        switch self {
        case .weekly: "com.quachgia.glasspulse.plus.weekly"
        case .monthly: "com.quachgia.glasspulse.plus.monthly"
        }
    }

    var sortOrder: Int {
        switch self {
        case .weekly: 0
        case .monthly: 1
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else {
            return nil
        }
        self = plan
    }
}

enum PlusStoreError: Error, Equatable, LocalizedError {
    case productUnavailable
    case failedVerification
    case storeFailure(String)

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "Gói Plus chưa tải được từ App Store."
        case .failedVerification:
            "Không thể xác minh giao dịch App Store."
        case .storeFailure(let reason):
            "App Store gặp lỗi: \(reason)"
        }
    }
}

enum SubscriptionEntitlementPolicy {
    static func isActive(
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date
    ) -> Bool {
        guard revocationDate == nil else { return false }
        return expirationDate.map { $0 > now } ?? true
    }
}

@MainActor
@Observable
final class PlusStore {
    nonisolated static let productIDs = Set(PlusPlan.allCases.map(\.productID))
    nonisolated static let subscriptionGroupID = "5A15D10B-9197-4D8A-A026-77A5ECCE01A1"

    private var products: [Product] = []
    private(set) var hasActivePlusSubscription = false
    private(set) var isBusy = false
    private(set) var notice: String?
    private(set) var errorMessage: String?

    @ObservationIgnored private var transactionTask: Task<Void, Never>?
    @ObservationIgnored private let testingEntitlementEnabled: Bool

    init(testingEntitlementEnabled: Bool = false) {
#if DEBUG
        self.testingEntitlementEnabled = testingEntitlementEnabled
        hasActivePlusSubscription = testingEntitlementEnabled
#else
        self.testingEntitlementEnabled = false
#endif
    }

    var access: FeatureAccess {
        FeatureAccess.current(
            hasActivePlusSubscription: hasActivePlusSubscription
        )
    }

    var isPlusUnlocked: Bool {
        access.hasPlus
    }

    var isBetaFullAccess: Bool {
        access.isBetaFullAccess
    }

    func start() async {
        guard !testingEntitlementEnabled else {
            products = []
            notice = "UI test entitlement đang bật."
            errorMessage = nil
            return
        }
        guard !isBetaFullAccess else {
            products = []
            notice = "Beta Full Access đang bật."
            errorMessage = nil
            return
        }
        startTransactionListener()
        guard products.isEmpty else {
            await refreshEntitlements()
            return
        }
        await loadProducts()
    }

    func loadProducts() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { productSortOrder($0) < productSortOrder($1) }
            guard !products.isEmpty else { throw PlusStoreError.productUnavailable }
            try await updateEntitlementState()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            try await updateEntitlementState()
            notice = isPlusUnlocked ? "Đã khôi phục Glass Pulse Plus." : "Không tìm thấy gói Plus đang hoạt động."
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func startTransactionListener() {
        guard transactionTask == nil else { return }
        transactionTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.processTransactionUpdate(result)
            }
        }
    }

    private func processTransactionUpdate(
        _ result: VerificationResult<Transaction>
    ) async {
        do {
            let transaction = try verified(result)
            await transaction.finish()
            try await updateEntitlementState()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func refreshEntitlements() async {
        do {
            try await updateEntitlementState()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func updateEntitlementState() async throws {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            let transaction = try verified(result)
            guard Self.productIDs.contains(transaction.productID) else { continue }
            guard SubscriptionEntitlementPolicy.isActive(
                revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate,
                now: .now
            ) else { continue }
            unlocked = true
            break
        }
        hasActivePlusSubscription = unlocked
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PlusStoreError.failedVerification
        }
    }

    private func productSortOrder(_ product: Product) -> Int {
        PlusPlan(productID: product.id)?.sortOrder ?? .max
    }

    private func handle(_ error: Error) {
        if let plusError = error as? PlusStoreError {
            errorMessage = plusError.localizedDescription
        } else {
            errorMessage = PlusStoreError.storeFailure(error.localizedDescription).localizedDescription
        }
        notice = nil
    }
}
