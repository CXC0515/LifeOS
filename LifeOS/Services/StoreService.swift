import Foundation
import SwiftData

@MainActor
final class StoreService {
    static let shared = StoreService()
    
    private init() {}
    
    func bootstrapIfNeeded(context: ModelContext) {
        guard StoreSampleProducts.isEnabled else { return }
        
        let descriptor = FetchDescriptor<StoreProduct>()
        let existingProducts = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingProducts.map { $0.name })
        
        let samplesToInsert = StoreSampleProducts.all.filter { !existingNames.contains($0.name) }
        guard !samplesToInsert.isEmpty else { return }
        
        for item in samplesToInsert {
            addProduct(
                name: item.name,
                desc: item.desc,
                pointsCost: item.cost,
                category: item.category,
                imageKind: .symbol,
                imageRef: item.icon,
                context: context
            )
        }
    }
    
    func fetchProducts(context: ModelContext) -> [StoreProduct] {
        let descriptor = FetchDescriptor<StoreProduct>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let result = try? context.fetch(descriptor) {
            return result
        }
        return []
    }
    
    func addProduct(
        name: String,
        desc: String,
        pointsCost: Int,
        category: String?,
        imageKind: ProductImageKind,
        imageRef: String,
        context: ModelContext
    ) {
        let product = StoreProduct(
            name: name,
            desc: desc,
            pointsCost: pointsCost,
            category: category,
            imageKind: imageKind,
            imageRef: imageRef
        )
        context.insert(product)
    }
    
    func updateProduct(_ product: StoreProduct, context: ModelContext) {
        context.insert(product)
    }
    
    func deleteProduct(_ product: StoreProduct, context: ModelContext) {
        context.delete(product)
    }
    
    func redeem(product: StoreProduct, context: ModelContext) -> Bool {
        let success = TaskService.shared.purchaseItem(cost: product.pointsCost, context: context)
        if success {
            product.isRedeemed = true
        }
        return success
    }
}
