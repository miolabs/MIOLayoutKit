//
//  LayoutRenderHandlers.swift
//  MIOLayoutKit
//
//  Extension point for renderers: draw (and optionally measure) custom node types
//  without editing the renderer. A library or app registers a handler for its item
//  class and a renderer class:
//
//      LayoutRenderHandlers.shared.register( SignatureBox.self, renderer: HTMLRender.self ) { box, html in
//          html.appendRaw( "<div class=\"signature\">…</div>" )
//      }
//
//  Lookup walks the item's class chain (most specific first) through custom classes
//  only: a handler for a custom base class serves its custom subclasses, but a
//  MIOLayoutKit type (LayoutItem, VStack, Page, …) matches only a handler registered for
//  exactly that type, so a handler for LayoutItem never takes over pages or stacks. For
//  each item class the renderer's class chain is walked, so a handler registered for a
//  base renderer class (even RenderContext) serves its subclasses. Items without a
//  handler render as before; custom item types without one are reported in
//  `RenderContext.issues`.
//

import Foundation
import MIOCore

public final class LayoutRenderHandlers: @unchecked Sendable {

    public static let shared = LayoutRenderHandlers( )

    struct Key: Hashable {
        let item: ObjectIdentifier
        let renderer: ObjectIdentifier
    }

    struct Entry {
        let render: ( LayoutItem, RenderContext ) -> Void
        let measure: ( ( LayoutItem, RenderContext ) -> Size )?
    }

    private let lock = NSLock( )
    private var entries: [Key:Entry] = [:]

    public init ( ) { }

    /// Registers how `renderer` draws items of class `item` (and its subclasses without a
    /// handler of their own). `measure`, when given, replaces the renderer's measurement.
    public func register<T: LayoutItem, R: RenderContext> ( _ item: T.Type
                                                         , renderer: R.Type
                                                         , measure: ( @Sendable ( T, R ) -> Size )? = nil
                                                         , render: @escaping @Sendable ( T, R ) -> Void ) {
        let entry = Entry(
            render: { i, r in render( i as! T, r as! R ) },
            measure: measure.map { m in { i, r in m( i as! T, r as! R ) } }
        )
        lock.withLock { entries[ Key( item: ObjectIdentifier( item ), renderer: ObjectIdentifier( renderer ) ) ] = entry }
    }

    public func unregister<T: LayoutItem, R: RenderContext> ( _ item: T.Type, renderer: R.Type ) {
        _ = lock.withLock { entries.removeValue( forKey: Key( item: ObjectIdentifier( item ), renderer: ObjectIdentifier( renderer ) ) ) }
    }

    func entry ( for item: LayoutItem, renderer: RenderContext ) -> Entry? {
        lock.withLock {
            if entries.isEmpty { return nil }
            var itemClass: AnyClass? = type( of: item )
            while let ic = itemClass {
                var rendererClass: AnyClass? = type( of: renderer )
                while let rc = rendererClass {
                    if let e = entries[ Key( item: ObjectIdentifier( ic ), renderer: ObjectIdentifier( rc ) ) ] { return e }
                    rendererClass = MCRuntime.superclass( of: rc )
                }
                if isBuiltIn( ic ) { break }      // built-in types: exact registrations only
                itemClass = MCRuntime.superclass( of: ic )
            }
            return nil
        }
    }
}

/// Whether `c` is a MIOLayoutKit type. Cached per class: it runs for every rendered item.
func isBuiltIn ( _ c: AnyClass ) -> Bool {
    BuiltInTypes.shared.contains( c )
}

final class BuiltInTypes: @unchecked Sendable {
    static let shared = BuiltInTypes( )
    private let lock = NSLock( )
    private var cache: [ObjectIdentifier:Bool] = [:]

    func contains ( _ c: AnyClass ) -> Bool {
        let id = ObjectIdentifier( c )
        if let known = lock.withLock( { cache[ id ] } ) { return known }
        let builtIn = String( reflecting: c ).hasPrefix( "MIOLayoutKit." )
        lock.withLock { cache[ id ] = builtIn }
        return builtIn
    }
}

extension RenderContext {

    /// Draws `item` with a registered handler. Returns false when there is none.
    package func renderWithHandler ( _ item: LayoutItem ) -> Bool {
        guard let entry = renderHandlers.entry( for: item, renderer: self ) else {
            noteUnhandledCustomType( item )
            return false
        }
        entry.render( item, self )
        return true
    }

    package func measureWithHandler ( _ item: LayoutItem ) -> Size? {
        guard let measure = renderHandlers.entry( for: item, renderer: self )?.measure else { return nil }
        return measure( item, self )
    }

    private func noteUnhandledCustomType ( _ item: LayoutItem ) {
        if isBuiltIn( type( of: item ) ) { return }        // built-in types: the renderer draws them
        let name = String( reflecting: type( of: item ) )
        let issue = "\(name) has no handler for \(String( reflecting: type( of: self ) )); drawn as a plain item"
        if !issues.contains( issue ) { issues.append( issue ) }
    }
}
