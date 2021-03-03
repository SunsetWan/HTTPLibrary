//
//  HTTPLibrary.swift
//  HTTPLibrary
//
//  Created by chenxi on 2021/2/25.
//

import Foundation

// HTTP Version 1.1
public struct HTTPMethod: Hashable {
    public static let get = HTTPMethod(rawValue: "GET")
    public static let post = HTTPMethod(rawValue: "POST")
    public static let put = HTTPMethod(rawValue: "PUT")
    public static let delete = HTTPMethod(rawValue: "DELETE")

    public let rawValue: String
}

public struct HTTPStatus: Hashable {
    public static let ok = HTTPStatus(rawValue: 200)
    public static let movedPermanently = HTTPStatus(rawValue: 300)
    public static let badRequest = HTTPStatus(rawValue: 400)
    public static let notFound = HTTPStatus(rawValue: 404)

    public let rawValue: Int
    //    public let description: String

    var code: Code? {
        Code(rawValue: rawValue)
    }

    enum Code: Int {
        case ok = 200
        case movedPermanently = 300
        case badRequest = 400
        case notFound = 404
    }

}

public protocol HTTPBody {
    var isEmpty: Bool { get }
    var additionalHeaders: [String: String] { get }
    func encode() throws -> Data
}

extension HTTPBody {
    public var isEmpty: Bool { return false }
    public var additionalHeaders: [String: String] { return [:] }
}

public struct EmptyBody: HTTPBody {
    public let isEmpty = true

    public init() { }
    public func encode() throws -> Data { Data() }
}

public struct DataBody: HTTPBody {
    private let data: Data

    public var isEmpty: Bool { data.isEmpty }
    public var additionalHeaders: [String: String]

    public init(_ data: Data, additionalHeaders: [String: String] = [:]) {
        self.data = data
        self.additionalHeaders = additionalHeaders
    }

    public func encode() throws -> Data { data }
}

public struct JSONBody: HTTPBody {
    public let isEmpty: Bool = false
    public var additionalHeaders = [
        "Content-Type": "application/json; charset=utf-8"
    ]

    private let _encode: () throws -> Data

    // Maybe custom JSONEncoder?
    public init<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) {
        self._encode = { try encoder.encode(value) }
    }

    public func encode() throws -> Data { return try _encode() }
}

public struct FormBody: HTTPBody {
    public var isEmpty: Bool { values.isEmpty }
    public let additionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded; charset=utf-8"
    ]

    private let values: [URLQueryItem]

    public init(_ values: [URLQueryItem]) {
        self.values = values
    }

    public init(_ values: [String: String]) {
        let queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        self.init(queryItems)
    }

    public func encode() throws -> Data {
        let pieces = values.map(self.urlEncode)
        let bodyString = pieces.joined(separator: "&")
        return Data(bodyString.utf8)
    }

    private func urlEncode(_ string: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
    }

    private func urlEncode(_ queryItem: URLQueryItem) -> String {
        let name = urlEncode(queryItem.name)
        let value = urlEncode(queryItem.value ?? "")
        return "\(name)=\(value)"
    }
}

public struct HTTPRequest {
    private var urlComponents = URLComponents()
    public var method: HTTPMethod = .get // the struct we previously defined
    public var headers: [String: String] = [:]
    public var body: HTTPBody = EmptyBody()

    public var url: URL? {
        return urlComponents.url
    }

    public init() {
        urlComponents.scheme = "https"
    }
}

public extension HTTPRequest {

    public var scheme: String { urlComponents.scheme ?? "https" }

    public var host: String? {
        get { urlComponents.host }
        set { urlComponents.host = newValue }
    }

    public var path: String {
        get { urlComponents.path }
        set { urlComponents.path = newValue }
    }

}

public struct HTTPResponse {
    public let request: HTTPRequest
    public let response: HTTPURLResponse
    public let body: Data?

    public var status: HTTPStatus {
        // A struct of similar construction to HTTPMethod
        HTTPStatus(rawValue: response.statusCode)
    }

    public var message: String {
        HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
    }

    // case insensitivity
    public var headers: [AnyHashable: Any] { response.allHeaderFields }
}


public typealias HTTPResult = Result<HTTPResponse, HTTPError>

public struct HTTPError: Error {
    /// The high-level classification of this error
    public let code: Code

    /// The HTTPRequest that resulted in this error
    public let request: HTTPRequest

    /// Any HTTPResponse (partial or otherwise) that we might have
    public let response: HTTPResponse?

    /// If we have more information about the error that caused this, stash it here
    public let underlyingError: Error?

    public enum Code {
        case invalidRequest     // the HTTPRequest could not be turned into a URLRequest
        case cannotConnect      // some sort of connectivity problem
        case cancelled          // the user cancelled the request
        case insecureConnection // couldn't establish a secure connection to the server
        case invalidResponse    // the system did not receive a valid HTTP response
        //...                     // other scenarios we may wish to expose; fill them in as necessary
        case unknown            // we have no idea what the problem is
        case wrongUrl
        case bodyEncodeError
    }
}

extension HTTPResult {
    public var request: HTTPRequest {
        switch self {
        case .success(let response): return response.request
        case .failure(let error): return error.request
        }
    }

    public var response: HTTPResponse? {
        switch self {
        case .success(let response): return response
        case .failure(let error): return error.response
        }
    }
}


public protocol HTTPLoading {
    func load(request: HTTPRequest, completion: @escaping (HTTPResult) -> Void)
}

extension URLSession: HTTPLoading {
    public func load(request: HTTPRequest, completion: @escaping (HTTPResult) -> Void) {
        guard let url = request.url else {
            // we couldn't construct a proper URL out of the request's URLComponents
            let error = HTTPError(code: .wrongUrl, request: request, response: nil, underlyingError: nil)
            completion(.failure(error))
            return
        }

        // construct the URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        // copy over any custom HTTP headers
        for (header, value) in request.headers {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }

        if request.body.isEmpty == false {
            // if our body defines additional headers, add them
            for (header, value) in request.body.additionalHeaders {
                urlRequest.addValue(value, forHTTPHeaderField: header)
            }

            // attempt to retrieve the body data
            do {
                urlRequest.httpBody = try request.body.encode()
            } catch {
                // something went wrong creating the body; stop and report back
                let error = HTTPError(code: .wrongUrl, request: request, response: nil, underlyingError: nil)
                completion(.failure(error))
                return
            }
        }

        let dataTask = self.dataTask(with: urlRequest) { (data, response, error) in
            // construct a Result<HTTPResponse, HTTPError> out of the triplet of data, url response, and url error
            var httpResponse: HTTPResponse?
//            var httpResult: HTTPResult?
            if let r = response as? HTTPURLResponse {
                httpResponse = HTTPResponse(request: request, response: r, body: data)
            }

            if let e = error as? URLError {
                let code: HTTPError.Code
                switch e.code {
                case .badURL:
                    code = .invalidRequest
//                case .unsupportedURL
                default:
                    code = .unknown
                }

                let httpResult: HTTPResult = .failure(HTTPError(code: code, request: request, response: httpResponse, underlyingError: e))
                completion(httpResult)
            } else if let someError = error {
                // an error, but not a URL error
                let httpResult: HTTPResult = .failure(HTTPError(code: .unknown, request: request, response: httpResponse, underlyingError: someError))
                completion(httpResult)
            } else if let r = httpResponse {
                // not an error, and an HTTPURLResponse
                let httpResult: HTTPResult = .success(r)
                completion(httpResult)
            } else {
                // not an error, but also not an HTTPURLResponse
                let httpResult: HTTPResult = .failure(HTTPError(code: .invalidResponse, request: request, response: nil, underlyingError: error))
                completion(httpResult)
            }
        }

        // off we go!
        dataTask.resume()
    }
}

public class StarWarsAPI {
    private let loader: HTTPLoading = URLSession.shared

    public func requestPeople(completion: @escaping (...) -> Void) {
        var r = HTTPRequest()
        r.host = "swapi.dev"
        r.path = "/api/people"

        loader.load(request: r) { result in
            // TODO: interpret the result
            completion(...)
        }
    }
}







