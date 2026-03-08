import Foundation
import SwiftData

enum ProductImageKind: String, Codable {
    case symbol
    case asset
    case file
}

@Model
final class StoreProduct {
    var id: UUID
    var name: String
    var desc: String
    var pointsCost: Int
    var category: String?
    var imageKind: ProductImageKind
    var imageRef: String
    var isRedeemed: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        desc: String,
        pointsCost: Int,
        category: String? = nil,
        imageKind: ProductImageKind = .symbol,
        imageRef: String = "gift.fill",
        isRedeemed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.desc = desc
        self.pointsCost = pointsCost
        self.category = category
        self.imageKind = imageKind
        self.imageRef = imageRef
        self.isRedeemed = isRedeemed
        self.createdAt = createdAt
    }
}

