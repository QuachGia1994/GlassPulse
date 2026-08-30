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
                        subscriptionStore
                        restoreButton
                        legalNote
                    }
                }
                .padding()
            }
            .navigationTitle("Glass Pulse Plus")
            .navigationBarTitleDisplayMode(.inline)
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
        return store.isPlusUnlocked ? "Plus đang hoạt động" : "Mở thêm mode"
    }

    private var heroSubtitle: String {
        if store.isBetaFullAccess {
            return "Toàn bộ mode và theme đã mở để kiểm thử bản unsigned."
        }
        return "Mở Rush 60, Precision Pulse, Wave Survival và theme Prism Plus."
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("Rush 60, Precision Pulse, Wave Survival", systemImage: "square.grid.2x2.fill")
            benefit("Theme Prism Plus", systemImage: "paintpalette.fill")
            benefit("Classic và Daily vẫn miễn phí", systemImage: "checkmark.circle.fill")
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

    private var subscriptionStore: some View {
        VStack(spacing: 10) {
            SubscriptionStoreView(productIDs: PlusStore.productIDs.sorted())
                .frame(minHeight: 260)
            if let notice = store.notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let error = store.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var restoreButton: some View {
        Button("Khôi phục giao dịch") {
            Task { await store.restorePurchases() }
        }
        .buttonStyle(.bordered)
        .disabled(store.isBusy)
    }

    private var legalNote: some View {
        Text("Gói tự động gia hạn theo kỳ đã chọn. Quản lý hoặc hủy trong cài đặt App Store.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    private func benefit(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
    }
}
