// NetProxy.swift - Shared proxy configuration for HTTP downloads + FTP (F-212/F-330).

import Foundation

public enum ProxyKind: String, Sendable, CaseIterable, Equatable {
    case http    // HTTP CONNECT proxy (used by URLSession for downloads)
    case socks5  // SOCKS5 proxy (URLSession + our FTP transport)
}

public struct ProxyConfig: Sendable, Equatable {
    public var kind: ProxyKind
    public var host: String
    public var port: Int
    public var username: String?
    public var password: String?

    public init(kind: ProxyKind, host: String, port: Int, username: String? = nil, password: String? = nil) {
        self.kind = kind
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }

    /// A `URLSessionConfiguration.connectionProxyDictionary` for this proxy, so
    /// URLSession routes HTTP/HTTPS through it (F-330).
    public var urlSessionProxyDictionary: [AnyHashable: Any] {
        var dict: [AnyHashable: Any] = [:]
        switch kind {
        case .http:
            dict[kCFNetworkProxiesHTTPEnable as String] = 1
            dict[kCFNetworkProxiesHTTPProxy as String] = host
            dict[kCFNetworkProxiesHTTPPort as String] = port
            dict["HTTPSEnable"] = 1
            dict["HTTPSProxy"] = host
            dict["HTTPSPort"] = port
        case .socks5:
            dict[kCFNetworkProxiesSOCKSEnable as String] = 1
            dict[kCFNetworkProxiesSOCKSProxy as String] = host
            dict[kCFNetworkProxiesSOCKSPort as String] = port
        }
        if let username { dict[kCFProxyUsernameKey as String] = username }
        if let password { dict[kCFProxyPasswordKey as String] = password }
        return dict
    }
}
