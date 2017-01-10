//
//  OAuth2ClientConfig.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 16/11/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
//

import Foundation


/**
Client configuration object that holds on to client-server specific configurations such as client id, -secret and server URLs.
*/
open class OAuth2ClientConfig {
	
	/// The client id.
	public final var clientId: String?
	
	/// The client secret, usually only needed for code grant.
	public final var clientSecret: String?
	
	/// The name of the client, e.g. for use during dynamic client registration.
	public final var clientName: String?
	
	/// The URL to authorize against.
	public final let authorizeURL: URL
	
	/// The URL where we can exchange a code for a token.
	public final var tokenURL: URL?
	
	/// Where a logo/icon for the app can be found.
	public final var logoURL: URL?
	
	/// The scope currently in use.
	open var scope: String?
	
	/// The redirect URL string currently in use.
	open var redirect: String?
	
	/// All redirect URLs passed to the initializer.
	open var redirectURLs: [String]?
	
	/// The receiver's access token.
	open var accessToken: String?

	/// The receiver's id token.  Used by Google + and AWS Cognito
	open var idToken: String?

	/// The access token's expiry date.
	open var accessTokenExpiry: Date?
	
	/// If set to true (the default), uses a keychain-supplied access token even if no "expires_in" parameter was supplied.
	open var accessTokenAssumeUnexpired = true
	
	/// The receiver's long-time refresh token.
	open var refreshToken: String?
	
	/// The URL to register a client against.
	public final var registrationURL: URL?
	
	/// Whether the receiver should use the request body instead of the Authorization header for the client secret; defaults to `false`.
	public var secretInBody = false
	
	/// How the client communicates the client secret with the server. Defaults to ".None" if there is no secret, ".clientSecretPost" if
	/// "secret_in_body" is `true` and ".clientSecretBasic" otherwise. Interacts with the `secretInBody` setting.
	public final var endpointAuthMethod = OAuth2EndpointAuthMethod.none
	
	/// Contains special authorization request headers, can be used to override defaults.
	open var authHeaders: OAuth2Headers?
	
	/// Add custom parameters to the authorization request.
	public var customParameters: [String: String]? = nil
	
	/// Most servers use UTF-8 encoding for Authorization headers, but that's not 100% true: make it configurable (see https://github.com/p2/OAuth2/issues/165).
	open var authStringEncoding = String.Encoding.utf8
	
	/// There's an issue with authenticating through 'system browser', where safari says:
	/// "Safari cannot open the page because the address is invalid." if you first selects 'Cancel' when asked to switch back to "your" app,
	/// and then you try authenticating again. To get rid of it you must restart Safari.
	///
	/// Read more about it here:
	/// http://stackoverflow.com/questions/27739442/ios-safari-does-not-recognize-url-schemes-after-user-cancels
	/// https://community.fitbit.com/t5/Web-API/oAuth2-authentication-page-gives-me-a-quot-Cannot-Open-Page-quot-error/td-p/1150391
	///
	/// Toggling `safariCancelWorkaround` to true will send an extra get-paramter to make the url unique, thus it will ask again for the new
	/// url.
	open var safariCancelWorkaround = false	
	
	/**
	Initializer to initialize properties from a settings dictionary.
	*/
	public init(settings: OAuth2JSON) {
		clientId = settings["client_id"] as? String
		clientSecret = settings["client_secret"] as? String
		clientName = settings["client_name"] as? String
		
		// authorize URL
		var aURL: URL?
		if let auth = settings["authorize_uri"] as? String {
			aURL = URL(string: auth)
		}
		authorizeURL = aURL ?? URL(string: "https://localhost/p2.OAuth2.defaultAuthorizeURI")!
		
		// token, registration and logo URLs
		if let token = settings["token_uri"] as? String {
			tokenURL = URL(string: token)
		}
		if let registration = settings["registration_uri"] as? String {
			registrationURL = URL(string: registration)
		}
		if let logo = settings["logo_uri"] as? String {
			logoURL = URL(string: logo)
		}
		
		// client authorization options
		scope = settings["scope"] as? String
		if let redirs = settings["redirect_uris"] as? [String] {
			redirectURLs = redirs
			redirect = redirs.first
		}
		if let inBody = settings["secret_in_body"] as? Bool {
			secretInBody = inBody
		}
		if secretInBody {
			endpointAuthMethod = .clientSecretPost
		}
		else if nil != clientSecret {
			endpointAuthMethod = .clientSecretBasic
		}
		if let headers = settings["headers"] as? OAuth2Headers {
			authHeaders = headers
		}
		if let params = settings["parameters"] as? OAuth2StringDict {
			customParameters = params
		}
		
		// access token options
		if let assume = settings["token_assume_unexpired"] as? Bool {
			accessTokenAssumeUnexpired = assume
		}
	}
	
	
	/**
	Update properties from response data.
	
	This method assumes values are present with the standard names, such as `access_token`, and assigns them to its properties.
	
	- parameter json: JSON data returned from a request
	*/
	func updateFromResponse(_ json: OAuth2JSON) {
		if let access = json["access_token"] as? String {
			accessToken = access
		}
		if let idtoken = json["id_token"] as? String {
			idToken = idtoken
		}
		accessTokenExpiry = nil
		if let expires = json["expires_in"] as? TimeInterval {
			accessTokenExpiry = Date(timeIntervalSinceNow: expires)
		}
		else if let expires = json["expires_in"] as? Int {
			accessTokenExpiry = Date(timeIntervalSinceNow: Double(expires))
		}
		else if let expires = json["expires_in"] as? String {			// when parsing implicit grant from URL fragment
			accessTokenExpiry = Date(timeIntervalSinceNow: Double(expires) ?? 0.0)
		}
		if let refresh = json["refresh_token"] as? String {
			refreshToken = refresh
		}
	}
	
	/**
	Creates a dictionary of credential items that can be stored to the keychain.
	
	- returns: A storable dictionary with credentials
	*/
	func storableCredentialItems() -> [String: Any]? {
		guard let clientId = clientId, !clientId.isEmpty else { return nil }
		
		var items: [String: Any] = ["id": clientId]
		if let secret = clientSecret {
			items["secret"] = secret
		}
		items["endpointAuthMethod"] = endpointAuthMethod.rawValue
		return items
	}
	
	/**
	Creates a dictionary of token items that can be stored to the keychain.
	
	- returns: A storable dictionary with token data
	*/
	func storableTokenItems() -> [String: Any]? {
		guard let access = accessToken, !access.isEmpty else { return nil }
		
		var items: [String: Any] = ["accessToken": access]
		if let date = accessTokenExpiry, date == (date as NSDate).laterDate(Date()) {
			items["accessTokenDate"] = date
		}
		if let refresh = refreshToken, !refresh.isEmpty {
			items["refreshToken"] = refresh
		}
		if let idtoken = idToken, !idtoken.isEmpty {
			items["idToken"] = idtoken
		}
		return items
	}
	
	/**
	Updates receiver's instance variables with values found in the dictionary. Returns a list of messages that can be logged on debug.
	
	- parameter items: The dictionary representation of the data to store to keychain
	- returns: An array of strings containing log messages
	*/
	func updateFromStorableItems(_ items: [String: Any]) -> [String] {
		var messages = [String]()
		if let id = items["id"] as? String {
			clientId = id
			messages.append("Found client id")
		}
		if let secret = items["secret"] as? String {
			clientSecret = secret
			messages.append("Found client secret")
		}
		if let methodName = items["endpointAuthMethod"] as? String, let method = OAuth2EndpointAuthMethod(rawValue: methodName) {
			endpointAuthMethod = method
		}
		if let token = items["accessToken"] as? String, !token.isEmpty {
			if let date = items["accessTokenDate"] as? Date {
				if date == (date as NSDate).laterDate(Date()) {
					messages.append("Found access token, valid until \(date)")
					accessTokenExpiry = date
					accessToken = token
				}
				else {
					messages.append("Found access token but it seems to have expired")
				}
			}
			else if accessTokenAssumeUnexpired {
				messages.append("Found access token but no expiration date, assuming unexpired (set `accessTokenAssumeUnexpired` to false to discard)")
				accessToken = token
			}
			else {
				messages.append("Found access token but no expiration date, discarding (set `accessTokenAssumeUnexpired` to true to still use it)")
			}
		}
		if let token = items["refreshToken"] as? String, !token.isEmpty {
			messages.append("Found refresh token")
			refreshToken = token
		}
		if let idtoken = items["idToken"] as? String, !idtoken.isEmpty {
			messages.append("Found id token")
			idToken = idtoken
		}
		return messages
	}
	
	/** Forgets the configuration's client id and secret. */
	open func forgetCredentials() {
		clientId = nil
		clientSecret = nil
	}
	
	/** Forgets the configuration's current tokens. */
	open func forgetTokens() {
		accessToken = nil
		accessTokenExpiry = nil
		refreshToken = nil
		idToken = nil
	}
}

