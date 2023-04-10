//
//  AttacherSelectionMenu.swift
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

class AttacherSelectionMenu: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate{
    //Holds the value of the selected attachment
    var tempStrAttach: String = ""
    var tempStrAttachDets: String = ""
    
    var TLAs = [String]()
    var SFXs = [String]()
    var TLAstr = String()
    var SFXstr = String()
    
    @IBOutlet weak var pickerAttachment: UIPickerView!
    let pickerAttachmentData = ["","ATT","FTR","CLK","GTL","GVT","LWD","RVR","???"]
    
    @IBOutlet weak var pickerAttachDetails: UIPickerView!
    let pickerAttachDetailsData = ["RG","DR","RS","OL","TR","NA","IL","EQ","SP","BA","DE"]
    
    let pickerAttachDetailsDataQty = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    
    
    @IBOutlet weak var lblAttachPreview: UILabel!
    @IBOutlet weak var lblAttachDetailsPreview: UILabel!
    
    override func viewDidLoad() {
        //Startup code here
        super.viewDidLoad()
        pickerAttachment.delegate = self
        pickerAttachment.dataSource = self
        pickerAttachment.layer.borderWidth = 2
        pickerAttachment.layer.borderColor = UIColor.secondarySystemBackground.cgColor
        
        pickerAttachDetails.delegate = self
        pickerAttachDetails.dataSource = self
        pickerAttachDetails.layer.borderWidth = 2
        pickerAttachDetails.layer.borderColor = UIColor.secondarySystemBackground.cgColor
        
        
        view.addSubview(pickerAttachment)
        view.addSubview(pickerAttachDetails)
        
        //Get the TLAs
        if !TLAstr.isEmpty{
            let components = TLAstr.components(separatedBy: ":")
            if components.count > 1{
                TLAs = components[1].components(separatedBy: ",")
            }else{
                
            }
        }
        if !SFXstr.isEmpty{
            let components = SFXstr.components(separatedBy: ":")
            if components.count > 1{
                SFXs = components[1].components(separatedBy: ",")
            }else{
                
            }
        }
        
    }
    
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        if pickerView == pickerAttachDetails {
            return 2 // Return 2 columns for the pickerAttachDetails picker view
        }
        return 1 // Return the number of components (columns) in the picker view
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        if pickerView == pickerAttachment && !TLAs.isEmpty{
            return TLAs.count
        }else if pickerView == pickerAttachment{
            return pickerAttachmentData.count //Return a default
        }else if pickerView == pickerAttachDetails && !SFXs.isEmpty{
            if component == 0 {
                return SFXs.count
            }else{
                return pickerAttachDetailsDataQty.count
            }
        }else if pickerView == pickerAttachDetails{
            if component == 0 {
                return pickerAttachDetailsData.count
            }else{
                return pickerAttachDetailsDataQty.count
            }
        }else{
            return 0
        }
        
    }
    
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        if pickerView == pickerAttachment && !TLAs.isEmpty{
            tempStrAttach = TLAs[row]
            return tempStrAttach
        }else if pickerView == pickerAttachment{
            tempStrAttach = pickerAttachmentData[row]
            return tempStrAttach
        }else if pickerView == pickerAttachDetails && !SFXs.isEmpty{
            if component == 0 {
                return SFXs[row]
            } else {
                return String(pickerAttachDetailsDataQty[row])
            }
        }else if pickerView == pickerAttachDetails{
            if component == 0 {
                return pickerAttachDetailsData[row]
            } else {
                return String(pickerAttachDetailsDataQty[row])
            }
            
        }else{
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        
        if pickerView == pickerAttachment && !TLAs.isEmpty{
            tempStrAttach = TLAs[row]
            lblAttachPreview.text = tempStrAttach
        } else if pickerView == pickerAttachment{
            tempStrAttach = pickerAttachmentData[row]
            lblAttachPreview.text = tempStrAttach
        } else if pickerView == pickerAttachDetails && !SFXs.isEmpty{
            let firstColumnData = SFXs[pickerView.selectedRow(inComponent: 0)]
            let secondColumnData = pickerAttachDetailsDataQty[pickerView.selectedRow(inComponent: 1)]
            tempStrAttachDets = "\(firstColumnData)\(secondColumnData)"
            lblAttachDetailsPreview.text = tempStrAttachDets
        } else if pickerView == pickerAttachDetails{
            let firstColumnData = pickerAttachDetailsData[pickerView.selectedRow(inComponent: 0)]
            let secondColumnData = pickerAttachDetailsDataQty[pickerView.selectedRow(inComponent: 1)]
            tempStrAttachDets = "\(firstColumnData)\(secondColumnData)"
            lblAttachDetailsPreview.text = tempStrAttachDets
        }
        
        
        // Check if selected row's value is "???"
        if tempStrAttach == "???" {
            let alertController = UIAlertController(title: "Enter a value", message: nil, preferredStyle: .alert)
            alertController.addTextField { textField in
                textField.placeholder = "Enter a value"
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                if let text = alertController.textFields?.first?.text {
                    self.tempStrAttach = text
                    self.lblAttachPreview.text = self.tempStrAttach
                    pickerView.selectRow(row, inComponent: component, animated: true)
                }
            }))
            present(alertController, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func btnAddDetsTap(_ sender: Any) {
        lblAttachPreview.text = "\(lblAttachPreview.text ?? "")-\(tempStrAttachDets)"
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if lblAttachPreview.text == "Preview:"{
            
        }else{
            NotificationCenter.default.post(name: Notification.Name("attacherDetails"), object: lblAttachPreview.text)
        }
        
    }
    
    @IBAction func btnDoneTap(_ sender: Any) {
        dismiss(animated: true)
    }
    
}
