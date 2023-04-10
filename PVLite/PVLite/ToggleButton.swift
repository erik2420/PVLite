//
//  ToggleButton.swift
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

class ToggleButton: UIButton {
    var isOn = false {
        didSet {
            updateButtonState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        updateButtonState()
        
        //Set corner size
        layer.cornerRadius = 10
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        updateButtonState()
        
        //Set corner size
        layer.cornerRadius = 10
    }
    
    @objc private func buttonTapped() {
        isOn.toggle()
    }
    
    private func updateButtonState() {
        let backgroundColor = isOn ? UIColor.systemBlue.withAlphaComponent(0.75) : UIColor.systemGray.withAlphaComponent(0.45)
                self.backgroundColor = backgroundColor
        //setTitle(isOn ? "Pressed" : "Not Pressed", for: .normal)
    }
}
