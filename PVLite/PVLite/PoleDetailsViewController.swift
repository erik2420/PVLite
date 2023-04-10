//
//  PoleDetailsViewController.swift
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


class PoleDetailsViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //poledata boxes:
    @IBOutlet weak var tbComments: UITextField!
    @IBOutlet weak var tbOwner: UITextField!
    @IBOutlet weak var tbPoleNum: UITextField!
    @IBOutlet weak var tbAttch1: UITextField!
    @IBOutlet weak var tbAttch2: UITextField!
    @IBOutlet weak var tbAttch3: UITextField!
    @IBOutlet weak var tbAttch4: UITextField!
    @IBOutlet weak var tbAttch5: UITextField!
    @IBOutlet weak var tbAttch6: UITextField!
    @IBOutlet weak var tbAttch7: UITextField!
    @IBOutlet weak var tbAttch8: UITextField!
    @IBOutlet weak var tbAttch9: UITextField!
    @IBOutlet weak var tbAttch10: UITextField!
    @IBOutlet weak var tbAttch11: UITextField!
    @IBOutlet weak var tbAttch12: UITextField!
    @IBOutlet weak var tbAttch13: UITextField!
    @IBOutlet weak var tbAttch14: UITextField!
    @IBOutlet weak var tbAttch15: UITextField!
    @IBOutlet weak var tbAttch16: UITextField!
    @IBOutlet weak var tbAttch17: UITextField!
    @IBOutlet weak var tbPoleAttribs: UITextField!
    
    
    @IBOutlet weak var lblPreview: UITextView!
    @IBOutlet weak var lblHeader: UILabel!
    
    @IBOutlet weak var btnTakePicture: UIButton!
    @IBOutlet weak var btnGetDirections: UIButton!
    @IBOutlet weak var btnDone: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    
    var pole: Pole?
    
    weak var currentTextField: UITextField!
    
    var poledata: String?
    var origPoledata: String?
    
    var didSendValue: ((Pole) -> Void)?
    
    //Arrays that hold Owners/TLAs/SFXs/PAs
    var Owners = [String]()
    var TLAs = [String]()
    var SFXs = [String]()
    var PAs = [String]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let pole = pole {
            lblPreview.text = pole.poledata
            lblHeader.text = pole.SRCID
            
            //Fan out poledata
            poledata = pole.poledata
            origPoledata = poledata
            var pd: [String] = splitPoleData(str: pole.poledata)!
            if pd.isEmpty || pd == [""]{
                pd = ",,,,,,,,,,,,,,,,,,,,".components(separatedBy: ",")
            }
            
            //Assign attacher boxes
            tbComments.text = pole.comments; //tbComments.inputView = UIView()
            tbOwner.text = pd[1]; tbOwner.inputView = UIView()
            //tbPoleNum.text = pd[2]
            tbAttch1.text = pd[2]; tbAttch1.inputView = UIView()
            tbAttch2.text = pd[3]; tbAttch2.inputView = UIView()
            tbAttch3.text = pd[4]; tbAttch3.inputView = UIView()
            tbAttch4.text = pd[5]; tbAttch4.inputView = UIView()
            tbAttch5.text = pd[6]; tbAttch5.inputView = UIView()
            tbAttch6.text = pd[7]; tbAttch6.inputView = UIView()
            tbAttch7.text = pd[8]; tbAttch7.inputView = UIView()
            tbAttch8.text = pd[9]; tbAttch8.inputView = UIView()
            tbAttch9.text = pd[10]; tbAttch9.inputView = UIView()
            tbAttch10.text = pd[11]; tbAttch10.inputView = UIView()
            tbAttch11.text = pd[12]; tbAttch11.inputView = UIView()
            tbAttch12.text = pd[13]; tbAttch12.inputView = UIView()
            tbAttch13.text = pd[14]; tbAttch13.inputView = UIView()
            tbAttch14.text = pd[15]; tbAttch14.inputView = UIView()
            tbAttch15.text = pd[16]; tbAttch15.inputView = UIView()
            tbAttch16.text = pd[17]; tbAttch16.inputView = UIView()
            tbAttch17.text = pd[18]; tbAttch17.inputView = UIView()
            tbPoleAttribs.text = pd[19]; tbPoleAttribs.inputView = UIView()
            
            tbComments.delegate = self
            tbAttch1.delegate = self;tbAttch2.delegate = self;tbAttch3.delegate = self;tbAttch4.delegate = self;
            tbAttch5.delegate = self;tbAttch6.delegate = self;tbAttch7.delegate = self;tbAttch8.delegate = self;
            tbAttch9.delegate = self;tbAttch10.delegate = self;tbAttch11.delegate = self;tbAttch12.delegate = self;
            tbAttch13.delegate = self;tbAttch14.delegate = self;tbAttch15.delegate = self;tbAttch16.delegate = self;
            tbAttch17.delegate = self;tbPoleAttribs.delegate = self;tbOwner.delegate = self;tbPoleNum.delegate = self;
            
            tbAttch1.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
    }
    
    
    //Split pd string into an array and return it
    func splitPoleData(str: String) -> [String]?{
        var poledata: [String] = str.components(separatedBy: ",")
        if poledata.isEmpty{
            poledata = ",,,,,,,,,,,,,,,,,,,,".components(separatedBy: ",")
        }
        return poledata
    }
    
    
    //Close the pole details screen
    @IBAction func btnDoneTap(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    
    //Let user take picture(s) of pole (TODO: Save photo after capture)
    @IBAction func btnTakePicTap(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true, completion: nil)
    }
    
    
    //Opens the selected pole in apple maps
    @IBAction func btnGetDirectsTap(_ sender: Any) {
        //Open apple maps with the selected pole as a destination
        let coordinate = CLLocationCoordinate2D(latitude: (pole?.Y)!, longitude: (pole?.X)!)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pole?.SRCID
        mapItem.openInMaps(launchOptions: nil)
    }
    
    
    //Delete the pole (format poledata)
    @IBAction func btnDeleteTap(_ sender: Any) {
        for i in 1...18 {
            // Code to be executed in each iteration of the loop
            if let textField = view.viewWithTag(i) as? UITextField {
                textField.text = ""
            }
        }
        tbOwner.text = ""
        tbComments.text = "DELETE"
        poledata = "DELETE,,,,,,,,,,,,,,,,,,,,"
        lblPreview.text = poledata
    }
    
    
    //Photo stuff
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            // Save the image to the app's documents folder
            saveImageToDocumentsFolder(image)
        }
        dismiss(animated: true, completion: nil)
    }
    
    
    func saveImageToDocumentsFolder(_ image: UIImage) {
        // Get the documents directory URL
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get documents directory")
            return
        }
        
        let idString = pole?.SRCID ?? ""
        var counter: Int = 0
        
        // Look for existing files with the same ID and incremental value
        var existingFilenames = try? FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)
        existingFilenames = existingFilenames?.filter { $0.hasPrefix("\(idString)-") && $0.hasSuffix(".jpg") }
        existingFilenames?.sort()
        let existingIncrementalValues = existingFilenames?.map { $0.components(separatedBy: "-")[2].replacingOccurrences(of: ".jpg", with: "") }
        if let lastValue = existingIncrementalValues?.last, let intValue = Int(lastValue) {
            counter = intValue + 1
        }
        
        // At this point, uniqueIdentifier contains a unique identifier that does not yet exist in the file system
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let currentDateString = formatter.string(from: currentDate)
        let filename = "\(idString)-\(currentDateString)-\(String(format: "%03d%", counter)).jpg"
        
        // Append the filename to the documents directory URL
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            // Convert the image to JPEG data and write it to the file URL
            if let jpegData = image.jpegData(compressionQuality: 0.01) {
                try jpegData.write(to: fileURL)
                showMessage(message: "Save imaged.")
            } else {
                showMessage(message: "Unable to save image. Please try again.")
            }
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }
        
        
        
        
        
    }
    
    
    //Close the camera if user taps cancel
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    
    //When the user taps one of the attacher boxes, bring up the attachment details view
    func textFieldShouldBeginEditing(_ textField: UITextField) ->Bool {
        //Don't pop up attacher selection for comments and pole number
        if textField == tbComments || textField == tbPoleNum{
            return true
            //Do nothing, the keyboard should pop up
        }else if textField == tbOwner{
            NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
            let ownerSelectionMenu = storyboard?.instantiateViewController(identifier: "OwnerSelectionMenu") as! OwnerSelectionMenu
            ownerSelectionMenu.modalPresentationStyle = .popover
            ownerSelectionMenu.Owners = Owners
            present(ownerSelectionMenu, animated: true)
            self.currentTextField = textField
            return false
        }
        else if textField == tbPoleAttribs{
            NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
            let poleAttribsSelectionMenu = storyboard?.instantiateViewController(identifier: "PoleAttribsSelectionMenu") as! PoleAttribsSelectionMenu
            poleAttribsSelectionMenu.modalPresentationStyle = .popover
            poleAttribsSelectionMenu.PAs = PAs
            present(poleAttribsSelectionMenu, animated: true)
            self.currentTextField = textField
            return false
        }else{
            let tagNum = textField.tag
            let atchNum = "ATCH" + String(format: "%02d", tagNum)
            // find the index of the string in the array that starts with the search string
            if let index = TLAs.firstIndex(where: { $0.hasPrefix(atchNum) }) {
                let matchingTLA = TLAs[index]
                if let index2 = SFXs.firstIndex(where: { $0.hasPrefix(atchNum) }) {
                    // found the string in the array
                    let matchingSFX = SFXs[index2]
                    NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
                    let attacherSelectionMenu = storyboard?.instantiateViewController(identifier: "AttacherSelectionMenu") as! AttacherSelectionMenu
                    attacherSelectionMenu.modalPresentationStyle = .popover
                    attacherSelectionMenu.TLAstr = matchingTLA
                    attacherSelectionMenu.SFXstr = matchingSFX
                    present(attacherSelectionMenu, animated: true)
                    self.currentTextField = textField
                    return false
                }else{
                    // found the string in the array
                    let matchingString = TLAs[index]
                    NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
                    let attacherSelectionMenu = storyboard?.instantiateViewController(identifier: "AttacherSelectionMenu") as! AttacherSelectionMenu
                    attacherSelectionMenu.modalPresentationStyle = .popover
                    attacherSelectionMenu.TLAstr = matchingString
                    attacherSelectionMenu.SFXs = SFXs
                    present(attacherSelectionMenu, animated: true)
                    self.currentTextField = textField
                    return false
                }
            } else {
                if let index2 = SFXs.firstIndex(where: { $0.hasPrefix(atchNum) }) {
                    // found the string in the array
                    let matchingSFX = SFXs[index2]
                    NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
                    let attacherSelectionMenu = storyboard?.instantiateViewController(identifier: "AttacherSelectionMenu") as! AttacherSelectionMenu
                    attacherSelectionMenu.modalPresentationStyle = .popover
                    attacherSelectionMenu.SFXstr = matchingSFX
                    present(attacherSelectionMenu, animated: true)
                    self.currentTextField = textField
                    return false
                }else{
                    // found the string in the array
                    NotificationCenter.default.addObserver(self, selector: #selector(didGetNotification(_:)), name: Notification.Name("attacherDetails"), object: nil)
                    let attacherSelectionMenu = storyboard?.instantiateViewController(identifier: "AttacherSelectionMenu") as! AttacherSelectionMenu
                    attacherSelectionMenu.modalPresentationStyle = .popover
                    present(attacherSelectionMenu, animated: true)
                    self.currentTextField = textField
                    return false
                }
            }
            
            
            
        }
    }
    
    
    //Anytime a textfield value changes, update the PD string
    @objc func textFieldDidChange(_ textField: UITextField) {
        updatePDLabel()
    }
    
    
    //Whenever an attacher value is changed, update the preview label
    func textFieldDidChangeSelection(_ textField: UITextField) {
        updatePDLabel()
    }
    
    
    
    
    //Clears the appropriate textfield for the trash button pressed
    @IBAction func clearTextField(sender: UIButton) {
        let textFieldTag = sender.tag - 100 // subtract 100 to get the tag value of the text field
        if let textField = view.viewWithTag(textFieldTag) as? UITextField {
            textField.text = ""
        }
        updatePDLabel()
    }
    
    //Cancels editing of the currently selected pole and returns to map screen
    @IBAction func btnCancelTap(_ sender: Any) {
        poledata = origPoledata
        dismiss(animated: true)
    }
    
    
    //Combine all attach text boxes to create the updated poledata string
    func updatePDLabel(){
        
        if tbComments.text == "DELETE"{
            //Delete pole, just give the delete string
            poledata = "DELETE,,,,,,,,,,,,,,,,,,,,"
        }else{
            let tempPD: String = (tbPoleNum.text ?? "") + "," + (tbOwner.text ?? "") + "," + (tbAttch1.text ?? "") + "," + (tbAttch2.text ?? "") + "," + (tbAttch3.text ?? "") + "," + (tbAttch4.text ?? "") + "," + (tbAttch5.text ?? "") + "," + (tbAttch6.text ?? "") + "," + (tbAttch7.text ?? "") + "," + (tbAttch8.text ?? "") + "," + (tbAttch9.text ?? "") + "," + (tbAttch10.text ?? "") + "," + (tbAttch11.text ?? "") + "," + (tbAttch12.text ?? "") + "," + (tbAttch13.text ?? "") + "," + (tbAttch14.text ?? "") + "," + (tbAttch15.text ?? "") + "," + (tbAttch16.text ?? "") + "," + (tbAttch17.text ?? "") + "," + (tbPoleAttribs.text ?? "") + ","
            lblPreview.text = tempPD
            poledata = tempPD
        }
    }
    
    
    //Receive attacher details here from attacherdetailsview
    @objc func didGetNotification(_ notification: Notification){
        let tempStr = (notification.object as! String?)!
        
        if notification.name.rawValue == "attacherDetails"{
            self.currentTextField.text = tempStr
            updatePDLabel()
        }
    }
    
    
    //Dismiss keyboard on return tap
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    //Return the poledata back to the main map screen after editing
    override func viewDidDisappear(_ animated: Bool) {
        updatePDLabel()
        //Return the pole object back to the main map screen with any changes
        pole?.comments = tbComments.text ?? ""
        pole?.poledata = poledata ?? ""
        
        didSendValue?(pole!)
    }
    
    func showMessage(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        rootViewController.present(alertController, animated: true, completion: nil)
    }
}
