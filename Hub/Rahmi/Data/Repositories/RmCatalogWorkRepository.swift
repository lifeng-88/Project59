//
//  RmCatalogWorkRepository.swift
//  glam
//
//  Created by Dev on 2026/1/18.
//

import Foundation

/// 模板 Repository 实现
actor RmCatalogWorkRepository: RmCatalogWorkRepositoryProtocol {
    static let shared = RmCatalogWorkRepository()
    
    private init() {}
    
    // MARK: - RmCatalogWorkRepositoryProtocol
    
    func getTemplateTabs(locale: String) async -> Result<[TemplateTab], AppError> {
        let localeKey = locale.isEmpty ? "en" : locale
        // 先尝试从缓存加载
        let cachedTabs = await MainActor.run {
            RmCatalogMaterialDiskCache.shared.getCachedTemplateTabs(locale: localeKey)
        }
        
        if let cachedTabs = cachedTabs {
            // 后台异步刷新缓存
            let loc = localeKey
            Task.detached(priority: .utility) {
                let result = await RmCatalogWireTransport.getTemplateTabs(locale: loc)
                if case .success(let response) = result {
                    await MainActor.run {
                        RmCatalogMaterialDiskCache.shared.setCachedTemplateTabs(response.list, locale: loc)
                    }
                }
            }
            return .success(cachedTabs)
        }
        
        // 缓存不存在，等待网络请求
        let result = await RmCatalogWireTransport.getTemplateTabs(locale: localeKey)
        if case .success(let response) = result {
            await MainActor.run {
                RmCatalogMaterialDiskCache.shared.setCachedTemplateTabs(response.list, locale: localeKey)
            }
        }
        
        return result.map { $0.list }
    }
    
    func getCatalogs(locale: String, forceRefresh: Bool) async -> Result<[Catalog], AppError> {
        let localeKey = locale.isEmpty ? "en" : locale
        // 先尝试从缓存加载（启动时优先使用缓存，提升响应速度）；`forceRefresh` 时跳过缓存直接走 `/v1/catalogs`
        if !forceRefresh {
            let cachedCatalogs = await MainActor.run {
                RmCatalogMaterialDiskCache.shared.getCachedCatalogs(locale: localeKey)
            }

            if let cachedCatalogs = cachedCatalogs {
                print("✅ [RmCatalogWorkRepository] Loaded catalogs from cache (locale: \(localeKey)), count: \(cachedCatalogs.count)")

                // 后台异步刷新缓存（不影响当前使用，下次启动时生效）
                let loc = localeKey
                Task.detached(priority: .utility) {
                    print("🔄 [RmCatalogWorkRepository] Refreshing catalogs cache in background (locale: \(loc))...")
                    let result = await RmCatalogWireTransport.getCatalogs(locale: loc)
                    if case .success(let response) = result {
                        await MainActor.run {
                            RmCatalogMaterialDiskCache.shared.setCachedCatalogs(response.list, locale: loc)
                            print("✅ [RmCatalogWorkRepository] Catalogs cache updated in background, count: \(response.list.count), will take effect on next startup")
                        }
                    } else {
                        print("⚠️ [RmCatalogWorkRepository] Failed to refresh catalogs cache in background, will keep using cached data")
                    }
                }

                // 立即返回缓存数据
                return .success(cachedCatalogs)
            }
        }
        
        // 缓存不存在或 `forceRefresh`，等待网络请求
        print("⏳ [RmCatalogWorkRepository] Loading catalogs from network (locale: \(localeKey), forceRefresh: \(forceRefresh))...")
        let result = await RmCatalogWireTransport.getCatalogs(locale: localeKey)
        if case .success(let response) = result {
            await MainActor.run {
                RmCatalogMaterialDiskCache.shared.setCachedCatalogs(response.list, locale: localeKey)
                print("✅ [RmCatalogWorkRepository] Loaded catalogs from network and saved to cache, count: \(response.list.count)")
            }
        }
        
        return result.map { $0.list }
    }
    
    func getImageTemplates(pageNum: Int32?, pageSize: Int32?) async -> Result<ImageTemplateListResponse, AppError> {
        // 先尝试从缓存加载
        let cachedResponse = await MainActor.run {
            RmCatalogMaterialDiskCache.shared.getCachedImageTemplates(pageNum: pageNum, pageSize: pageSize)
        }
        
        if let cachedResponse = cachedResponse {
            // 后台异步刷新缓存
            Task.detached(priority: .utility) {
                let result = await RmCatalogWireTransport.getImageTemplates(pageNum: pageNum, pageSize: pageSize)
                if case .success(let response) = result {
                    await MainActor.run {
                        RmCatalogMaterialDiskCache.shared.setCachedImageTemplates(response, pageNum: pageNum, pageSize: pageSize)
                    }
                }
            }
            return .success(cachedResponse)
        }
        
        // 缓存不存在，等待网络请求
        let result = await RmCatalogWireTransport.getImageTemplates(pageNum: pageNum, pageSize: pageSize)
        if case .success(let response) = result {
            await MainActor.run {
                RmCatalogMaterialDiskCache.shared.setCachedImageTemplates(response, pageNum: pageNum, pageSize: pageSize)
            }
        }
        
        return result
    }
    
    func getDancingTemplates(pageNum: Int32?, pageSize: Int32?, titleId: Int32) async -> Result<DancingTemplateListResponse, AppError> {
        // 先尝试从缓存加载
        let cachedResponse = await MainActor.run {
            RmCatalogMaterialDiskCache.shared.getCachedDancingTemplates(pageNum: pageNum, pageSize: pageSize, titleId: titleId)
        }
        
        if let cachedResponse = cachedResponse {
            // 后台异步刷新缓存
            let tid = titleId
            let pn = pageNum
            let ps = pageSize
            Task.detached(priority: .utility) {
                let result = await RmCatalogWireTransport.getDancingTemplates(pageNum: pn, pageSize: ps, titleId: tid)
                if case .success(let response) = result {
                    await MainActor.run {
                        RmCatalogMaterialDiskCache.shared.setCachedDancingTemplates(response, pageNum: pn, pageSize: ps, titleId: tid)
                    }
                }
            }
            return .success(cachedResponse)
        }
        
        // 缓存不存在，等待网络请求
        let result = await RmCatalogWireTransport.getDancingTemplates(pageNum: pageNum, pageSize: pageSize, titleId: titleId)
        if case .success(let response) = result {
            await MainActor.run {
                RmCatalogMaterialDiskCache.shared.setCachedDancingTemplates(response, pageNum: pageNum, pageSize: pageSize, titleId: titleId)
            }
        }
        
        return result
    }
    
    func getVideoTemplates(pageNum: Int32?, pageSize: Int32?, catalogId: Int32?, titleId: Int32) async -> Result<VideoTemplateListResponse, AppError> {
        // 先尝试从缓存加载
        let cachedResponse = await MainActor.run {
            RmCatalogMaterialDiskCache.shared.getCachedVideoTemplates(catalogId: catalogId, pageNum: pageNum, pageSize: pageSize, titleId: titleId)
        }
        
        if let cachedResponse = cachedResponse {
            // 后台异步刷新缓存
            let tid = titleId
            let pn = pageNum
            let ps = pageSize
            let cid = catalogId
            Task.detached(priority: .utility) {
                let result = await RmCatalogWireTransport.getVideoTemplates(pageNum: pn, pageSize: ps, catalogId: cid, titleId: tid)
                if case .success(let response) = result {
                    await MainActor.run {
                        RmCatalogMaterialDiskCache.shared.setCachedVideoTemplates(response, catalogId: cid, pageNum: pn, pageSize: ps, titleId: tid)
                    }
                }
            }
            return .success(cachedResponse)
        }
        
        // 缓存不存在，等待网络请求
        let result = await RmCatalogWireTransport.getVideoTemplates(pageNum: pageNum, pageSize: pageSize, catalogId: catalogId, titleId: titleId)
        if case .success(let response) = result {
            await MainActor.run {
                RmCatalogMaterialDiskCache.shared.setCachedVideoTemplates(response, catalogId: catalogId, pageNum: pageNum, pageSize: pageSize, titleId: titleId)
            }
        }
        
        return result
    }
    
    func getImageTemplateDetail(tid: String) async -> Result<ImageTemplate, AppError> {
        return await RmCatalogWireTransport.getImageTemplateDetail(tid: tid)
    }
    
    func getDancingTemplateDetail(tid: String) async -> Result<DancingTemplate, AppError> {
        return await RmCatalogWireTransport.getDancingTemplateDetail(tid: tid)
    }
    
    func getVideoTemplateDetail(tid: String) async -> Result<VideoTemplate, AppError> {
        return await RmCatalogWireTransport.getVideoTemplateDetail(tid: tid)
    }
}
