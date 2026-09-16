//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

class RenderProtocol {
    func textSize ( text: String ) -> Size {
        return Size( width: 0, height: 0 )
    }
    
    func constrainedTextLength ( text: String, width: Decimal ) -> Size {
        return Size( width: 0, height: 0 )
    }
    
//    func addImage ( image: Image ) { }
//    func addText ( span: TextSpan ) { }
//    func addText ( box: TextBox ) { }
    
    func willFitInPage ( _ height: Decimal ) -> Bool { return true }
}
