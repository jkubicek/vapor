//  JeevesTests.swift
//  Vapor
//
//  Created by Logan Wright on 3/12/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest

@testable import Vapor

class HTTPStreamTests: XCTestCase {

    static var allTests: [(String, (HTTPStreamTests) -> () throws -> Void)] {
        return [
           ("testParser", testParser),
           ("testSerializer", testSerializer)
        ]
    }

    func testParser() {
        let stream = TestStream()

        //MARK: Create Request
        let content = "{\"hello\": \"world\"}"

        var data = "POST /json HTTP/1.1\r\n"
        data += "Accept-Encoding: gzip, deflate\r\n"
        data += "Accept: */*\r\n"
        data += "Accept-Language: en-us\r\n"
        data += "Cookie: 1=1;2=2\r\n"
        data += "Content-Type: application/json\r\n"
        data += "Content-Length: \(content.characters.count)\r\n"
        data += "\r\n"
        data += content

        try! stream.send(data.data, timingOut: 0)
        let parser = HTTPParser(stream: stream)

        do {
            let request = try parser.parse()

            //MARK: Verify Request
            XCTAssert(request.method == Request.Method.post, "Incorrect method \(request.method)")
            XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
            XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
        } catch {
            XCTFail("Parsing failed: \(error)")
        }
    }

    func testSerializer() {
        //MARK: Create Response
        var response = Response(status: .enhanceYourCalm, headers: [
            "Test": "123",
            "Content-Type": "text/plain"
        ], chunked: { stream in
            try stream.send("Hello, world")
            try stream.close()
        })
        response.cookies["key"] = "val"

        let stream = TestStream()
        let serializer =  HTTPSerializer(stream: stream)
        do {
            try serializer.serialize(response)
        } catch {
            XCTFail("Could not serialize response: \(error)")
        }

        let data = try! stream.receive(upTo: 2048, timingOut: 0)

        XCTAssert(data.string.range(of: "HTTP/1.1 420 Enhance Your Calm") != nil)
        XCTAssert(data.string.range(of: "Content-Type: text/plain") != nil)
        XCTAssert(data.string.range(of: "Test: 123") != nil)
        XCTAssert(data.string.range(of: "Transfer-Encoding: chunked") != nil)
        XCTAssert(data.string.range(of: "\r\n\r\nC\r\nHello, world\r\n0\r\n\r\n") != nil)
    }
}

final class TestStream: Stream {
    var closed: Bool
    var buffer: Data

    init() {
        closed = false
        buffer = []
    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ data: Data, timingOut deadline: Double) throws {
        closed = false
        buffer.append(contentsOf: data)
    }

    func flush(timingOut deadline: Double) throws {
        buffer = Data()
    }

    func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        if buffer.count == 0 {
            try close()
            return []
        }

        if byteCount >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }
}

final class TestStreamDriver: StreamDriver {
    init() {

    }

    static func make(host: String, port: Int) throws -> Self {
        return .init()

    }
    func start(handler: (Stream) throws -> ()) throws {

    }
}
