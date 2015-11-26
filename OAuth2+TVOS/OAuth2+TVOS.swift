extension OAuth2
{
	
	public final func openAuthorizeURLInBrowser(params: [String: String]? = nil) -> Bool {
		fatalError("Not yet implemented")
	}
	
	public func authorizeEmbeddedWith(config: OAuth2AuthConfig, params: [String: String]? = nil, autoDismiss: Bool = true) -> Bool {
        fatalError("no supported on TVOS!")
	}
	
	public func authorizeEmbeddedFrom(controller: UIViewController, params: [String: String]?) -> AnyObject {
		fatalError("no supported on TVOS!")
	}
}

