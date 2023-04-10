//
//  CustomPointAnnotation.swift
//  PVLite
//
//  Created by Erik Taylor on 4/7/23.
//

import UIKit
import UniformTypeIdentifiers
import Foundation
import MobileCoreServices
import MapKit
import FilesProvider

class CustomPointAnnotation: MKPointAnnotation {
    var annotationColor: UIColor
    var type: String
    
    override init() {
        self.annotationColor = .red
        self.type = ""
        super.init()
    }
    
    init(annotationColor: UIColor) {
        self.annotationColor = annotationColor
        self.type = ""
        super.init()
    }
}
