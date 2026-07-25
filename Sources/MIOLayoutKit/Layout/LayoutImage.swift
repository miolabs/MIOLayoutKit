//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

// TODO: Add support for Top, middle and bottom align
public enum ImageAlign: Int {
    case left   = 0
    case center = 1
    case right  = 2
}


public class Image: LayoutItem {
    public var data: Data?
    public var imgSize: Size
    public var align: ImageAlign = .center
    
    public init ( data: Data?, width: Float, height: Float, flex: Int = 0, id: String? = nil ) {
        self.data = data
        self.imgSize = Size( width: width, height: height )
        super.init( flex, id)
    }
        
    public func align ( _ value: ImageAlign ) -> Self {
        align = value
        return self
    }
    
    public override func clone ( ) -> Image {
        let ret = Image( data: data, width: imgSize.width, height: imgSize.height, flex: flex, id: id )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues(_ src: Image ) {
        data = src.data
        imgSize = src.imgSize
        align = src.align
        super.copyValues( src as LayoutItem )
    }
    
    override open func meassure ( _ context: RenderContext ) {
        size = self.imgSize
    }
    
    override func setValue ( _ value: Any ) throws {
        if let new_data = value as? Data {
            data = new_data
        }
        
        // TODO: throw xxx( "the url is not an string: \(value)" )
    }
    
    override open func shallowCopy ( ) -> LayoutItem {
        let ret = Image( data: data, width: imgSize.width, height: imgSize.height )
        ret.copyValues( self )
        
        return ret
    }
}


public class URLImage: Image {
    public var url: String
    
    public init ( url: String, width: Float, height: Float, flex: Int = 0, id: String? = nil ) {
        self.url = url
        super.init( data: nil, width: width, height: height, flex: flex, id: id )
    }
    
//    override func setDimension ( _ dim: Size ) {
//        dimensions = dim
//    }
    
    override func setValue ( _ value: Any ) throws {
        if let new_url = value as? String {
            url = new_url
        }
        
        // TODO: throw xxx( "the url is not an string: \(value)" )
    }
    
    override open func shallowCopy ( ) -> LayoutItem {
        let ret = URLImage( url: url, width: imgSize.width, height: imgSize.height )
        ret.copyValues( self )
        
        return ret
    }
}
