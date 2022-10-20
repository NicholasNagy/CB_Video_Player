import GCDWebServer
import PINCache
import Foundation

@objc public class CacheManager : NSObject {
    var server: HLSCachingReverseProxyServer
    
    @objc override public init() {
        GCDWebServer.setLogLevel(4)
        let webServer = GCDWebServer()
        let cache = PINCache.shared
        
        // Warn devs when we reach the memory limit.
        cache.memoryCache.didReceiveMemoryWarningBlock = { (theCache: PINCaching) in
            print("RECEIVED MEMORY WARNING!!!!")
            print("DELETING ALL OBJECTS IN MEMORY CACHE!")
            print("BEWARE OF POTENTIAL PERFORMANCE DEGRADATION!")
        }
        
        // set disk cache to 3GB.
        cache.diskCache.byteLimit = 1024 * 1024 * 1024 * 3;
        let urlSession = URLSession.shared
        self.server = HLSCachingReverseProxyServer(webServer: webServer, urlSession: urlSession, cache: cache)
        server.start(port: 8080)
        print("Cache Server Initialized!")

        super.init()
    }
    
    @objc public func getCacheUrl(_ url: NSString) -> NSURL {
        return self.server.reverseProxyURL(from: URL.init(string: url as String)!)! as NSURL
    }

    @objc public func preCache(_ url: NSString) {
        let preCacheUrl = URL.init(string: url as String)!
        let proxyUrl = server.reverseProxyURL(from: preCacheUrl)!
        
        self.handlePreCache(url: proxyUrl, isM3u8: url.hasSuffix(".m3u8"))
        
    }
    
    private func handlePreCache(url: URL, isM3u8: Bool) {
        if (isM3u8) {
            getRequest(url: url, handler: self.handleM3u8)
        } else {
            // handler does nothing when it is a .ts file
            getRequest(url: url, handler: {data in })
        }
    }
    
    private func getRequest(url: URL, handler: @escaping (Data) -> Void) {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data, let response = response else {
                print("Something failed")
                return
            }
            handler(data)
        }
        task.resume()
    }
    
    // TODO: Look at better way to handle this. We are assuming the first .m3u8 is the highest resolution.
    private func handleM3u8(data: Data) {
        let k = String(data: data, encoding: .utf8)!
            .components(separatedBy: .newlines)
            .first { line in self.isURL(line: line) }!
        self.handlePreCache(url: URL.init(string: k)!, isM3u8: k.hasSuffix(".m3u8"))
    }
    

    private func isURL(line: String) -> Bool {
        guard !line.isEmpty else { return false }
        
        // TODO: this might break in the future
        return line.hasPrefix("http")
    }
    
    
}
