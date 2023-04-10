//
//  PoleAttribsSelectionMenu.swift
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

class PoleAttribsSelectionMenu: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate{
    
    //Picker Views
    @IBOutlet weak var pickerYear: UIPickerView!
    @IBOutlet weak var pickerHeight: UIPickerView!
    @IBOutlet weak var pickerClass: UIPickerView!
    @IBOutlet weak var pickerMaterial: UIPickerView!
    @IBOutlet weak var pickerAttribs: UIPickerView!
    
    var PAs = [String]()
    
    //Temp Picker View data
    var pickerYearData = ["","2020","2021","2022","2023"]
    let pickerHeightData = ["","025","030","035","040","045","050","055","060","065","070","080","090","100","110","120"]
    let pickerClassData = ["","0","1","2","3","4","5","6","7","8"]
    let pickerMaterialData = ["","WD","MT","FB","CO","LM","DC","OT"]
    let pickerAttribsData = ["","OVF","PRIP","SECP","TRNP","ODLP","CAPP","REGP","TO","ONA","HZRD"]
    
    
    //Holds the value of the pole attribs
    var tempStr: String = ""
    
    var year: String = ""
    var height: String = ""
    var type: String = ""
    var material: String = ""
    var attribs: String = ""
    
    
    
    
    override func viewDidLoad() {
        //Startup code here
        super.viewDidLoad()
        pickerYear.delegate = self
        pickerYear.dataSource = self
        
        pickerHeight.delegate = self
        pickerHeight.dataSource = self
        
        pickerClass.delegate = self
        pickerClass.dataSource = self
        
        pickerMaterial.delegate = self
        pickerMaterial.dataSource = self
        
        pickerAttribs.delegate = self
        pickerAttribs.dataSource = self
        
        view.addSubview(pickerYear)
        view.addSubview(pickerHeight)
        view.addSubview(pickerClass)
        view.addSubview(pickerMaterial)
        view.addSubview(pickerAttribs)
        
        //Populate year values:
        let currentYear = Calendar.current.component(.year, from: Date())
        let pastDate = 1945
        var years = [String]()
        for year in (pastDate...currentYear).reversed() {
            years.append("\(year)")
        }
        pickerYearData = years
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // Return the number of components (columns) in the picker view
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == pickerYear{
            return pickerYearData.count
        }else if pickerView == pickerHeight{
            return pickerHeightData.count
        }else if pickerView == pickerClass{
            return pickerClassData.count
        }else if pickerView == pickerMaterial{
            return pickerMaterialData.count
        }else if pickerView == pickerAttribs{
            return pickerAttribsData.count
        }else{
            return 0
        }
        // Return the number of rows in the picker view
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == pickerYear{
            return pickerYearData[row]
        }else if pickerView == pickerHeight{
            return pickerHeightData[row]
        }else if pickerView == pickerClass{
            return pickerClassData[row]
        }else if pickerView == pickerMaterial{
            return pickerMaterialData[row]
        }else if pickerView == pickerAttribs{
            return pickerAttribsData[row]
        }else{
            return ""
        }
        // Return the data for the specified row and component
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == pickerYear{
            year = pickerYearData[row]
        }else if pickerView == pickerHeight{
            height = pickerHeightData[row]
        }else if pickerView == pickerClass{
            type = pickerClassData[row]
        }else if pickerView == pickerMaterial{
            material = pickerMaterialData[row]
        }else if pickerView == pickerAttribs{
            attribs = pickerAttribsData[row]
        }
        
        
        tempStr = ("\(year)-\(height)-\(type)-\(material)-\(attribs)")
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.post(name: Notification.Name("attacherDetails"), object: tempStr)
    }
    
    @IBAction func btnDoneTap(_ sender: Any) {
        dismiss(animated: true)
    }
}
