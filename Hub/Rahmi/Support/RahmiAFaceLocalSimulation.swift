//
//  RahmiAFaceLocalSimulation.swift
//  Rahmi
//
//  DEBUG：A 面离线/接口失败时的本地种子数据（文案走 String Catalog，与 `AppLanguageStore` 一致）。
//

#if DEBUG

import Foundation

enum RahmiAFaceLocalSimulation {
    /// 与 `IAP.storekit` 商品 ID 对齐，供直链 IAP 联调
    private static let appleProductIDs: [String] = [
        "com.rahmi.app.coins_40",
        "com.rahmi.app.coins_80",
        "com.rahmi.app.coins_200",
        "com.rahmi.app.coins_400"
    ]

    private static let previewImageURLs: [String] = [
        "https://lh3.googleusercontent.com/aida-public/AB6AXuCTmfxFmNZ8N_-A0kKPK5QBGEDKYT-cFiY_3a9cSHtanseBUNpDtWHBu9YcL7tD09AcGOHAps_dcqPFppFTHmdUf4yzBqbLyKQ-_5V0nWBhLuDcKUxwzpV403NrkVV5FKxtiHLcPPbCA4t2KeM-tpqLxckQqI5n-Qp42Kd0a0M3iBtq4bKzGjbuv6IcvZTcg5OAreWsaL4UJ4h4qwGXxkXCGLOsp8UlJDUFuhSchrFrZdUteJjxSLVVw2ySZRsKBHF6deBQU-JS-JkN",
        "https://lh3.googleusercontent.com/aida-public/AB6AXuBXKz2V6Ea0kW-GqCpETP3ghfIRqxMkr5zTGdNljWy_vKvd578ah3e3H2JoX8dM0wyzVolGTOegz3pxJWNXyvQ6fGCd9uGjn554qeqE7ZlIojv3pcM0w5sWMQbXBYliGCH9i0hI0Yf79QnhgCcXdQBiywMwvXpvG9qSuMEQWghiazEBkrgrBm1naWZV6PeA6-9-6440QNG2R5dQ_rBE7IQ2ZF-hDFB4f64gyr0BenQMjMEgcw9qf_C1H4Jkz4x8PnlWEXf_NhuuSUJZ",
        "https://lh3.googleusercontent.com/aida-public/AB6AXuDuX54Gg4GBz0LqYteaMvDSHMlQboJPXqhg1blAM2DjkgzgmZ2TORz7OLTbFb6aQ8F15MD0NOqd83hw7SPHr9DwtLYfaHKF7sstjz6O0CODNtjnl4qdiAUg6XNCkHCuYK8rVbzMBwWj61x2TBvZB_b5xw4WtfBXcg0lHVdW0aRlUfPHgfelnADI7qkBUVMckoEou0ybTgCuQ61RICHXJViH16mXapX_tu6BSEUgsHDckdeGgnxOP6rCN8MQMwgS8R2z9v0LzDfvV6t3",
        "https://lh3.googleusercontent.com/aida-public/AB6AXuBt6Pl6QmeNu74iUX9PhJPAKCfmGzlCrocUnvLSfJQufbdlGwNWMlJfH4GTf0qFrFqUmjCOqlaV5nN7x_b1XB7_tmckmY38ao6b5TY7MJ4si2r_pIsa8G6rwvgGDecKjZKYt4dhUK1fCliOeabu4aacfTUj8rIL0ZliDqYYOJtC2AInvmQpu7zSg_wWts50UoSWzliUioLGtsmaeaqpHGatFcVv6zIIbJlxjBOw3ixmLhoYRTGInA72MGjPe-iY5MfLxqbS_XY5mlJl"
    ]

    static func videoCatalogs() -> [Catalog] {
        [
            Catalog(id: 1, name: AppLanguageStore.localized("home.catalog.preset.hot")),
            Catalog(id: 2, name: AppLanguageStore.localized("home.catalog.preset.new")),
            Catalog(id: 3, name: AppLanguageStore.localized("home.catalog.preset.funny"))
        ]
    }

    static func imageTemplates() -> [ImageTemplate] {
        let title = AppLanguageStore.localized("debug.local.template_title")
        return previewImageURLs.enumerated().map { index, before in
            let after = previewImageURLs[(index + 1) % previewImageURLs.count]
            return ImageTemplate(
                id: "rahmi-debug-local-t1-\(index)",
                title: title,
                beforePics: [before, after],
                beforePicsType: [0, 0],
                afterPic: after,
                changeBackground: false,
                transAnimation: "2400",
                consumedGold: "1",
                isNew: index == 1 ? TemplateListTruthyFlag(isOn: true) : nil,
                isHot: index == 0 ? TemplateListTruthyFlag(isOn: true) : nil,
                hasAudio: nil,
                discountEndsAt: nil,
                originalConsumedGold: nil
            )
        }
    }

    static func domainPackages() -> [Package] {
        let specs: [(id: Int32, nameKey: String, regular: Int64, discount: Int64, gold: Int32, bonus: Int32)] = [
            (101, "debug.local.package.starter", 1299, 999, 40, 10),
            (102, "debug.local.package.popular", 1999, 999, 80, 40),
            (103, "debug.local.package.value", 2499, 1999, 80, 40),
            (104, "debug.local.package.plus", 4499, 3499, 200, 50)
        ]
        return specs.enumerated().map { index, spec in
            let productId = appleProductIDs.indices.contains(index) ? appleProductIDs[index] : nil
            return Package(
                id: spec.id,
                name: AppLanguageStore.localized(spec.nameKey),
                regularPrice: spec.regular,
                discountPrice: spec.discount,
                gold: spec.gold,
                bonus: spec.bonus,
                appleProductId: productId
            )
        }
    }
}

#endif
