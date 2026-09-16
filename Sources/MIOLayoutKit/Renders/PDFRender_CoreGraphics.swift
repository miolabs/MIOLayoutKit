//
//  PDFRender_CoreGraphics.swift
//  
//
//  Created by Jorge Barbero on 13/6/23.
//

#if os(iOS)

import Foundation
import MIOCore
import UIKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


public class PDFRender_CoreGraphics: RenderContext
{
    var _default_font:UIFont = UIFont.systemFont( ofSize: UIFont.systemFontSize )
    
    public var defaultFont:UIFont {
        get { return _default_font }
        set { _default_font = newValue }
    }

    public func setFont( name:String ) {
        let f = UIFont(name: name, size: 10)
        _default_font = f ?? UIFont.systemFont( ofSize: UIFont.systemFontSize )
    }

    public func font( size: CGFloat, bold:Bool = false, italic:Bool = false ) -> UIFont {
        var traits = UIFontDescriptor.SymbolicTraits()
        if bold { traits.insert( .traitBold ) }
        if italic { traits.insert( .traitItalic ) }
        guard let fd = _default_font.fontDescriptor.withSymbolicTraits( traits ) else {
            return _default_font.withSize( size )
        }
        
        return UIFont(descriptor: fd, size: size )
    }
    
    
    var context:CGContext!
    var renderData = NSMutableData()
        
    var pageMargin: Margin = Margin( )
    
    var offsetY:Float = 0
    
    var resourcesPath:String?
    public override func setResourcesPath( _ path: String ) {
        resourcesPath = path
    }
    
    public override func beginCoords ( ) -> Vector2D {
        return Vector2D( x: 0, y: Float( currentPageNumber + 1 ) * (currentPage?.size.height ?? 0))
    }
    
    public override func beginRender(_ root: Page ) {
        super.beginRender(root)
                        
//        try? pdf.beginDocument( )
        if resourcesPath != nil {
//            pdf.setParameter(key: "SearchPath", value: resourcesPath!)
        }
        
//        defaultFont = (try? pdf.loadFont(name: "Helvetica", encoding: "winansi" ) ) ?? -1
//        defaultFontBold = (try? pdf.loadFont(name: "Helvetica-Bold", encoding: "winansi") ) ?? -1
        
        pageMargin = root.margins
//        offsetY = A4.size.height - root.margins.top - root.margins.bottom
        UIGraphicsBeginPDFContextToData( renderData, CGRect(origin: CGPoint(), size: CGSize( width: Double( root.size.width ), height: Double( root.size.height ) ) ), nil )
        
        context = UIGraphicsGetCurrentContext()
        
    }
    
    
    
    public override func endRender() {
        super.endRender()
        
//        pdf.endDocument()
//        renderData = pdf.pdfData()
        
        UIGraphicsEndPDFContext()
    }
    
    public override func output() -> Data {
        return renderData as Data
    }
            
    public override func beginContainer(_ container: Container<LayoutItem>) {
        super.beginContainer(container)
        
        if container is A4 {
//            pdf.setFont( defaultFont, size: defaultFontSize )
//            pdf.setParameter(key: "stringformat", value: "utf8")
        }
        else if let table = container as? Table {
            
            if !table.hideHeader {
                let header = table.header!.children

                rect( table.header! )

                for h in header {
                    h.render( self )
                }
            }

            for row in table.body.children {
                for col in (row as! HStack).children {
                    col.render( self )
                }
            }
            
            if !table.hideFooter {
                rect( table.footer! )
                
                for col in table.footer!.children {
                    col.render( self )
                }
            }
        }
        else {
            rect( container )
        }

    }
    
    
    public func rect ( _ item: LayoutItem ) {
        defer {
            setColor( "#000000", "fillstroke")
        }
        
        let p = pos( item )
        let bg = item.style.bgColor
        let fg = item.style.fgColor
        let t = item.style.borderWidth.top
        let b = item.style.borderWidth.bottom
        let r = item.style.borderWidth.right
        let l = item.style.borderWidth.left
        
        if bg != nil {
            setColor( bg )
            UIRectFill( CGRect(x: p.x, y: p.y, width: Double( item.dimensions.width  ), height: Double( item.dimensions.height ) ) )
//            pdf.rect( x: p.x
//                    , y: p.y
//                    , width:  Double( item.dimensions.width  )
//                    , height: Double( item.dimensions.height ) )
//            pdf.fill()
        }
                
        //TODO: Hack to render rounded rectangle only with all the border > 0
        if t > 0 && l > 0 && b > 0 && r > 0 && item.style.borderRadius > 0 {
            setColor( fg, "stroke" )
            //let rdx = Double( item.style.borderRadius )
            _ = Double( item.style.borderRadius )
//            pdf.moveTo( x: p.x + rdx, y: p.y)
//            pdf.lineTo( x: p.x + Double( item.dimensions.width ) - rdx, y: p.y )
//            pdf.arc   ( x: p.x + Double( item.dimensions.width ) - rdx, y: p.y + rdx, radius: rdx, alpha: 270, beta: 360 )
//            pdf.lineTo( x: p.x + Double( item.dimensions.width ), y: p.y - rdx + Double( item.dimensions.height ) )
//            pdf.arc   ( x: p.x + Double( item.dimensions.width ) - rdx , y: p.y - rdx + Double( item.dimensions.height ), radius: rdx, alpha: 0, beta: 90 )
//            pdf.lineTo( x: p.x + rdx, y: p.y + Double( item.dimensions.height ) )
//            pdf.arc   ( x: p.x + rdx, y: p.y - rdx + Double( item.dimensions.height ), radius: rdx, alpha: 90, beta: 180 )
//            pdf.lineTo( x: p.x, y: p.y + rdx )
//            pdf.arc   ( x: p.x + rdx, y: p.y + rdx, radius: rdx, alpha: 180, beta: 270 )
//            pdf.stroke()
            return
        }
        
        if t > 0 {
            setColor( item.style.borderColor.top ?? fg )
            UIRectFill( CGRect(x: p.x,
                               y: p.y + Double( item.dimensions.height ) - Double( t ),
                               width: Double( item.dimensions.width  ),
                               height: Double( t ) )
                      )

//            pdf.rect( x: p.x
//                    , y: p.y + Double( item.dimensions.height ) - Double( t )
//                    , width:  Double( item.dimensions.width  )
//                    , height: Double( t ) )
//            pdf.fill()
        }

        if l > 0 {
            setColor( item.style.borderColor.left ?? fg )
            UIRectFill( CGRect(x: p.x,
                               y: p.y,
                               width: Double( l ),
                               height: Double( item.dimensions.height ) )
                      )

//            pdf.rect( x: p.x
//                    , y: p.y
//                    , width:  Double( l )
//                    , height: Double( item.dimensions.height ) )
//            pdf.fill()
        }
        
        if b > 0 {
            setColor( item.style.borderColor.bottom ?? fg )
            UIRectFill( CGRect(x: p.x,
                               y: p.y,
                               width: Double( item.dimensions.width ),
                               height: Double( b ) )
                      )

//            pdf.rect( x: p.x
//                    , y: p.y
//                    , width:  Double( item.dimensions.width  )
//                    , height: Double( b ) )
//            pdf.fill()
        }

        if r > 0 {
            setColor( item.style.borderColor.right ?? fg )
            UIRectFill( CGRect(x: p.x + Double( item.dimensions.width ) - Double( r ),
                               y: p.y,
                               width: Double( r ),
                               height: Double( item.dimensions.height ) )
                      )

//            pdf.rect( x: p.x + Double( item.dimensions.width ) - Double( r )
//                    , y: p.y
//                    , width:  Double( r )
//                    , height: Double( item.dimensions.height ) )
//            pdf.fill()
        }
        
    }
    
    func setColor ( _ color: String?, _ fstype: String = "fill" ) {
        if color == nil { return }
        
        let color = parse_color( color! )
//        pdf.setColor(fstype: fstype, colorspace: "rgb", c1: color.r, c2: color.g, c3: color.b)
        switch( fstype ) {
        case "fill": context.setFillColor( red: color.r, green: color.g, blue: color.b, alpha: color.a )
        case "stroke": context.setStrokeColor( red: color.r, green: color.g, blue: color.b, alpha: color.a )
        default: break
        }
    }
    
    
    public func pos ( _ item: LayoutItem ) -> (x: Double, y: Double) {
        let abs_pos = item.absPosition( )
//        let y = offsetY - (abs_pos.y + item.dimensions.height)  + pageMargin.top
        let y = (abs_pos.y + item.dimensions.height)  + pageMargin.top
        
        return ( x: Double( abs_pos.x + pageMargin.left )
               , y: Double( y ) )
    }
    
    
    public override func endContainer(_ container: Container<LayoutItem>) {
        super.endContainer(container)
    }
    
    let _align:[String] = ["left", "center", "right"]
    func textAlignString( _ align: TextAlign ) -> String {
        return _align[ align.rawValue ]
    }
    func imageAlignString( _ align: ImageAlign ) -> String {
        return _align[ align.rawValue ]
    }

    
    override open func renderItem ( _ item: LayoutItem ) {
        rect( item )
        
        if clip( item ) {
            return
        }
        
        if let text = item as? Text {
            let fs = fontSizeInPoints(text.text_size)
            
            let txt_font = font(size: fs, bold: text.bold, italic: text.italic)
            let paragraphStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.alignment = text.align.nsTextAlignment
            paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
            
            var txt_attr: [NSAttributedString.Key:Any] = [
                .font: txt_font,
                .paragraphStyle: paragraphStyle
            ]
                    
            if text.style.fgColor != nil {
                let (r,g,b,a) = parse_color( text.style.fgColor! )
                let fg_color = UIColor(red: r, green: g, blue: b, alpha: a)
                txt_attr[.foregroundColor] = fg_color
            }
            
            let pos = self.pos( text )
            let fs_line_height: Float = Float( line_height( fs ) )
            
            if text.dimensions.height > fs_line_height {
                let parts = text.text.split(separator: " " )
                let sizes = parts.map{ Float( text_width( String( $0 ), size: fs, bold: text.bold, italic: text.italic ) ) }
                let space_size = Float( text_width( " ", size: fs, bold: text.bold, italic: text.italic ) )

                var i = 0
                var cur_line: Float = 0
                
                while i < parts.count {
                    var sentence: [String] = []
                    var sentence_size: Float = 0
                    while i < parts.count && (sentence_size + sizes[ i ] + Float( sentence.count ) * space_size) < text.dimensions.width {
                        sentence.append( String( parts[ i ] ) )
                        sentence_size = sentence_size + sizes[ i ]
                        i = i + 1
                    }

                    cur_line = cur_line + 1
                    let txt = sentence.joined(separator: " ")
                    let y = Double(   Float( pos.y + 4 )
                                    + Float( text.dimensions.height )
                                    - Float( cur_line * fs_line_height )
                                  )
                                                                                       
                    
                    let bounds = CGRect(x: pos.x, y: y, width: Double(text.dimensions.width), height: Double(text.dimensions.height))

                    (txt as NSString).draw(in: bounds, withAttributes: txt_attr )
                    
//                    try? pdf.fitTextLine( text: sentence.joined(separator: " ")
//                                        , x: pos.x
//                                        , y: Double(  Float( pos.y + 4 )
//                                                    + Float( text.dimensions.height )
//                                                    - Float( cur_line * fs_line_height )
//                                                   )
//                                        , options: opts.joined(separator: " "))
                    
                }
                
            
            } else {
                // Note => +4 = baseline?
                let bounds = CGRect(x: pos.x, y: pos.y, width: Double(text.dimensions.width), height: Double(text.dimensions.height))
                (text.text as NSString).draw(in: bounds, withAttributes:txt_attr)

//                try? pdf.fitTextLine( text: text.text
//                                    , x: pos.x
//                                    , y: pos.y + 4
//                                    , options: opts.joined(separator: " "))
            }
        }
//        else if let img = item as? URLImage {
//            let r = URLRequest( urlString: img.url )
//            let data = try? MIOCoreURLDataRequest_sync( r )
//            print("*** URL Image retrieve data from url: \(img.url)")
//            if data != nil {
//                let fn = String( img.url.split(separator: "/").last! )
//                pdf.createPVF( filename: fn, data: data! )
//                print("*** URL Image create pvf PDFLIB: \(fn)")
//                do {
//                    let image = try pdf.loadImage(fileName: fn )
//                    print("*** URL Image load image PDFLIB")
//                    let pos = self.pos( img )
//                    pdf.fitImage(image: image, x: pos.x, y: pos.y, options: "boxsize={\(item.dimensions.width) \(item.dimensions.height)} fitmethod=auto position={ \(imageAlignString ( img.align ) ) center }")
////                    pdf.fitImage(image: image, x: pos.x, y: pos.y, options: "boxsize={\(item.dimensions.width) \(item.dimensions.height)} fitmethod=auto")
//                    pdf.closeImage( image: image )
//                }
//                catch {
//                    print( "*** URL Image error: \(error.localizedDescription)")
//                }
//                pdf.deletePVF( filename: fn )
//            }
//        }
    }
        
    
    func clip ( _ item: LayoutItem ) -> Bool {
        return false // item.absPosition().y < 0
    }
    /*
     case none = 0
     case xxs  = 1
     case xs   = 2
     case s    = 3
     case m    = 4
     case l    = 5
     case xl   = 6
     case xxl  = 7
     case h    = 8 // huge
     */
    
    let fontSize:[Double] = [0, 4, 6, 8, 10, 14, 18, 24, 36]
    func fontSizeInPoints( _ size:ItemSize ) -> Double { return fontSize[ size.rawValue ] }
    var defaultFontSize:Double { get { return fontSizeInPoints (.s ) } }
    
    override open func meassure ( _ item: LayoutItem ) -> Size {
        if let text = item as? Text {
            let fs = fontSizeInPoints( text.text_size )
            let fs_line_height: Double = line_height( fs )
            var num_lines: Float = 1
            
            let w = text_width( text.text, size: fs, bold: text.bold, italic: text.italic )
            if Float ( w ) > A4.landscapeSize.width && text.wrap == .wrap {
                num_lines = ceil( ( Float(w) / A4.landscapeSize.width ) )
            }
            
            // Text needs air
            return Size( width: Float( w ), height: Float( fs_line_height ) * num_lines )
        }
        else if let sp = item as? Space {
            return Size( width: Float (sp.a.rawValue) * 4, height: Float (sp.b.rawValue) * 4 )
        }
            
        return super.meassure( item )
    }
    
    func text_width ( _ text: String, size: Double, bold: Bool, italic:Bool ) -> Double {

        let font = font( size: size, bold: bold, italic: italic )
        let attr = [NSAttributedString.Key.font: font ]
        let size = (text as NSString).size(withAttributes: attr )
        // let h = pdf.infoTextline( "\(text.text)", 0, "height", opts.joined(separator: " ") )
//        return pdf.stringWidth("\(text)", font: bold ? defaultFontBold : defaultFont, size: size )
        
        return size.height
    }
    
    func line_height ( _ fs: Double ) -> Double {
        let descent: Double = 2

        return (fs + descent + 4.0)
    }
    
    func parse_color( _ hex:String) -> (r:Double, g:Double, b:Double, a:Double){
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor + "00")
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    let r = Double((hexNumber & 0xff000000) >> 24) / 255
                    let g = Double((hexNumber & 0x00ff0000) >> 16) / 255
                    let b = Double((hexNumber & 0x0000ff00) >> 8) / 255
                    let a = 1.0
                    //if hexColor.count == 8 { Double(hexNumber & 0x000000ff) / 255 }
                    
                    return (r, g, b, a)
                }
            }
        }
        
        return (0, 0, 0, 0)
    }
    
    open override func beginPage ( _ page: Page ) {
        super.beginPage( page )
        UIGraphicsBeginPDFPage()
//        pdf.beginPage(options: "width=a4.width height=a4.height")
        
    }
    
    
    open override func endPage ( _ page: Page ) {
        super.endPage( page )
//        pdf.endPage()
    }

}

extension TextAlign
{
    var nsTextAlignment : NSTextAlignment {
        switch self {
        case .left: return NSTextAlignment.left
        case .center: return NSTextAlignment.center
        case .right: return NSTextAlignment.right
        }
    }
}

#endif
