//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

public enum SizeGrowDirection: Int16 {
    case horizontal = 0
    case vertical   = 1
    case both       = 2
}


@objc public enum ItemSize: Int {
    case none = 0
    case xxs  = 1
    case xs   = 2
    case s    = 3
    case m    = 4
    case l    = 5
    case xl   = 6
    case xxl  = 7
    case h    = 8 // huge
}


public enum IncludeInPage: Int {
    case all  = 3
    case even = 2
    case odd  = 1
    case here = 0
}


public func should_include ( _ pageNumber: Int, _ inc: IncludeInPage ) -> Bool {
    if inc == .here { return false }
    
    if inc == .all  { return true  }
    
    if (pageNumber & 1) == 0 {
        if inc == .even {
            return true
        }
    } else if inc == .odd {
        return true
    }
 
    return false
}


public struct Size {
    var width : Float = 0
    var height: Float = 0
    
    public init( width: Float = 0, height: Float = 0 ) {
        self.width  = width
        self.height = height
    }
        
    public func join ( _ s: Size, _ dir: SizeGrowDirection ) -> Size {
        return Size( width:  dir == .horizontal ? width  + s.width        : max( width , s.width )
                   , height: dir == .horizontal ? max( height, s.height ) : height + s.height )
    }
}


public class Edges<T> {
    public var top: T
    public var right: T
    public var bottom: T
    public var left: T
    
    init (  _ t: T, _ r: T, _ b: T, _ l: T ) {
        top = t
        right = r
        bottom = b
        left = l
    }
}


public class BorderWidth: Edges<Int> {
    override public init (  _ t: Int = 0, _ r: Int = 0, _ b: Int = 0, _ l: Int = 0 ) {
        super.init( t, r, b, l )
    }
}


public class BorderColor: Edges<String?> {
    override public init ( _ t: String? = nil
                         , _ r: String? = nil
                         , _ b: String? = nil
                         , _ l: String? = nil ) {
        super.init( t, r, b, l )
    }
}

public class Margin: Edges<Float> {
    override public init (  _ t: Float = 0, _ r: Float = 0, _ b: Float = 0, _ l: Float = 0 ) {
        super.init( t, r, b, l )
    }
}


public class EdgeSizes: Edges<ItemSize> {
    public init ( top:    ItemSize = .none
                , right:  ItemSize = .none
                , bottom: ItemSize = .none
                , left:   ItemSize = .none ) {
        super.init( top, right, bottom, left )
    }
}


public class Style {
    public var borderWidth: BorderWidth
    public var borderColor: BorderColor
    public var fgColor: String?
    public var bgColor: String?
    public var borderRadius: Int = 0
    
    public init ( ) {
        borderWidth = BorderWidth( )
        borderColor = BorderColor( )
    }
    
    open func copyValues ( _ ret: Style ) {
        fgColor = ret.fgColor
        bgColor = ret.bgColor
        borderColor = ret.borderColor
        borderWidth = ret.borderWidth
        borderRadius = ret.borderRadius
    }
}


public class FontStyle: Style {
    var color: String?
    var family: String?
    var size: Int?
    var weight: Int?
}


public class Constraint {
    var width: Decimal?
    var height: Decimal?
    
    init ( width: Decimal? = nil, height: Decimal? = nil ) {
        self.width  = width
        self.height = height
    }
}


public enum FormatterType {
    case string
    case number
    case decimal
    case currency
    case percentage
    case shortDate
    case shortDateTime
    case longDate
    case longDateTime
    case time
}

public struct Vector2D {
    var x: Float
    var y: Float
}

open class RenderContext {
    var fgColor: String
    var bgColor: String
    var font: FontStyle
    var x: Float
    var y: Float
    var contraintStack: [Constraint]
    var containerStack: [Container<LayoutItem>]
    var translations: [String:String]
    var currentPageNumber: Int
    var currentPage: Page?
    
    public init ( _ trans: [String:String] = [:] ) {
        fgColor = "#000000"
        bgColor = "#FFFFFF"
        font = FontStyle( )
        x = 0
        y = 0
        contraintStack = []
        containerStack = []
        translations = trans
        currentPageNumber = 0
    }
            
    open func beginCoords ( ) -> Vector2D { return Vector2D( x: 0, y: 0 ) }
    open func hasBegan ( ) -> Bool { return containerStack.count > 0 }
    open func beginRender ( _ root: Page ) { containerStack = [root] }
    open func endRender ( ) { }
    
    open func meassure ( _ item: LayoutItem ) -> Size { return Size( width: 0, height: 0 ) }
    
    open func renderItem ( _ item: LayoutItem ) { }
    
    open func beginContainer ( _ container: Container<LayoutItem> ) {
        containerStack.append( container )
    }
    
    open func endContainer ( _ container: Container<LayoutItem> ) {
        _ = containerStack.popLast()
    }
    
    open func output ( ) -> Data { return Data( ) }
    
    open func setResourcesPath( _ path:String ) { }
        
    open func beginPage ( _ page: Page ) { currentPage = page }
    open func endPage   ( _ page: Page ) { currentPageNumber += 1 }
    
    // MARK: - Translations
    
    open func translate_container ( _ c: Container<LayoutItem> ) {
        for child in c.children {
            if let text = child as? LocalizedText {
                text.apply_translation( self.translations )
            }
            else if let cont = child as? Container {
                cont.translate_container( self.translations )
            }
        }
        
    }
    
    public func localizedString( _ key: String ) -> String {
        self.translations[ key ] ?? key
    }
    
    // MARK: - Conversion types
    
    var locale_id:String = "es_ES"
    open var localeIdentifier:String {
        set { locale_id = newValue }
        get { return locale_id }
    }
    
    var currency_formatter:NumberFormatter? = nil
    var currencyFromatter:NumberFormatter { get {
        if currency_formatter != nil { return currency_formatter! }
        
        currency_formatter = NumberFormatter()
        currency_formatter!.locale = Locale(identifier: locale_id )
        currency_formatter!.numberStyle = .currency
//        currency_formatter!.numberStyle = .decimal
        // PDFLib 7 not print with Euro symbol
//        currency_formatter!.currencySymbol = ""
        currency_formatter!.minimumFractionDigits = 2
        currency_formatter!.maximumFractionDigits = 2
       
        return currency_formatter!
    } }
    
    open func stringCurrency ( from value: NSDecimalNumber? ) -> String {
        let number = NSNumber( floatLiteral: value?.doubleValue ?? 0 )
//        return currencyFromatter.string(from: number)!.trimmingCharacters(in: .whitespacesAndNewlines) + " €" //+ currencyFromatter.currencySymbol!
        return currencyFromatter.string(from: number)!
    }
    
    open func stringCurrency ( from value: Decimal? ) -> String {
        let d = NSDecimalNumber(decimal: value ?? 0)
        return stringCurrency(from: d )
    }
    
    var number_formatter:NumberFormatter? = nil
    var numberFormatter:NumberFormatter { get {
        if number_formatter != nil { return number_formatter! }
        
        number_formatter = NumberFormatter()
        number_formatter!.locale = Locale(identifier: locale_id )
        number_formatter!.numberStyle = .decimal
        number_formatter!.minimumFractionDigits = 0
        number_formatter!.maximumFractionDigits = 2
       
        return number_formatter!
    } }
    
    open func stringNumber ( from value: NSDecimalNumber? ) -> String {
//        let number = NSNumber( floatLiteral: d )
//        numberFormatter.minimumFractionDigits = floor( d ) == d ? 0 : 2
        return numberFormatter.string(from: value ?? 0 )!
    }
    
    open func stringNumber ( from value: Decimal? ) -> String {
        let d = NSDecimalNumber(decimal: value ?? 0)
        return stringNumber( from: d )
    }

    open func stringNumber ( from value: Int? ) -> String {
        let number = NSNumber( integerLiteral: value ?? 0 )
        return numberFormatter.string(from: number)!
    }
    
    var date_formatter:DateFormatter? = nil
    var dateFormatter:DateFormatter { get {
        if date_formatter != nil { return date_formatter! }
        
        date_formatter = DateFormatter()
        date_formatter!.locale = Locale(identifier: locale_id )
        date_formatter!.dateStyle = .short
        date_formatter!.timeStyle = .short
       
        return date_formatter!
    } }
    
    open func stringDate ( from value: Date?, dateStyle: DateFormatter.Style = .short, timeStyle: DateFormatter.Style = .short) -> String {
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string(from: value ?? Date())
    }
 

}
