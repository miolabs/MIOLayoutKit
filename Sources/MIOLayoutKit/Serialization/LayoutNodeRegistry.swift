//
//  LayoutNodeRegistry.swift
//  MIOLayoutKit
//
//  Extension points of the serialized format: node coders and reusable
//  fragments. Custom node types registered from other libraries or apps must
//  use a reverse prefix ("dl.", "pos.", ...); unprefixed types are reserved
//  for MIOLayoutKit.
//

import Foundation


/// Encoder/decoder pair for one node type. Decode is looked up by `nodeType`;
/// encode candidates are tried in registration order (most specific first)
/// and return nil for items they don't handle.
public struct LayoutNodeCoder {
    public let nodeType: String
    public let decode: ( LayoutNode, LayoutDecoder ) throws -> LayoutItem
    public let encode: ( ( LayoutItem, LayoutEncoder ) throws -> LayoutNode? )?

    public init ( nodeType: String
                , decode: @escaping ( LayoutNode, LayoutDecoder ) throws -> LayoutItem
                , encode: ( ( LayoutItem, LayoutEncoder ) throws -> LayoutNode? )? = nil ) {
        self.nodeType = nodeType
        self.decode = decode
        self.encode = encode
    }
}


public final class LayoutNodeRegistry {

    public static let standard = LayoutNodeRegistry( standardCoders: true )

    var decoders: [String:LayoutNodeCoder] = [:]
    var encodeOrder: [LayoutNodeCoder] = []

    public init ( standardCoders: Bool = true ) {
        if standardCoders {
            for coder in LayoutStandardCoders.all { register( coder, prepend: false ) }
        }
    }

    /// Registers a coder. Custom coders are prepended so their encode matcher
    /// runs before the standard ones (subclass coders must win).
    public func register ( _ coder: LayoutNodeCoder, prepend: Bool = true ) {
        decoders[ coder.nodeType ] = coder
        if coder.encode != nil {
            if prepend { encodeOrder.insert( coder, at: 0 ) }
            else       { encodeOrder.append( coder ) }
        }
    }

    public func decoder ( for nodeType: String ) -> LayoutNodeCoder? {
        decoders[ nodeType ]
    }
}


/// Named, reusable layout fragments referenced from templates with
/// `"ref": "<name>"`. Register shared blocks (company header, legal entity
/// block, ...) once and reference them from every template.
public final class LayoutFragmentLibrary {

    public static let standard = LayoutFragmentLibrary()

    var fragments: [String:LayoutNode] = [:]

    public init ( ) { }

    public func register ( _ name: String, node: LayoutNode ) {
        fragments[ name ] = node
    }

    public func register ( _ name: String, json: Data ) throws {
        let node = try JSONDecoder().decode( LayoutNode.self, from: json )
        register( name, node: node )
    }

    public func fragment ( _ name: String ) -> LayoutNode? {
        fragments[ name ]
    }
}
