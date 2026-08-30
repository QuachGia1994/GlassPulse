import Foundation
import Observation
import StoreKit

enum PlusPlan: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly

    var id: String { productID }

    var productID: String {
        switch self {
        case .weekly: "com.quachgia.glasspulse.plus.weekly"
        case .monthly: "com.quachgia.glasspulse.plus.monthly"
        }
    }

    var title: String {
        switch self {
        case .weekly: "Plus tuần"
        case .monthly: "Plus tháng"
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
    case unknownPurchaseState
    case storeFailure(String)

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "Gói Plus chưa tải được từ App Store."
        case .failedVerification:
            "Không thể xác minh giao dịch App Store."
        case .unknownPurchaseState:
            "App Store trả về trạng thái giao dịch chưa được hỗ trợ."
        case .storeFailure(let reason):
            "App Store gặp lỗi: \(reason)"
        }
    }
}

@MainActor
@Observable
final class PlusStore {
    nonisolated static let productIDs = Set(PlusPlan.allCases.map(\.productID))

    private(set) var products: [Product] = []
    private(set) var hasActivePlusSubscription = false
    private(set) var isBusy = false
    private(set) var notice: String?
    private(set) var errorMessage: String?

    @ObservationIgnored private var transactionTask: Task<Void, Never>?

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

    func purchase(_ product: Product) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()
            try await handlePurchaseResult(result)
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

    private func handlePurchaseResult(
        _ result: Product.PurchaseResult
    ) async throws {
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            try await updateEntitlementState()
            notice = "Glass Pulse Plus đã được kích hoạt."
        case .pending:
            notice = "Giao dịch đang chờ App Store xác nhận."
        case .userCancelled:
            notice = nil
        @unknown default:
            throw PlusStoreError.unknownPurchaseState
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
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate.map({ $0 > .now }) ?? true else { continue }
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
