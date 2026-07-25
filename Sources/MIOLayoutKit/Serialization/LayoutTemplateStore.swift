//
//  LayoutTemplateStore.swift
//  MIOLayoutKit
//
//  Storage abstraction for serialized layout templates. The file
//  implementation lives here; database-backed implementations live in
//  consumer libraries behind the same protocol.
//

import Foundation


public struct LayoutTemplateDescriptor: Codable, Equatable {
    public var key: String
    public var name: String?
    public var language: String?
    public var documentType: String?
    public var formatVersion: Int

    public init ( key: String, name: String? = nil, language: String? = nil
                , documentType: String? = nil, formatVersion: Int = LayoutTemplateFormatVersion ) {
        self.key = key
        self.name = name
        self.language = language
        self.documentType = documentType
        self.formatVersion = formatVersion
    }
}


public protocol LayoutTemplateStore {
    func save ( _ descriptor: LayoutTemplateDescriptor, body: Data ) throws
    func load ( key: String, language: String? ) throws -> Data
    func list ( documentType: String? ) throws -> [LayoutTemplateDescriptor]
    func delete ( key: String, language: String? ) throws
}


public enum LayoutTemplateStoreError: Error, CustomStringConvertible {
    case notFound( key: String, language: String? )

    public var description: String {
        switch self {
        case .notFound( let key, let language ):
            return "Layout template '\(key)'\(language.map { " (\($0))" } ?? "") not found"
        }
    }
}


/// Stores each template as `<key>[.<language>].layout.json` under a root
/// directory. Loading with a language falls back to the language-neutral file.
public final class FileLayoutTemplateStore: LayoutTemplateStore {

    public let rootURL: URL

    public init ( rootPath: String ) throws {
        self.rootURL = URL( fileURLWithPath: rootPath, isDirectory: true )
        try FileManager.default.createDirectory( at: rootURL, withIntermediateDirectories: true )
    }

    static let fileSuffix = ".layout.json"

    func fileURL ( key: String, language: String? ) -> URL {
        let name = key + ( language.map { ".\($0)" } ?? "" ) + FileLayoutTemplateStore.fileSuffix
        return rootURL.appendingPathComponent( name )
    }

    public func save ( _ descriptor: LayoutTemplateDescriptor, body: Data ) throws {
        // The body must at least parse as a template document.
        _ = try JSONDecoder().decode( LayoutTemplateDocument.self, from: body )
        try body.write( to: fileURL( key: descriptor.key, language: descriptor.language ), options: .atomic )
    }

    public func load ( key: String, language: String? ) throws -> Data {
        let url = fileURL( key: key, language: language )
        if FileManager.default.fileExists( atPath: url.path ) {
            return try Data( contentsOf: url )
        }

        if language != nil {
            let neutral = fileURL( key: key, language: nil )
            if FileManager.default.fileExists( atPath: neutral.path ) {
                return try Data( contentsOf: neutral )
            }
        }

        throw LayoutTemplateStoreError.notFound( key: key, language: language )
    }

    public func list ( documentType: String? ) throws -> [LayoutTemplateDescriptor] {
        let files = try FileManager.default.contentsOfDirectory( atPath: rootURL.path )
        var result: [LayoutTemplateDescriptor] = []

        for file in files.sorted() where file.hasSuffix( FileLayoutTemplateStore.fileSuffix ) {
            let base = String( file.dropLast( FileLayoutTemplateStore.fileSuffix.count ) )

            let key: String
            let language: String?
            if let dot = base.range( of: ".", options: .backwards ) {
                key = String( base[ ..<dot.lowerBound ] )
                language = String( base[ dot.upperBound... ] )
            }
            else {
                key = base
                language = nil
            }

            let data = try Data( contentsOf: rootURL.appendingPathComponent( file ) )
            guard let document = try? JSONDecoder().decode( LayoutTemplateDocument.self, from: data ) else { continue }

            if let filter = documentType, document.documentType != filter { continue }

            result.append( LayoutTemplateDescriptor( key: key
                                                   , name: document.name
                                                   , language: language
                                                   , documentType: document.documentType
                                                   , formatVersion: document.formatVersion ) )
        }

        return result
    }

    public func delete ( key: String, language: String? ) throws {
        let url = fileURL( key: key, language: language )
        guard FileManager.default.fileExists( atPath: url.path ) else {
            throw LayoutTemplateStoreError.notFound( key: key, language: language )
        }
        try FileManager.default.removeItem( at: url )
    }
}
