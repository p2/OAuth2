//
//  OAuth2ClientConfig.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 16/11/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
//

import Foundation


public class OAuth2ClientConfig {
	
	/// The client id.
	public final var clientId: String
	
	/// The client secret, usually only needed for code grant.
	public final var clientSecret: String?
	
	/// The URL to authorize against.
	public final let authorizeURL: NSURL
	
	/// The URL string where we can exchange a code for a token.
	public let tokenURL: NSURL?
	
	/// The scope currently in use.
	public var scope: String?
	
	/// The redirect URL string currently in use.
	public var redirect: String?
	
	/// The receiver's access token.
	public var accessToken: String?
	
	/// The access token's expiry date.
	public var accessTokenExpiry: NSDate?
	
	/// If set to true (the default), uses a keychain-supplied access token even if no "expires_in" parameter was supplied.
	public var accessTokenAssumeUnexpired = true
	
	/// The receiver's long-time refresh token.
	public var refreshToken: String?
	
	
	public init(settings: OAuth2JSON) {
		clientId = settings["client_id"] as? String ?? ""
		clientSecret = settings["client_secret"] as? String
		
		// authorize URL
		var aURL: NSURL?
		if let auth = settings["authorize_uri"] as? String {
			aURL = NSURL(string: auth)
		}
		authorizeURL = aURL ?? NSURL(string: "http://localhost")!
		
		// token URL
		if let token = settings["token_uri"] as? String {
			tokenURL = NSURL(string: token)
		}
		else {
			tokenURL = nil
		}
		
		// client authentication options
		scope = settings["scope"] as? String
		if let redirs = settings["redirect_uris"] as? [String] {
			redirect = redirs.first
		}
		
		// access token options
		if let assume = settings["token_assume_unexpired"] as? Bool {
			accessTokenAssumeUnexpired = assume
		}
	}
	
	
	func updateFromResponse(json: OAuth2JSON) {
		if let access = json["access_token"] as? String {
			accessToken = access
		}
		accessTokenExpiry = nil
		if let expires = json["expires_in"] as? NSTimeInterval {
			accessTokenExpiry = NSDate(timeIntervalSinceNow: expires)
		}
		else if let expires = json["expires_in"] as? String {			// when parsing implicit grant from URL fragment
			accessTokenExpiry = NSDate(timeIntervalSinceNow: Double(expires) ?? 0.0)
		}
		if let refresh = json["refresh_token"] as? String {
			refreshToken = refresh
		}
	}
	
	func storableItems() -> [String: NSCoding]? {
		guard let access = accessToken where !access.isEmpty else { return nil }
		
		var items: [String: NSCoding] = ["accessToken": access]
		if let date = accessTokenExpiry where date == date.laterDate(NSDate()) {
			items["accessTokenDate"] = date
		}
		if let refresh = refreshToken where !refresh.isEmpty {
			items["refreshToken"] = refresh
		}
		return items
	}
	
	public func forgetTokens() {
		accessToken = nil
		accessTokenExpiry = nil
		refreshToken = nil
	}
}

