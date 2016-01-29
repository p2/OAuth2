import UIKit

extension OAuth2 {
	
    // no webview or webbrowser available on tvOS
    
	public final func openAuthorizeURLInBrowser(params: [String: String]? = nil) -> Bool {
		fatalError("Not implemented")
	}
	
	public func authorizeEmbeddedWith(config: OAuth2AuthConfig, params: [String: String]? = nil, autoDismiss: Bool = true) -> Bool {
        fatalError("Not implemented")
	}
	
	public func authorizeEmbeddedFrom(controller: UIViewController, params: [String: String]?) -> AnyObject {
		fatalError("Not implemented")
	}
}

