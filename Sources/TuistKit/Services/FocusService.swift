import Foundation
import RxBlocking
import RxSwift
import TSCBasic
import TuistCache
import TuistCore
import TuistGenerator
import TuistGraph
import TuistLoader
import TuistPlugin
import TuistSupport

final class FocusService {
    private let opener: Opening
    private let generatorFactory: GeneratorFactorying
    private let configLoader: ConfigLoading
    private let manifestLoader: ManifestLoading
    private let pluginService: PluginServicing
    private let manifestGraphLoader: ManifestGraphLoading

    init(
        configLoader: ConfigLoading,
        manifestLoader: ManifestLoading = CachedManifestLoader(),
        opener: Opening = Opener(),
        generatorFactory: GeneratorFactorying = GeneratorFactory(),
        pluginService: PluginServicing = PluginService(),
        manifestGraphLoader: ManifestGraphLoading
    ) {
        self.configLoader = configLoader
        self.manifestLoader = manifestLoader
        self.opener = opener
        self.generatorFactory = generatorFactory
        self.pluginService = pluginService
        self.manifestGraphLoader = manifestGraphLoader
    }
    
    convenience init() {
        let manifestLoader = CachedManifestLoader()
        self.init(
            configLoader: ConfigLoader(manifestLoader: manifestLoader),
            manifestLoader: manifestLoader,
            manifestGraphLoader: ManifestGraphLoader(manifestLoader: manifestLoader)
        )
    }

    func run(path: String?, sources: Set<String>, noOpen: Bool, xcframeworks: Bool, profile: String?, ignoreCache: Bool) throws {
        let path = self.path(path)
        let config = try configLoader.loadConfig(path: path)
        let cacheProfile = try CacheProfileResolver().resolveCacheProfile(named: profile, from: config)
        let generator = generatorFactory.focus(
            config: config,
            sources: sources.isEmpty ? try projectTargets(at: path, config: config) : sources,
            xcframeworks: xcframeworks,
            cacheProfile: cacheProfile,
            ignoreCache: ignoreCache
        )
        let workspacePath = try generator.generate(path: path, projectOnly: false)
        if !noOpen {
            try opener.open(path: workspacePath)
        }
    }

    // MARK: - Helpers

    private func path(_ path: String?) -> AbsolutePath {
        if let path = path {
            return AbsolutePath(path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }

    private func projectTargets(at path: AbsolutePath, config: Config) throws -> Set<String> {
        let plugins = try pluginService.loadPlugins(using: config)
        try manifestLoader.register(plugins: plugins)
        let graph = try manifestGraphLoader.loadGraph(at: path)
        let graphTraverser = GraphTraverser(graph: graph)
        return Set(graphTraverser.projects[path]?.targets.map(\.name) ?? [])
    }
}
