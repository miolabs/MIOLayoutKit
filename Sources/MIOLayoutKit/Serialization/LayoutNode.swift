//
//  LayoutNode.swift
//  MIOLayoutKit
//
//  Serialized layout format: a versioned JSON tree of typed nodes.
//

import Foundation


public let LayoutTemplateFormatVersion = 1


public enum LayoutSerializationError: Error, CustomStringConvertible {
    case invalidDocument( String )
    case unknownNodeType( String )
    case unknownFragment( String )
    case missingProperty( String, nodeType: String )
    case invalidProperty( String, nodeType: String, expected: String )
    case unsupportedItem( String )

    public var description: String {
        switch self {
        case .invalidDocument( let msg ):  return "Invalid layout document: \(msg)"
        case .unknownNodeType( let t ):    return "Unknown layout node type '\(t)'"
        case .unknownFragment( let n ):    return "Unknown layout fragment '\(n)'"
        case .missingProperty( let p, let t ):        return "Missing property '\(p)' in node '\(t)'"
        case .invalidProperty( let p, let t, let e ): return "Invalid property '\(p)' in node '\(t)': expected \(e)"
        case .unsupportedItem( let cls ):  return "Layout item '\(cls)' has no registered node encoder"
        }
    }
}


// MARK: - JSON value

public enum LayoutNodeValue: Codable, Equatable {
    case string( String )
    case int( Int )
    case double( Double )
    case bool( Bool )
    case array( [LayoutNodeValue] )
    case object( [String:LayoutNodeValue] )
    case null

    public init ( from decoder: Decoder ) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil()                                { self = .null }
        else if let v = try? single.decode( Bool.self )      { self = .bool( v ) }
        else if let v = try? single.decode( Int.self )       { self = .int( v ) }
        else if let v = try? single.decode( Double.self )    { self = .double( v ) }
        else if let v = try? single.decode( String.self )    { self = .string( v ) }
        else if let v = try? single.decode( [LayoutNodeValue].self )        { self = .array( v ) }
        else if let v = try? single.decode( [String:LayoutNodeValue].self ) { self = .object( v ) }
        else {
            throw DecodingError.dataCorruptedError( in: single, debugDescription: "Unsupported JSON value" )
        }
    }

    public func encode ( to encoder: Encoder ) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .string( let v ): try single.encode( v )
        case .int   ( let v ): try single.encode( v )
        case .double( let v ): try single.encode( v )
        case .bool  ( let v ): try single.encode( v )
        case .array ( let v ): try single.encode( v )
        case .object( let v ): try single.encode( v )
        case .null:            try single.encodeNil()
        }
    }

    public var stringValue: String? { if case .string( let v ) = self { return v } else { return nil } }
    public var boolValue:   Bool?   { if case .bool( let v )   = self { return v } else { return nil } }
    public var arrayValue:  [LayoutNodeValue]?        { if case .array( let v )  = self { return v } else { return nil } }
    public var objectValue: [String:LayoutNodeValue]? { if case .object( let v ) = self { return v } else { return nil } }

    public var intValue: Int? {
        switch self {
        case .int( let v ):    return v
        case .double( let v ): return Int( v )
        default:               return nil
        }
    }

    public var floatValue: Float? {
        switch self {
        case .int( let v ):    return Float( v )
        case .double( let v ): return Float( v )
        default:               return nil
        }
    }
}

extension LayoutNodeValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init ( stringLiteral value: String ) { self = .string( value ) }
    public init ( integerLiteral value: Int )   { self = .int( value ) }
    public init ( booleanLiteral value: Bool )  { self = .bool( value ) }
    public init ( floatLiteral value: Double )  { self = .double( value ) }
    public init ( arrayLiteral elements: LayoutNodeValue... ) { self = .array( elements ) }
    public init ( dictionaryLiteral elements: (String, LayoutNodeValue)... ) {
        self = .object( Dictionary( uniqueKeysWithValues: elements ) )
    }
}


// MARK: - Node

/// One node of a serialized layout: a `type` discriminator, type-specific
/// properties and optional children. On the wire the properties are flattened
/// into the same JSON object as `type` and `children`.
public struct LayoutNode: Codable {
    public var type: String
    public var properties: [String:LayoutNodeValue]
    public var children: [LayoutNode]

    public init ( type: String, properties: [String:LayoutNodeValue] = [:], children: [LayoutNode] = [] ) {
        self.type = type
        self.properties = properties
        self.children = children
    }

    public init ( value: LayoutNodeValue ) throws {
        guard let obj = value.objectValue else {
            throw LayoutSerializationError.invalidDocument( "node must be a JSON object" )
        }
        try self.init( object: obj )
    }

    public init ( object: [String:LayoutNodeValue] ) throws {
        guard let type = object[ "type" ]?.stringValue else {
            throw LayoutSerializationError.invalidDocument( "node object has no 'type'" )
        }
        var props = object
        props.removeValue( forKey: "type" )

        var children: [LayoutNode] = []
        if let child_values = props.removeValue( forKey: "children" ) {
            guard let arr = child_values.arrayValue else {
                throw LayoutSerializationError.invalidProperty( "children", nodeType: type, expected: "array of nodes" )
            }
            children = try arr.map { try LayoutNode( value: $0 ) }
        }

        self.type = type
        self.properties = props
        self.children = children
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init? ( stringValue: String ) { self.stringValue = stringValue }
        init? ( intValue: Int ) { return nil }
    }

    public init ( from decoder: Decoder ) throws {
        let value = try LayoutNodeValue( from: decoder )
        try self.init( value: value )
    }

    public func encode ( to encoder: Encoder ) throws {
        var container = encoder.container( keyedBy: DynamicKey.self )
        try container.encode( type, forKey: DynamicKey( stringValue: "type" )! )
        for ( key, value ) in properties {
            try container.encode( value, forKey: DynamicKey( stringValue: key )! )
        }
        if !children.isEmpty {
            try container.encode( children, forKey: DynamicKey( stringValue: "children" )! )
        }
    }

    // MARK: typed accessors

    public func stringIfPresent ( _ key: String ) -> String? { properties[ key ]?.stringValue }
    public func intIfPresent    ( _ key: String ) -> Int?    { properties[ key ]?.intValue }
    public func floatIfPresent  ( _ key: String ) -> Float?  { properties[ key ]?.floatValue }
    public func boolIfPresent   ( _ key: String ) -> Bool?   { properties[ key ]?.boolValue }

    public func string ( _ key: String ) throws -> String {
        guard let v = stringIfPresent( key ) else {
            throw LayoutSerializationError.missingProperty( key, nodeType: type )
        }
        return v
    }

    public func float ( _ key: String ) throws -> Float {
        guard let v = floatIfPresent( key ) else {
            throw LayoutSerializationError.missingProperty( key, nodeType: type )
        }
        return v
    }

    public func int  ( _ key: String, default def: Int  ) -> Int  { intIfPresent( key )  ?? def }
    public func bool ( _ key: String, default def: Bool ) -> Bool { boolIfPresent( key ) ?? def }

    public func objectIfPresent ( _ key: String ) -> [String:LayoutNodeValue]? { properties[ key ]?.objectValue }
    public func arrayIfPresent  ( _ key: String ) -> [LayoutNodeValue]?        { properties[ key ]?.arrayValue }

    public func nodeIfPresent ( _ key: String ) throws -> LayoutNode? {
        guard let v = properties[ key ] else { return nil }
        return try LayoutNode( value: v )
    }

    func itemSize ( _ key: String, default def: ItemSize ) throws -> ItemSize {
        guard let name = stringIfPresent( key ) else { return def }
        guard let size = ItemSize( name: name ) else {
            throw LayoutSerializationError.invalidProperty( key, nodeType: type, expected: "one of \(ItemSize.names)" )
        }
        return size
    }

    func textAlign ( _ key: String, default def: TextAlign ) throws -> TextAlign {
        guard let name = stringIfPresent( key ) else { return def }
        switch name {
        case "left":   return .left
        case "center": return .center
        case "right":  return .right
        default: throw LayoutSerializationError.invalidProperty( key, nodeType: type, expected: "left|center|right" )
        }
    }

    func textWrap ( _ key: String, default def: TextWrap ) throws -> TextWrap {
        guard let name = stringIfPresent( key ) else { return def }
        switch name {
        case "wrap":   return .wrap
        case "nowrap": return .noWrap
        default: throw LayoutSerializationError.invalidProperty( key, nodeType: type, expected: "wrap|nowrap" )
        }
    }

    func imageAlign ( _ key: String, default def: ImageAlign ) throws -> ImageAlign {
        guard let name = stringIfPresent( key ) else { return def }
        switch name {
        case "left":   return .left
        case "center": return .center
        case "right":  return .right
        default: throw LayoutSerializationError.invalidProperty( key, nodeType: type, expected: "left|center|right" )
        }
    }

    func includeInPages ( _ key: String, default def: IncludeInPage ) throws -> IncludeInPage {
        guard let name = stringIfPresent( key ) else { return def }
        switch name {
        case "all":  return .all
        case "even": return .even
        case "odd":  return .odd
        case "here": return .here
        default: throw LayoutSerializationError.invalidProperty( key, nodeType: type, expected: "all|even|odd|here" )
        }
    }
}


// MARK: - Enum names

extension ItemSize {
    static let names = [ "none", "xxs", "xs", "s", "m", "l", "xl", "xxl", "h" ]

    init? ( name: String ) {
        guard let index = ItemSize.names.firstIndex( of: name ) else { return nil }
        self.init( rawValue: index )
    }

    var name: String { ItemSize.names[ rawValue ] }
}

extension TextAlign  { var name: String { [ "left", "center", "right" ][ rawValue ] } }
extension ImageAlign { var name: String { [ "left", "center", "right" ][ rawValue ] } }
extension TextWrap   { var name: String { [ "wrap", "nowrap" ][ rawValue ] } }

extension IncludeInPage {
    var name: String {
        switch self {
        case .all: return "all"; case .even: return "even"; case .odd: return "odd"; case .here: return "here"
        }
    }
}


// MARK: - Style

enum LayoutStyleCoding {

    static func decode ( _ obj: [String:LayoutNodeValue], into style: Style, nodeType: String ) throws {
        if let v = obj[ "fgColor" ]?.stringValue { style.fgColor = v }
        if let v = obj[ "bgColor" ]?.stringValue { style.bgColor = v }
        if let v = obj[ "borderRadius" ]?.intValue { style.borderRadius = v }

        if let bw = obj[ "borderWidth" ] {
            if let all = bw.intValue {
                style.borderWidth = BorderWidth( all, all, all, all )
            }
            else if let edges = bw.objectValue {
                style.borderWidth = BorderWidth( edges[ "top"    ]?.intValue ?? 0
                                               , edges[ "right"  ]?.intValue ?? 0
                                               , edges[ "bottom" ]?.intValue ?? 0
                                               , edges[ "left"   ]?.intValue ?? 0 )
            }
            else {
                throw LayoutSerializationError.invalidProperty( "style.borderWidth", nodeType: nodeType, expected: "int or edges object" )
            }
        }

        if let bc = obj[ "borderColor" ] {
            if let all = bc.stringValue {
                style.borderColor = BorderColor( all, all, all, all )
            }
            else if let edges = bc.objectValue {
                style.borderColor = BorderColor( edges[ "top"    ]?.stringValue
                                               , edges[ "right"  ]?.stringValue
                                               , edges[ "bottom" ]?.stringValue
                                               , edges[ "left"   ]?.stringValue )
            }
            else {
                throw LayoutSerializationError.invalidProperty( "style.borderColor", nodeType: nodeType, expected: "string or edges object" )
            }
        }
    }

    static func encode ( _ style: Style ) -> LayoutNodeValue? {
        var obj: [String:LayoutNodeValue] = [:]

        if let v = style.fgColor { obj[ "fgColor" ] = .string( v ) }
        if let v = style.bgColor { obj[ "bgColor" ] = .string( v ) }
        if style.borderRadius != 0 { obj[ "borderRadius" ] = .int( style.borderRadius ) }

        let bw = style.borderWidth
        if bw.top != 0 || bw.right != 0 || bw.bottom != 0 || bw.left != 0 {
            if bw.top == bw.right && bw.top == bw.bottom && bw.top == bw.left {
                obj[ "borderWidth" ] = .int( bw.top )
            }
            else {
                obj[ "borderWidth" ] = .object( [ "top": .int( bw.top ), "right": .int( bw.right )
                                                , "bottom": .int( bw.bottom ), "left": .int( bw.left ) ] )
            }
        }

        let bc = style.borderColor
        let colors = [ bc.top, bc.right, bc.bottom, bc.left ]
        if colors.contains( where: { $0 != nil } ) {
            if let first = bc.top, colors.allSatisfy( { $0 == first } ) {
                obj[ "borderColor" ] = .string( first )
            }
            else {
                var edges: [String:LayoutNodeValue] = [:]
                if let v = bc.top    { edges[ "top"    ] = .string( v ) }
                if let v = bc.right  { edges[ "right"  ] = .string( v ) }
                if let v = bc.bottom { edges[ "bottom" ] = .string( v ) }
                if let v = bc.left   { edges[ "left"   ] = .string( v ) }
                obj[ "borderColor" ] = .object( edges )
            }
        }

        return obj.isEmpty ? nil : .object( obj )
    }
}
