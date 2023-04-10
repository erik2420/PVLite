//
//  OwnerSelectionMenu.swift
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

class OwnerSelectionMenu: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate{
    
    public var completionHandler: ((String?) -> Void)?
    
    //Holds the value of the selected attachment
    var tempStr: String = ""
    
    var Owners = [String]()
    
    //PickerView for selecting owner code
    @IBOutlet weak var pickerAttachment: UIPickerView!
    
    @IBOutlet weak var lblOwner: UILabel!
    //Temp data for pickerview
    let pickerData = ["","LTON","LTOFF","NLT","AT&T","BBTC","BRWN","BTBT","CLNK","CMBC","COOP","CTCO","EJEC","EKEC","ENEC","ESBC","ESPO","EVEC","EWCC","FRTR","GNTL","GVEC","GVTC","HCTC","MCAC","MDEC","MRCC","MUNI","MVEC","OXEA","PHRC","RAYC","RGDC","SBNC","SCTC","SJNC","SWTT","TWCH","TXCC","VLTC ","VRZN"]
    
    override func viewDidLoad() {
        //Startup code here
        super.viewDidLoad()
        pickerAttachment.delegate = self
        pickerAttachment.dataSource = self
        view.addSubview(pickerAttachment)
    }
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // Return the number of components (columns) in the picker view
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if Owners.isEmpty{
            return pickerData.count // Return the default data if Owners is blank
        }else{
            return Owners.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if Owners.isEmpty{
            return pickerData[row] // Return the default data if Owners is blank
        }else{
            return Owners[row]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if Owners.isEmpty{
            tempStr = pickerData[row] // Return the default data if Owners is blank
        }else{
            tempStr = Owners[row]
        }

        lblOwner.text = tempStr
        
        // Check if selected row's value is "???"
        if tempStr == "???" {
            let alertController = UIAlertController(title: "Enter a value", message: nil, preferredStyle: .alert)
            alertController.addTextField { textField in
                textField.placeholder = "Enter a value"
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                if let text = alertController.textFields?.first?.text {
                    self.tempStr = text
                    self.lblOwner.text = self.tempStr
                    pickerView.selectRow(row, inComponent: component, animated: true)
                }
            }))
            present(alertController, animated: true, completion: nil)
        }
        print("Huh?\(tempStr)")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("Should be sending: \(tempStr)")
        NotificationCenter.default.post(name: Notification.Name("attacherDetails"), object: tempStr)
    }
    
    @IBAction func btnDoneTap(_ sender: Any) {
        dismiss(animated: true)
    }
    
}

