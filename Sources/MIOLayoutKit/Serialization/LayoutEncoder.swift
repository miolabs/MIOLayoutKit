//
//  LayoutEncoder.swift
//  MIOLayoutKit
//
//  Encodes a layout tree into the serialized JSON template format. Decode is
//  the product; encode is the toolchain — it seeds default templates from
//  layouts built in code and powers round-trip tests.
//

import Foundation


public final class LayoutEncoder {

    public let registry: LayoutNodeRegistry
    public var prettyPrinted = true

    public init ( registry: LayoutNodeRegistry = .standard ) {
        self.registry = registry
    }

    public func encode ( _ page: Page, documentType: String? = nil, name: String? = nil ) throws -> Data {
        var paper: String? = nil
        if page.size.width == A4.portraitSize.width && page.size.height == A4.portraitSize.height {
            paper = "a4-portrait"
        }
        else if page.size.width == A4.landscapeSize.width && page.size.height == A4.landscapeSize.height {
            paper = "a4-landscape"
        }

        var margins: LayoutTemplateDocument.MarginValues? = nil
        let m = page.margins
        if m.top != 0 || m.right != 0 || m.bottom != 0 || m.left != 0 {
            margins = LayoutTemplateDocument.MarginValues( top: m.top, right: m.right, bottom: m.bottom, left: m.left )
        }

        let root: LayoutNode
        if page.children.count == 1 {
            root = try encodeItem( page.children[ 0 ] )
        }
        else {
            var wrapper = LayoutNode( type: "vstack" )
            wrapper.children = try page.children.map { try encodeItem( $0 ) }
            root = wrapper
        }

        let document = LayoutTemplateDocument( formatVersion: LayoutTemplateFormatVersion
                                             , documentType: documentType
                                             , name: name
                                             , paper: paper
                                             , margins: margins
                                             , header: try page.header.map { try encodeItem( $0 ) }
                                             , footer: try page.footer.map { try encodeItem( $0 ) }
                                             , root: root )

        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [ .prettyPrinted, .sortedKeys ] : [ .sortedKeys ]
        return try encoder.encode( document )
    }

    public func encodeItem ( _ item: LayoutItem ) throws -> LayoutNode {
        for coder in registry.encodeOrder {
            if var node = try coder.encode?( item, self ) {
                applyCommon( item, &node )
                return node
            }
        }
        throw LayoutSerializationError.unsupportedItem( "\(type( of: item ))" )
    }

    func applyCommon ( _ item: LayoutItem, _ node: inout LayoutNode ) {
        if item.flex != 0 { node.properties[ "flex" ] = .int( item.flex ) }
        if let id = item.id { node.properties[ "id" ] = .string( id ) }
        if item.is_unbreakable { node.properties[ "unbreakable" ] = .bool( true ) }
        if item.include_in_pages != .here {
            node.properties[ "includeInPages" ] = .string( item.include_in_pages.name )
        }
        if let style = LayoutStyleCoding.encode( item.style ) {
            node.properties[ "style" ] = style
        }
    }
}
