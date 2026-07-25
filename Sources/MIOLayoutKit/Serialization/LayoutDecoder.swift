//
//  LayoutDecoder.swift
//  MIOLayoutKit
//
//  Decodes a serialized layout template (JSON) into a layout tree, pulling
//  dynamic values from a LayoutDataProvider as it meets them. After decoding,
//  the tree contains only literal values and renders through the existing
//  pipeline unchanged.
//

import Foundation


struct LayoutTemplateDocument: Codable {
    var formatVersion: Int
    var documentType: String?
    var name: String?
    var paper: String?
    var margins: MarginValues?
    var header: LayoutNode?
    var footer: LayoutNode?
    var root: LayoutNode

    struct MarginValues: Codable {
        var top: Float?
        var right: Float?
        var bottom: Float?
        var left: Float?
    }
}


public final class LayoutDecoder {

    public let registry: LayoutNodeRegistry
    public let fragments: LayoutFragmentLibrary

    /// Non-fatal problems found while decoding: unresolved binding paths,
    /// collections without count, ... The validate flow decodes against a
    /// sample provider and reports these.
    public private(set) var issues: [String] = []

    var provider: LayoutDataProvider?

    /// Safety cap for flat-mode row probing when the provider implements
    /// neither items(forPath:) nor count(forPath:).
    public var maxProbedRows = 10_000

    public init ( registry: LayoutNodeRegistry = .standard, fragments: LayoutFragmentLibrary = .standard ) {
        self.registry = registry
        self.fragments = fragments
    }

    // MARK: - Entry points

    public func decode ( _ data: Data, provider: LayoutDataProvider? = nil ) throws -> Page {
        self.provider = provider
        self.issues = []

        let document: LayoutTemplateDocument
        do {
            document = try JSONDecoder().decode( LayoutTemplateDocument.self, from: data )
        }
        catch let error as LayoutSerializationError { throw error }
        catch {
            throw LayoutSerializationError.invalidDocument( "\(error)" )
        }

        if document.formatVersion > LayoutTemplateFormatVersion {
            throw LayoutSerializationError.invalidDocument( "format version \(document.formatVersion) is newer than supported \(LayoutTemplateFormatVersion)" )
        }

        let page: Page
        switch document.paper ?? "a4-portrait" {
        case "a4-portrait":  page = A4.portrait()
        case "a4-landscape": page = A4.lanscape()
        default:
            throw LayoutSerializationError.invalidDocument( "unknown paper '\(document.paper!)'" )
        }

        if let m = document.margins {
            page.setMargins( Margin( m.top ?? 0, m.right ?? 0, m.bottom ?? 0, m.left ?? 0 ) )
        }

        if let header_node = document.header, let item = try decodeItem( header_node, defaultInclude: .all ) {
            page.header = item
            item.parent = page
        }

        if let footer_node = document.footer, let item = try decodeItem( footer_node, defaultInclude: .all ) {
            page.footer = item
            item.parent = page
        }

        if let root = try decodeItem( document.root ) {
            page.add( root )
        }

        return page
    }

    /// Decodes one node into a layout item. Returns nil when the node is
    /// hidden by `visibleIf`. Node coders call this for their children.
    public func decodeItem ( _ node: LayoutNode ) throws -> LayoutItem? {
        try decodeItem( node, defaultInclude: .here )
    }

    func decodeItem ( _ node: LayoutNode, defaultInclude: IncludeInPage ) throws -> LayoutItem? {
        var node = node

        if let ref = node.stringIfPresent( "ref" ) {
            guard let fragment = fragments.fragment( ref ) else {
                throw LayoutSerializationError.unknownFragment( ref )
            }
            node = fragment
        }

        if let condition = node.stringIfPresent( "visibleIf" ) {
            if let provider = provider {
                if !provider.bool( forPath: condition ) { return nil }
            }
            else {
                issues.append( "visibleIf '\(condition)' has no provider; node kept" )
            }
        }

        guard let coder = registry.decoder( for: node.type ) else {
            throw LayoutSerializationError.unknownNodeType( node.type )
        }

        let item = try coder.decode( node, self )

        item.flex = node.int( "flex", default: item.flex )
        if let id = node.stringIfPresent( "id" ) { item.id = id }
        if node.bool( "unbreakable", default: false ) { item.is_unbreakable = true }
        item.include_in_pages = try node.includeInPages( "includeInPages", default: defaultInclude )

        if let style_obj = node.objectIfPresent( "style" ) {
            try LayoutStyleCoding.decode( style_obj, into: item.style, nodeType: node.type )
        }

        return item
    }

    // MARK: - Bindings

    /// Resolves `{{ path }}` / `{{ path | hint }}` bindings inside a string.
    /// Text outside braces is kept literally; a quoted segment (`{{ 'X' }}`)
    /// resolves to the literal X.
    public func resolveText ( _ template: String ) -> String {
        guard template.contains( "{{" ) else { return template }

        var result = ""
        var rest = Substring( template )

        while let open = rest.range( of: "{{" ) {
            result += rest[ ..<open.lowerBound ]
            rest = rest[ open.upperBound... ]

            guard let close = rest.range( of: "}}" ) else {
                result += "{{"
                break
            }

            let expression = String( rest[ ..<close.lowerBound ] )
            rest = rest[ close.upperBound... ]

            result += resolveExpression( expression ) ?? ""
        }

        result += rest
        return result
    }

    func resolveExpression ( _ expression: String ) -> String? {
        var path = expression
        var hint: String? = nil

        if let pipe = expression.range( of: "|" ) {
            path = String( expression[ ..<pipe.lowerBound ] )
            hint = String( expression[ pipe.upperBound... ] ).trimmingCharacters( in: .whitespaces )
        }
        path = path.trimmingCharacters( in: .whitespaces )

        if path.hasPrefix( "'" ) && path.hasSuffix( "'" ) && path.count >= 2 {
            return String( path.dropFirst().dropLast() )
        }

        return text( forPath: path, hint: hint )
    }

    /// Provider lookup that records unresolved paths as issues.
    public func text ( forPath path: String, hint: String? = nil ) -> String? {
        guard let provider = provider else {
            issues.append( "unresolved '\(path)': no data provider" )
            return nil
        }

        guard let value = provider.text( forPath: path, hint: hint ) else {
            issues.append( "unresolved '\(path)'" )
            return nil
        }

        return value
    }

    public func recordIssue ( _ message: String ) {
        issues.append( message )
    }

    // MARK: - Collections (scoped + flat indexed)

    /// One element of a bound collection: resolves column keys to final text
    /// regardless of the resolution mode behind it.
    public struct RowHandle {
        public let text: ( _ key: String, _ hint: String? ) -> String?
        public let rows: ( _ path: String, _ probeKeys: [String] ) -> [RowHandle]?
    }

    /// Resolves the collection at `path` in scoped mode when the provider
    /// implements items(forPath:), otherwise in flat indexed mode
    /// (`<path>.<index>.<key>`) using count(forPath:) or probing with
    /// `probeKeys` (a row exists while any key resolves).
    public func rows ( at path: String, probeKeys: [String] ) -> [RowHandle] {
        guard let provider = provider else {
            issues.append( "unresolved collection '\(path)': no data provider" )
            return []
        }
        return LayoutDecoder.rows( at: path, probeKeys: probeKeys, provider: provider
                                 , maxProbedRows: maxProbedRows, issues: &issues )
    }

    static func rows ( at path: String, probeKeys: [String], provider: LayoutDataProvider
                     , maxProbedRows: Int, issues: inout [String] ) -> [RowHandle] {

        if let scoped = provider.items( forPath: path ) {
            return scoped.map { element in handle( for: element, maxProbedRows: maxProbedRows ) }
        }

        // Flat indexed mode
        var count = provider.count( forPath: path )

        if count == nil {
            var probed = 0
            while probed < maxProbedRows {
                let row_path = "\(path).\(probed)"
                let exists = probeKeys.contains { provider.text( forPath: "\(row_path).\($0)", hint: nil ) != nil }
                if !exists { break }
                probed += 1
            }
            if probed == maxProbedRows {
                issues.append( "collection '\(path)': probing stopped at \(maxProbedRows) rows" )
            }
            count = probed
        }

        return ( 0 ..< count! ).map { index in
            flatHandle( base: "\(path).\(index)", provider: provider, maxProbedRows: maxProbedRows )
        }
    }

    static func handle ( for element: LayoutDataProvider, maxProbedRows: Int ) -> RowHandle {
        RowHandle(
            text: { key, hint in element.text( forPath: key, hint: hint ) },
            rows: { path, probeKeys in
                var ignored: [String] = []
                return rows( at: path, probeKeys: probeKeys, provider: element
                           , maxProbedRows: maxProbedRows, issues: &ignored )
            }
        )
    }

    static func flatHandle ( base: String, provider: LayoutDataProvider, maxProbedRows: Int ) -> RowHandle {
        RowHandle(
            text: { key, hint in provider.text( forPath: "\(base).\(key)", hint: hint ) },
            rows: { path, probeKeys in
                var ignored: [String] = []
                return rows( at: "\(base).\(path)", probeKeys: probeKeys, provider: provider
                           , maxProbedRows: maxProbedRows, issues: &ignored )
            }
        )
    }

    /// Count of a collection, honoring scoped mode first. Returns nil when it
    /// cannot be determined without probing.
    public func countOfCollection ( at path: String ) -> Int? {
        guard let provider = provider else { return nil }
        if let scoped = provider.items( forPath: path ) { return scoped.count }
        return provider.count( forPath: path )
    }
}
