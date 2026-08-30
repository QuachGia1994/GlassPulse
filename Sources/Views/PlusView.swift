import StoreKit
import SwiftUI

@MainActor
struct PlusView: View {
    @Environment(PlusStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    benefits
                    if store.isBetaFullAccess {
                        betaAccessStatus
                    } else {
                        purchaseOptions
                        restoreButton
                        legalNote
                    }
                }
                .padding()
            }
            .navigationTitle("Glass Pulse Plus")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .task { await store.start() }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: store.isPlusUnlocked ? "checkmark.seal.fill" : "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(.cyan)
            Text(heroTitle)
                .font(.title2.weight(.semibold))
            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var heroTitle: String {
        if store.isBetaFullAccess { return "Beta Full Access" }
        return store.isPlusUnlocked ? "Plus đang hoạt động" : "Mở nhịp chơi riêng"
    }

    private var heroSubtitle: String {
        if store.isBetaFullAccess {
            return "Toàn bộ theme và pulse đã mở để kiểm thử bản unsigned."
        }
        return "Tắt quảng cáo, mở theme Prism Plus và nhận mode mới sớm hơn."
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("Không có quảng cáo", systemImage: "rectangle.slash")
            benefit("Theme và pulse độc quyền", systemImage: "paintpalette.fill")
            benefit("Truy cập sớm mode mới", systemImage: "clock.badge.checkmark")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var betaAccessStatus: some View {
        Label(
            "Không cần mua hoặc khôi phục trong bản Beta này.",
            systemImage: "checkmark.shield.fill"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.cyan)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var purchaseOptions: some View {
        if store.products.isEmpty {
            if store.isBusy {
                ProgressView("Đang tải gói Plus")
            } else {
                Text(store.errorMessage ?? "Gói Plus chưa sẵn sàng.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tải lại") {
                    Task { await store.loadProducts() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    productButton(product)
                }
            }
        }

        if let notice = store.notice {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }

        if let error = store.errorMessage, !store.products.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Text(PlusPlan(productID: product.id)?.title ?? product.displayName)
                Spacer()
                Text(product.displayPrice)
                    .monospacedDigit()
            }
            .font(.headline)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
        .disabled(store.isBusy || store.isPlusUnlocked)
    }

    private var restoreButton: some View {
        Button("Khôi phục giao dịch") {
            Task { await store.restorePurchases() }
        }
        .buttonStyle(.bordered)
        .disabled(store.isBusy)
    }

    private var legalNote: some View {
        Text("Gói tự động gia hạn theo kỳ đã chọn. Bạn có thể quản lý hoặc hủy trong cài đặt App Store.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    private func benefit(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
    }
}
