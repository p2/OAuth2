//
//  OAuth2Error.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 16/11/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
All errors that might occur.

The response errors return a description as defined in the spec: http://tools.ietf.org/html/rfc6749#section-4.1.2.1
*/
public enum OAuth2Error: Error, CustomStringConvertible, Equatable {
	
	/// An error for which we don't have a specific one.
	case generic(String)
	
	/// An error holding on to an NSError.
	case nsError(Foundation.NSError)
	
	/// Invalid URL components, failed to create a URL
	case invalidURLComponents(URLComponents)
	
	
	// MARK: - Client errors
	
	/// There is no client id.
	case noClientId
	
	/// There is no client secret.
	case noClientSecret
	
	/// There is no redirect URL.
	case noRedirectURL
	
	/// There is no username.
	case noUsername
	
	/// There is no password.
	case noPassword
	
	/// The client is already authorizing.
	case alreadyAuthorizing
	
	/// There is no authorization context.
	case noAuthorizationContext
	
	/// The authorization context is invalid.
	case invalidAuthorizationContext
	
	/// The redirect URL is invalid; with explanation.
	case invalidRedirectURL(String)
	
	/// There is no access token.
	case noAccessToken
	
	/// There is no refresh token.
	case noRefreshToken
	
	/// There is no registration URL.
	case noRegistrationURL
	
	/// The login controller does not have a valid type
	case invalidLoginController(actualType: String, expectedType: String)

	/// There is no delegate associated with the password grant flow instance.
	case noPasswordGrantDelegate
	
	
	// MARK: - Request errors
	
	/// The request is not using SSL/TLS.
	case notUsingTLS
	
	/// Unable to open the authorize URL.
	case unableToOpenAuthorizeURL
	
	/// The request is invalid.
	case invalidRequest
	
	/// The request was canceled.
	case requestCancelled
	
	
	// MARK: - Response Errors
	
	/// There was no token type in the response.
	case noTokenType
	
	/// The token type is not supported.
	case unsupportedTokenType(String)
	
	/// There was no data in the response.
	case noDataInResponse
	
	/// Some prerequisite failed; with explanation.
	case prerequisiteFailed(String)
	
	/// The state parameter was missing in the response.
	case missingState
	
	/// The state parameter was invalid.
	case invalidState
	
	/// The JSON response could not be parsed.
	case jsonParserError
	
	/// Unable to UTF-8 encode.
	case utf8EncodeError
	
	/// Unable to decode to UTF-8.
	case utf8DecodeError
	
	
	// MARK: - OAuth2 errors
	
	/// The client is unauthorized (HTTP status 401).
	case unauthorizedClient
	
	/// The request was forbidden (HTTP status 403).
	case forbidden
	
	/// Username or password was wrong (HTTP status 403 on password grant).
	case wrongUsernamePassword
	
	/// Access was denied.
	case accessDenied
	
	/// Response type is not supported.
	case unsupportedResponseType
	
	/// Scope was invalid.
	case invalidScope
	
	/// A 500 was thrown.
	case serverError
	
	/// The service is temporarily unavailable.
	case temporarilyUnavailable
	
	/// Other response error, as defined in its String.
	case responseError(String)
	
	
	/**
	Instantiate the error corresponding to the OAuth2 response code, if it is known.
	
	- parameter code: The code, like "access_denied", that should be interpreted
	- parameter fallback: The error string to use in case the error code is not known
	- returns: An appropriate OAuth2Error
	*/
	public static func fromResponseError(_ code: String, fallback: String? = nil) -> OAuth2Error {
		switch code {
		case "invalid_request":
			return .invalidRequest
		case "unauthorized_client":
			return .unauthorizedClient
		case "access_denied":
			return .accessDenied
		case "unsupported_response_type":
			return .unsupportedResponseType
		case "invalid_scope":
			return .invalidScope
		case "server_error":
			return .serverError
		case "temporarily_unavailable":
			return .temporarilyUnavailable
		default:
			return .responseError(fallback ?? "Authorization error: \(code)")
		}
	}
	
	/// Human understandable error string.
	public var description: String {
		switch self {
		case .generic(let message):
			return message
		case .nsError(let error):
			return error.localizedDescription
		case .invalidURLComponents(let components):
			return "Failed to create URL from components: \(components)"
		
		case .noClientId:
			return "Client id not set"
		case .noClientSecret:
			return "Client secret not set"
		case .noRedirectURL:
			return "Redirect URL not set"
		case .noUsername:
			return "No username"
		case .noPassword:
			return "No password"
		case .invalidLoginController(let expectedType, let actualType):
			return "The login controller of type \(actualType) cannot be displayed. Expecting a \(expectedType)."
		case .noPasswordGrantDelegate:
			return "The password grant flow needs to be set a delegate to present the login controller."
		case .alreadyAuthorizing:
			return "The client is already authorizing, wait for it to finish or abort authorization before trying again"
		case .noAuthorizationContext:
			return "No authorization context present"
		case .invalidAuthorizationContext:
			return "Invalid authorization context"
		case .invalidRedirectURL(let url):
			return "Invalid redirect URL: \(url)"
		case .noAccessToken:
			return "I don't have an access token, cannot sign request"
		case .noRefreshToken:
			return "I don't have a refresh token, not trying to refresh"
		
		case .noRegistrationURL:
			return "No registration URL defined"
		
		case .notUsingTLS:
			return "You MUST use HTTPS/SSL/TLS"
		case .unableToOpenAuthorizeURL:
			return "Cannot open authorize URL"
		case .invalidRequest:
			return "The request is missing a required parameter, includes an invalid parameter value, includes a parameter more than once, or is otherwise malformed."
		case .requestCancelled:
			return "The request has been canceled"
		case .noTokenType:
			return "No token type received, will not use the token"
		case .unsupportedTokenType(let message):
			return message
		case .noDataInResponse:
			return "No data in the response"
		case .prerequisiteFailed(let message):
			return message
		case .missingState:
			return "The state parameter was missing in the response"
		case .invalidState:
			return "The state parameter did not check out"
		case .jsonParserError:
			return "Error parsing JSON"
		case .utf8EncodeError:
			return "Failed to UTF-8 encode the given string"
		case .utf8DecodeError:
			return "Failed to decode given data as a UTF-8 string"
		
		case .unauthorizedClient:
			return "Unauthorized"
		case .forbidden:
			return "Forbidden"
		case .wrongUsernamePassword:
			return "The username or password is incorrect"
		case .accessDenied:
			return "The resource owner or authorization server denied the request."
		case .unsupportedResponseType:
			return "The authorization server does not support obtaining an access token using this method."
		case .invalidScope:
			return "The requested scope is invalid, unknown, or malformed."
		case .serverError:
			return "The authorization server encountered an unexpected condition that prevented it from fulfilling the request."
		case .temporarilyUnavailable:
			return "The authorization server is currently unable to handle the request due to a temporary overloading or maintenance of the server."
		case .responseError(let message):
			return message
		}
	}
	
	
	// MARK: - Equatable
	
	public static func ==(lhs: OAuth2Error, rhs: OAuth2Error) -> Bool {
		switch (lhs, rhs) {
		case (.generic(let lhm), .generic(let rhm)):    return lhm == rhm
		case (.nsError(let lhe), .nsError(let rhe)):    return lhe.isEqual(rhe)
		case (.invalidURLComponents(let lhe), .invalidURLComponents(let rhe)):   return (lhe == rhe)
		
		case (.noClientId, .noClientId):                             return true
		case (.noClientSecret, .noClientSecret):                     return true
		case (.noRedirectURL, .noRedirectURL):                       return true
		case (.noUsername, .noUsername):                             return true
		case (.noPassword, .noPassword):                             return true
		case (.alreadyAuthorizing, .alreadyAuthorizing):             return true
		case (.noAuthorizationContext, .noAuthorizationContext):                 return true
		case (.invalidAuthorizationContext, .invalidAuthorizationContext):       return true
		case (.invalidRedirectURL(let lhu), .invalidRedirectURL(let rhu)):       return lhu == rhu
		case (.noAccessToken, .noAccessToken):                       return true
		case (.noRefreshToken, .noRefreshToken):                     return true
		
		case (.notUsingTLS, .notUsingTLS):                           return true
		case (.unableToOpenAuthorizeURL, .unableToOpenAuthorizeURL): return true
		case (.invalidRequest, .invalidRequest):                     return true
		case (.requestCancelled, .requestCancelled):                 return true
		case (.noTokenType, .noTokenType):                           return true
		case (.unsupportedTokenType(let lhm), .unsupportedTokenType(let rhm)):   return lhm == rhm
		case (.noDataInResponse, .noDataInResponse):                 return true
		case (.prerequisiteFailed(let lhm), .prerequisiteFailed(let rhm)):       return lhm == rhm
		case (.missingState, .missingState):                         return true
		case (.invalidState, .invalidState):                         return true
		case (.jsonParserError, .jsonParserError):                   return true
		case (.utf8EncodeError, .utf8EncodeError):                   return true
		case (.utf8DecodeError, .utf8DecodeError):                   return true
		
		case (.unauthorizedClient, .unauthorizedClient):             return true
		case (.forbidden, .forbidden):                               return true
		case (.wrongUsernamePassword, .wrongUsernamePassword):       return true
		case (.accessDenied, .accessDenied):                         return true
		case (.unsupportedResponseType, .unsupportedResponseType):   return true
		case (.invalidScope, .invalidScope):                         return true
		case (.serverError, .serverError):                           return true
		case (.temporarilyUnavailable, .temporarilyUnavailable):     return true
		case (.responseError(let lhm), .responseError(let rhm)):     return lhm == rhm
		default:                                                     return false
		}
	}
}


public extension Error {
	
	/**
	Convenience getter to easily retrieve an OAuth2Error from any Error.
	*/
	public var asOAuth2Error: OAuth2Error {
		if let oaerror = self as? OAuth2Error {
			return oaerror
		}
		return OAuth2Error.nsError(self as NSError)
	}
}

