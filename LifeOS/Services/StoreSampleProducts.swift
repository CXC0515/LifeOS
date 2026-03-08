import Foundation

struct StoreSampleProduct {
    let name: String
    let desc: String
    let cost: Int
    let category: String
    let icon: String
}

enum StoreSampleProducts {
    static let isEnabled: Bool = true
    
    static let all: [StoreSampleProduct] = [
        StoreSampleProduct(
            name: "番茄工作法计时器",
            desc: "提升专注力的番茄钟工具",
            cost: 500,
            category: "工具",
            icon: "timer"
        ),
        StoreSampleProduct(
            name: "主题皮肤礼包",
            desc: "解锁更多主题与配色，让界面更好看",
            cost: 800,
            category: "外观",
            icon: "paintpalette.fill"
        ),
        StoreSampleProduct(
            name: "会员月卡",
            desc: "解锁高级功能一个月，奖励自己一段高效时间",
            cost: 2000,
            category: "会员",
            icon: "crown.fill"
        ),
        StoreSampleProduct(
            name: "学习资料包",
            desc: "精选学习资料合集，为成长加一点燃料",
            cost: 1200,
            category: "资料",
            icon: "book.fill"
        ),
        StoreSampleProduct(
            name: "专注白噪音",
            desc: "高质量白噪音合集，沉浸式进入心流",
            cost: 300,
            category: "音频",
            icon: "waveform"
        ),
        StoreSampleProduct(
            name: "测试商品",
            desc: "用于测试兑换流程的 1 积分商品",
            cost: 1,
            category: "测试",
            icon: "testtube.2"
        )
    ]
}

