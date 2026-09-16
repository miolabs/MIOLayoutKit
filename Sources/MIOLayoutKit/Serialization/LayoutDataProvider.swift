//
//  LayoutDataProvider.swift
//  MIOLayoutKit
//
//  Pull-based value resolution for serialized layouts. The decoder calls the
//  provider lazily whenever it meets a dynamic node; providers return final,
//  already-formatted display strings.
//

import Foundation


public enum LayoutImageSource {
    case url( String )
    case data( Data )
}


public protocol LayoutDataProvider: AnyObject {

    /// REQUIRED. Final, already-formatted display string for a path.
    /// `hint` is the pass-through format hint from the template ("short", ...);
    /// providers are free to ignore it. Return nil when the path is unknown.
    func text ( forPath path: String, hint: String? ) -> String?

    /// For `visibleIf`. Default: false.
    func bool ( forPath path: String ) -> Bool

    /// For dynamic images (logo, QR). Default: nil.
    func image ( forPath path: String ) -> LayoutImageSource?

    /// Scoped collection resolution: each element is itself a provider scoped
    /// to that element, so table column keys resolve against it.
    /// Default: nil, which makes the decoder fall back to flat indexed
    /// resolution (`<path>.<index>.<key>` against this provider).
    func items ( forPath path: String ) -> [LayoutDataProvider]?

    /// Number of elements of a collection, for flat indexed resolution.
    /// Default: nil, which makes the decoder probe ascending indices until a
    /// row where every column resolves to nil.
    func count ( forPath path: String ) -> Int?
}


public extension LayoutDataProvider {
    func bool  ( forPath path: String ) -> Bool { false }
    func image ( forPath path: String ) -> LayoutImageSource? { nil }
    func items ( forPath path: String ) -> [LayoutDataProvider]? { nil }
    func count ( forPath path: String ) -> Int? { nil }
}


// MARK: - Dictionary provider

/// Reference `LayoutDataProvider` backed by a nested `[String:Any]` of
/// pre-formatted values. Used by tests, template validation and editor
/// previews. Answers both scoped and flat indexed resolution: numeric path
/// components index into arrays.
public final class DictionaryDataProvider: LayoutDataProvider {

    let values: [String:Any]

    public init ( _ values: [String:Any] ) {
        self.values = values
    }

    func value ( forPath path: String ) -> Any? {
        var current: Any = values

        for component in path.split( separator: "." ) {
            if let dict = current as? [String:Any] {
                guard let next = dict[ String( component ) ] else { return nil }
                current = next
            }
            else if let array = current as? [Any], let index = Int( component ) {
                guard index >= 0 && index < array.count else { return nil }
                current = array[ index ]
            }
            else {
                return nil
            }
        }

        return current
    }

    public func text ( forPath path: String, hint: String? ) -> String? {
        guard let v = value( forPath: path ) else { return nil }
        if let s = v as? String { return s }
        if v is [String:Any] || v is [Any] { return nil }
        return "\(v)"
    }

    public func bool ( forPath path: String ) -> Bool {
        guard let v = value( forPath: path ) else { return false }
        if let b = v as? Bool   { return b }
        // Presence semantics: visibleIf on a text path shows the node when
        // there is something to show.
        if let s = v as? String { return !s.isEmpty && s != "false" && s != "0" }
        if let n = v as? Int    { return n != 0 }
        return true
    }

    public func image ( forPath path: String ) -> LayoutImageSource? {
        guard let v = value( forPath: path ) else { return nil }
        if let url  = v as? String { return .url( url ) }
        if let data = v as? Data   { return .data( data ) }
        return nil
    }

    public func items ( forPath path: String ) -> [LayoutDataProvider]? {
        guard let array = value( forPath: path ) as? [Any] else { return nil }

        return array.map {
            if let dict = $0 as? [String:Any] { return DictionaryDataProvider( dict ) }
            return DictionaryDataProvider( [ "value": $0 ] )
        }
    }

    public func count ( forPath path: String ) -> Int? {
        ( value( forPath: path ) as? [Any] )?.count
    }
}
