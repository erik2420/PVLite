//
//  ViewController.swift
//  PVLite
//
//  Created by Erik Taylor on 3/3/23.
//
//  poles.txt format as follows:
//  X,Y,comments,poledata,suppdata,VSUMInfo,SRCID,SRCOWN
//  0 = Long | 1 = Lat | 2 = comments | 3 = poledata
//  4 = suppdata | 5 = VSUMInfo | 6 = SRCID | 7 = SRCOWN

import UIKit
import UniformTypeIdentifiers
import Foundation
import MobileCoreServices
import MapKit
import FilesProvider


//Main map screen which allows user to import/export poles
class ViewController: UIViewController, UIDocumentPickerDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    //Map Items
    @IBOutlet weak var map: MKMapView! //Map
    let locationManager = CLLocationManager() //User Location
    var crosshairView: UIView! //Cross hair on map
    var annotations = [CustomPointAnnotation()] //Annotations (pins on map)
    
    
    //Buttons on Map
    @IBOutlet weak var btnCrosshair: ToggleButton!
    @IBOutlet weak var btnCenter: ToggleButton!
    @IBOutlet weak var btnBaseMap: ToggleButton!
    @IBOutlet weak var btnDirections: ToggleButton!
    
    @IBOutlet weak var btnImport: UIButton!
    
    @IBOutlet weak var btnExport: UIButton!
    
    @IBOutlet weak var btnSettings: UIButton!
    
    @IBOutlet weak var btnInsert: UIButton!
    
    
    //Poles.txt contents (Owners, TLAs, etc...)
    var Owners = [String]()
    var TLAs = [String]()
    var SFXs = [String]()
    var PAs = [String]()
    
    
    
    //Other
    var fileURL: String = "" //Stores a file path
    var insertCounter: Int32 = 0 //To track insert count
    var counter: Int = 0 //For incremental values in VSUMInfo and elsewhere if needed
    var poleFileDate: String = ""
    @IBOutlet weak var lblText: UITextView! //TextView to display various messages for user
    var currentPolyline: MKPolyline? //Used to add and remove directions line from map
    
    
    //Poles
    var poles: [Pole] = [] //Contains all poles
    
    
    
    
    //Startup code -- Load Map
    override func viewDidLoad() {
        
        super.viewDidLoad()
        //Map Settings
        map.showsUserLocation = true
        map.delegate = self
        map.mapType = .standard
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        //Ask for user's location
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        //Track user :O
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        
        //Follow user >:)
        map.userTrackingMode = .follow
        
        //Initialize a crosshair that user can turn on or off
        addCrosshair()
        
        //Button appearance
        btnImport.backgroundColor = UIColor.systemGray.withAlphaComponent(0.45)
        btnImport.layer.cornerRadius = 10
        btnExport.backgroundColor = UIColor.systemGray.withAlphaComponent(0.45)
        btnExport.layer.cornerRadius = 10
        btnSettings.backgroundColor = UIColor.systemGray.withAlphaComponent(0.45)
        btnSettings.layer.cornerRadius = 10
        btnInsert.backgroundColor = UIColor.systemGray.withAlphaComponent(0.45)
        btnInsert.layer.cornerRadius = 10
        
        lblText.backgroundColor = UIColor.systemGray.withAlphaComponent(0.65)
        lblText.layer.cornerRadius = 10
        
        //Label at bottom of screen
        lblText.text = "Import a poles file to continue..."
    }
    
    
    
    //MARK: Map Functions
    //______________________
    //Show all the pins on the map (to avoid fading in and out based on zoom)
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        guard let annotation = annotation as? MKPointAnnotation else {
            return nil
        }
        
        let identifier = "annotation"
        var view: MKPinAnnotationView
        
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
        }
        
        //Set the pin color based on the annotationColor property of the annotation
        if let customAnnotation = annotation as? CustomPointAnnotation {
            //Colors Testing :D DELETE THIS COMMENT
            view.pinTintColor = customAnnotation.annotationColor
        } else {
            view.pinTintColor = .black // default color
        }
        
        //Disable clustering (fades symbols in/out based on zoom level)
        view.clusteringIdentifier = nil
        
        return view
    }
    
    //Disables the user from selecting their own location
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        if let userLocationAnnotationView = map.view(for: map.userLocation) {
            userLocationAnnotationView.isSelected = false
        }
    }
    
    //Event for whenever an annotation (pin) is tapped on the map
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        //Deselect user location annotation view
        if view == map.view(for: map.userLocation) {
            view.isSelected = false
        }
        
        guard let annotation = view.annotation as? MKPointAnnotation else { return }
        if (view.annotation?.title) != nil {
            
            //Loop through pole list to get selected pole using SRCID
            let selectedPole: Pole = getSelectedPole(srcid: annotation.title!)!
            
            //Change color to green if not tapped yet ('clicked pole')
            if let pinView = view as? MKPinAnnotationView {
                if pinView.pinTintColor == .green{
                    //Already tapped
                }else{
                    pinView.pinTintColor = .green
                }
            }
            //Show poledetails screen
            performSegue(withIdentifier: "mapToPoleSegue", sender: selectedPole)
        }
    }
    
    //For rendering objects on the map
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        //If the object to display is a polyline, turn it light blue
        if let polyline = overlay as? MKPolyline {
            let color = UIColor(red: 0.0, green: 0.96, blue: 1.0, alpha: 1.0)
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = color
            renderer.lineWidth = 1
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    //If the user has selected the option, center the user's location in the center of the map
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        // Update the center of the map to the user's location if user has selected to be centered
        if btnCenter.isOn{
            map.setCenter(userLocation.coordinate, animated: true)
        }else{
            
        }
    }
    
    //Adds a crosshair symbol to the map to help user see center of map
    func addCrosshair(){
        // Add cross to map (off by default)
        let crossSize: CGFloat = 20
        crosshairView = UIView(frame: CGRect(x: map.bounds.midX - crossSize/2, y: map.bounds.midY - crossSize/2, width: crossSize, height: crossSize))
        crosshairView.backgroundColor = UIColor.clear
        map.addSubview(crosshairView)
        
        let crossLine1 = UIView(frame: CGRect(x: crossSize/4, y: crossSize/2 - 1, width: crossSize/2, height: 2))
        crossLine1.backgroundColor = UIColor.red
        crosshairView.addSubview(crossLine1)
        
        let crossLine2 = UIView(frame: CGRect(x: crossSize/2 - 1, y: crossSize/4, width: 2, height: crossSize/2))
        crossLine2.backgroundColor = UIColor.red
        crosshairView.addSubview(crossLine2)
        
        crosshairView.isHidden = true
    }
    //_______________________
    //MARK: End Map Functions
    
    
    
    
    //MARK: Send and Receive data from other screens
    //______________________________________________
    //Sets Pole object in PoleDetailsVC
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "mapToPoleSegue" {
            if let pole = sender as? Pole, let poleDetailsViewController = segue.destination as? PoleDetailsViewController {
                poleDetailsViewController.didSendValue = { [weak self] value in
                    self?.didReceiveValue(value)
                }
                //Send selected pole and project restrictions (owners, attributes, etc...)
                poleDetailsViewController.pole = pole
                poleDetailsViewController.Owners = Owners
                poleDetailsViewController.TLAs = TLAs
                poleDetailsViewController.SFXs = SFXs
                poleDetailsViewController.PAs = PAs
            }
        }
    }
    
    //When poledetails screen closes, this method receives the updated Pole and updates it in the poles array
    func didReceiveValue(_ value: Pole) {
        
        lblText.text = "Done editing pole: \(value.SRCID)"
        //Update previously selected pole with current data and update annotation pin
        for pole in poles {
            if pole.SRCID == value.SRCID{
                //Matched, update the info
                pole.poledata = value.poledata
                pole.comments = value.comments
                pole.suppdata = "CHECKED"
                pole.VSUMInfo = updateVSUMInfo(pole: pole)
            }
        }
        //Update the annotation
        for annotation in annotations {
            if annotation.title == "\"" + value.SRCID + "\"" || annotation.title == value.SRCID{
                annotation.subtitle = value.poledata
                annotation.annotationColor = .green
                //Matched, update the annotation
                if let annotationView = map.view(for: annotation) {

                    annotationView.setNeedsDisplay()
                }
            }
        }
        
        writeToFile(fileName: "poles_active")
    }
    //______________________________________________
    //MARK: End Send and Receive data from other screens

    
    
    
    //MARK: Locate + Update Pole fuctions
    //____________________________
    //Adds timestamp to VSUMInfo of pole
    func updateVSUMInfo(pole: Pole) -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss" // set timestamp format
        if pole.VSUMInfo == ""{
            //Blank VSUMInfo, create a blank default one
            pole.VSUMInfo = "||||"
        }
        
        var components = pole.VSUMInfo.components(separatedBy: "|") // split string into array
        components[2] = dateFormatter.string(from: Date()) // update 2nd index with timestamp
        //Put a incremental value next, but check if at 999 first
        if counter == 999{
            //reset
            counter = 0
        }
        components[3] = String(format: "%03d%", counter)
        counter+=1 //increment the counter
        let updatedString = components.joined(separator: "|") // join array back into string
        
        
        return updatedString
    }
    
    //Searches array of poles and returns the matched pole based on SRCID
    func getSelectedPole(srcid: String) -> Pole? {
        for pole in poles{
            if pole.SRCID == srcid.replacingOccurrences(of: "\"", with: ""){
                //we got 'em
                return pole
            }
        }
        return nil
    }
    //______________________________________________
    //MARK: End Locate + Update Pole fuctions
    
    
    
    
    //MARK: File picker + Writing to Files
    //____________________________________
    //Reads the poles.txt file and updates the Poles array
    private func readPolesFile(selectedFileURL: URL) {
        do {
            
            //Check if poles has correct format: poles_dateTimeStamp.txt
            if let range = selectedFileURL.lastPathComponent.range(of: "^poles_(\\w+)\\.txt$", options: .regularExpression) {
                let someString = String(selectedFileURL.lastPathComponent[range].dropFirst(6).dropLast(4))
                //someString holds the date of the poles file
                self.poleFileDate = someString
                self.setSetting(value: someString, settingName: "PolesFileDate")
                print("Set pole file date \(someString) to: \(self.getSetting(settingName: "PolesFileDate"))")
            } else {
                self.showMessage(message: "Poles file does not follow typical poles file naming structure. Proceed with caution.")
                self.poleFileDate = ""
                self.setSetting(value: "", settingName: "PolesFileDate")
            }
            
            let fileContents = try String(contentsOf: selectedFileURL)
            let stringArr = fileContents.components(separatedBy: CharacterSet.newlines)
            //stringArr.removeFirst()
            //print("\(stringArr)")
            
            //self.plotCoord(stringArr: stringArr)
            
            //arrays stores each section of the file
            var arrays = [[String]]()
            var currentArray = [String]()

            // Loop through each line and append to the current array
            for string in stringArr {
                
                if string == ""{
                    
                } else if string == "_END_" {
                    // Append the current array to the 2D array and start a new array
                    arrays.append(currentArray)
                    currentArray = [String]()
                } else {
                    // Append the line to the current array
                    currentArray.append(String(string))
                }
            }
            // Append the last current array to the 2D array
            arrays.append(currentArray)

            
            //Clear any old arrays
            Owners.removeAll()
            TLAs.removeAll()
            SFXs.removeAll()
            PAs.removeAll()

            //MARK: FIRST - Read Poles
            if arrays.indices.contains(0) {
                var poles = arrays[0]
                poles.removeFirst()
                self.plotCoord(stringArr: poles)
            }

            //MARK: SECOND - Read Owners
            if arrays.indices.contains(1) {
                let ownerArray = arrays[1]
                if let ownerString = ownerArray.first?.components(separatedBy: "OWNR:").last {
                    Owners = ownerString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }

            //MARK: THIRD - Read TLA (Three Letter Attacher)
            if arrays.indices.contains(2) {
                let tlaArray = arrays[2]
                for line in tlaArray{
                    TLAs.append(line)
                }
            }

            //MARK: FOURTH - Read SFX (Attacher Attributes ex. "Dead", "Riser", etc... )
            if arrays.indices.contains(3) {
                let sfxArray = arrays[3]
                for line in sfxArray{
                    SFXs.append(line)
                }
            }

            //MARK: FIFTH - Read PA (Pole Attributes)
            if arrays.indices.contains(4) {
                let paArray = arrays[4]
                for line in paArray{
                    PAs.append(line)
                }
            }
            
            //Create a file for the poles
            writeToFile(fileName: "poles_active")
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        guard let selectedFileURL = urls.first else {
            return
        }
        
        //Check if an active poles file already exists
        if doesFileExist(fileName: "poles_active") && selectedFileURL.lastPathComponent != "poles_active.txt"{
            //Ask user if they want to open active poles file
            let alertController = UIAlertController(title: "Active Poles", message: "You already have an active poles file that hasn't been completed; selecting a new poles file will overwrite that currently active poles file. Continue?", preferredStyle: .alert)
            
            let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
                //Handle Yes action
                self.poles.removeAll()
                self.readPolesFile(selectedFileURL: selectedFileURL)
            }
            
            let noAction = UIAlertAction(title: "No", style: .cancel) { (action) in
                // Handle No action
            }
            
            alertController.addAction(yesAction)
            alertController.addAction(noAction)
            
            present(alertController, animated: true, completion: nil)
        }else{
            // Read the contents of the selected file
            self.readPolesFile(selectedFileURL: selectedFileURL)
        }
        // Dismiss the document picker
        controller.dismiss(animated: true, completion: nil)
    }
    
    //Event for if the user does not select a file
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User cancelled document picker
        lblText.text = "No Poles file selected. Select a poles file to continue..."
        // Dismiss the document picker
        controller.dismiss(animated: true, completion: nil)
    }
    
    //Writes to a file of given name as param
    func writeToFile(fileName: String){
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        //MARK: 1st - Poles
        
        var allPoles: String = "X,Y,comments,poledata,suppdata,VSUMInfo,SRCID,SRCOWN\n"
        
        for pole in poles {
            let singlePole = pole.toExportString()
            allPoles += singlePole + "\n"
        }
        
        allPoles += "_END_\n" //Ending of poles 'table'
        
        //MARK: 2nd - Owners
        var ownerStr = "OWNR:"
        for owner in Owners{
            ownerStr += owner + ","
        }
        ownerStr = String(ownerStr.dropLast())
        
        ownerStr += "\n"
        
        allPoles.append(ownerStr)
        
        allPoles += "_END_\n"
        
        
        //MARK: 3rd - TLAs
        var tlaStr = ""
        for tla in TLAs{
            tlaStr += tla + "\n"
        }
        tlaStr = String(tlaStr.dropLast())
        tlaStr += "\n"
        
        allPoles.append(tlaStr)
        allPoles += "_END_\n"
        
        //MARK: 4th - SFXs
        var sfxStr = ""
        for sfx in SFXs{
            sfxStr += sfx + "\n"
        }
        sfxStr = String(sfxStr.dropLast())
        sfxStr += "\n"
        
        allPoles.append(sfxStr)
        allPoles += "_END_\n"
        
        //MARK: 5th - PAs
        var paStr = ""
        for pa in PAs{
            paStr += pa + "\n"
        }
        paStr = String(paStr.dropLast())
        paStr += "\n"
        
        allPoles.append(paStr)
        allPoles += "_END_"
        
        
        
        let fileURL = documentsDirectory.appendingPathComponent("\(fileName).txt")
        do {
            try allPoles.write(to: fileURL, atomically: true, encoding: .utf8) //Changed to true
            // Delete the active poles file
            let fileManager = FileManager.default
            
            if fileName == "poles_completed"{
                try fileManager.removeItem(at: documentsDirectory.appendingPathComponent("poles_active.txt"))
                showMessage(message: "Poles uploaded as complete. Use PoleVAULT to import completed poles.")
            }
        } catch {
            print("Error writing to or deleting file: \(error)")
        }
        
    }
    
    //Function that returns whether a file exists or not
    func doesFileExist(fileName: String) -> Bool{
        let fileName = "\(fileName).txt"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return true
        } else {
            return false
        }
    }
    
    //Presents the files app to let user select the poles.txt file
    @IBAction func btnOpenFiles(_ sender: Any) {
        //Clear the current poles array:
       
        
        
        let message = "Tap on Browse in the bottom right corner and navigate to the shared folder location under \"Shared\" (Example: 192.168.0.1)."
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(documentTypes: [UTType.plainText.identifier], in: .import)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            documentPicker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            self.present(documentPicker, animated: true, completion: nil)
        }
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
        
    }
    //______________________________________________
    //MARK: End File picker + Writing to Files
    
    
    
    
    //MARK: Getting and Setting of Defaults (App Settings)
    //____________________________________________________
    //Set a string setting
    func setSetting(value: String, settingName: String){
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: settingName)
    }
    
    //Read a string setting
    func getSetting(settingName: String) -> String{
        if let setting: String = UserDefaults.standard.string(forKey: settingName){
            return setting
        }else{
            return ""
        }
    }
    //______________________________________________
    //MARK: End Getting and Setting of Defaults (App Settings)
    
    
    
    
    //Add poles to map as well as Poles array:
    func plotCoord(stringArr: [String]){
        //need to loop through and create points based on each line
        
        var lat: String
        var long: String
        var latDouble: Double!
        var longDouble: Double!
        
        //Clear any annotations
        map.removeAnnotations(annotations)
        
        for point in stringArr{
            if point == "" {
                
            }else{
                let tempPole = Pole()
                let tempData = splitCommaDelimitedString(point)
                tempPole.setData(strArr: tempData)
                poles.append(tempPole)
                long = tempData[0]
                lat = tempData[1]
                latDouble = Double(lat)
                longDouble = Double(long)
                
                lblText.text = lblText.text + ("\nLat: " + lat + "   Long: " + long)
                
                
                let coordinate = CLLocationCoordinate2D(latitude: latDouble, longitude: longDouble)
                
                let annotation = CustomPointAnnotation()
                
                annotation.coordinate = coordinate
                annotation.title = tempData[6]
                annotation.subtitle = tempPole.poledata
                annotation.type = "Poles"
                
                //Set the pole color here
                if tempPole.SRCID.contains("INSERT"){
                    annotation.annotationColor = .blue
                }
                else if tempPole.suppdata == "CHECKED"{
                    annotation.annotationColor = .green
                }else{
                    annotation.annotationColor = .red
                    
                }
                
                
                annotations.append(annotation)
                
                map.addAnnotation(annotation as CustomPointAnnotation)
                
                let annotationCoordinate = annotation.coordinate
                let regionRadius: CLLocationDistance = 1000 // meters
                let region = MKCoordinateRegion(center: annotationCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
                map.setRegion(region, animated: true)
            }
            
        }
        lblText.text = "Pole(s) mapped..."
        
    }
    
    //Get directions to closest pole
    func getDirectionsToClosestAnnotation() {
        guard let userLocation = map.userLocation.location else { return }
        // Find the closest annotation to the user's location that doesn't have a certain color
        guard let closestAnnotation = map.annotations
            .compactMap({ $0 as? CustomPointAnnotation })
            .filter({ $0.annotationColor != .green }) // skip annotations with a certain color
            .min(by: { userLocation.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) < userLocation.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)) })
        else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: closestAnnotation.coordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else { return }
            
            // Add the polyline to the map
            let polyline = route.polyline
            
            self.map.addOverlay(polyline)
            // Save the new polyline to the currentPolyline variable
            self.currentPolyline = polyline
            
            // Set the visible region of the map to show the entire route
            let routeRect = route.polyline.boundingMapRect
            self.map.setVisibleMapRect(routeRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
        }
    }
    
    
    
    
    //MARK: Button and Switch Functions
    //__________________________________
    //If switch is enabled, get directions to the nearest unclicked pole
    @IBAction func btnDirectionsTap(_ sender: Any) {
        if btnDirections.isOn{
            getDirectionsToClosestAnnotation()
        }else{
            if let polyline = currentPolyline {
                map.removeOverlay(polyline)
                currentPolyline = nil
            }
        }
    }
    
    //Export poles to a completed file
    @IBAction func btnExportTap(_ sender: Any) {
        //Construct and export the poles to a local text file for now
        writeToFile(fileName: "poles_\(getSetting(settingName: "PolesFileDate"))_completed")
    }
    
    //Add a new pole to the map
    @IBAction func btnInsertPoleTap(_ sender: Any) {
        
        //Create a pole to insert
        let insertPole = Pole()
        
        // Get the center point of the map view
        let mapCenterPoint = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        
        // Convert the center point to a coordinate
        let centerCoordinate = map.convert(mapCenterPoint, toCoordinateFrom: map)
        
        // Create an annotation with the center coordinate
        //let annotation = MKPointAnnotation()
        let annotation = CustomPointAnnotation()
        annotation.coordinate = centerCoordinate
        
        
        // Add the annotation to the map view
        map.addAnnotation(annotation)
        
        insertPole.X = annotation.coordinate.longitude
        insertPole.Y = annotation.coordinate.latitude
        insertPole.poledata = ",,,,,,,,,,,,,,,,,,,,"
        //Set SRCID as "INSERT(Timestamp)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss" // set timestamp format
        insertPole.SRCID = "INSERT\(String(describing: dateFormatter.string(from: Date())))"
        insertPole.VSUMInfo = "||||"
        insertPole.comments = ""
        insertPole.SRCOWN = ""
        insertPole.suppdata = ""
        poles.append(insertPole)
        
        annotation.title = insertPole.SRCID
        annotation.subtitle = insertPole.poledata
        annotations.append(annotation)
        
        insertCounter += 1
        
        writeToFile(fileName: "poles_active")
    }
    
    //Turns on or off crosshair on map
    @IBAction func btnCrosshairTap(_ sender: Any) {
        if btnCrosshair.isOn{
            crosshairView?.isHidden = false
        }else{
            crosshairView?.isHidden = true
        }
    }
    
    
    //Switch appearance of map to satellite or hybrid
    @IBAction func btnBaseMapTap(_ sender: Any) {
        if btnBaseMap.isOn{
            //Satellite view
            map.mapType = .hybrid
        }else{
            //Standard
            map.mapType = .standard
        }
    }
    
    
    
    
    
    
    //______________________________________________
    //MARK: End Button and Switch Functions
    
    
    
    
    //Takes a comma delimited string and returns the String array. Ignores commas inside ""s
    func splitCommaDelimitedString(_ str: String) -> [String] {
        //X,Y,comments,poledata,suppdata,VSUMInfo,SRCID,SRCOWN
        //0 = Long | 1 = Lat | 2 = comments | 3 = poledata | 4 = suppdata | 5 = VSUMInfo | 6 = SRCID | 7 = SRCOWN
        let pattern = #""[^"]*"|[^",]+"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: str, options: [], range: NSRange(str.startIndex..., in: str))
        let parts = matches.map { match -> String in
            let range = Range(match.range, in: str)!
            return String(str[range])
        }
        return parts
    }
    
    //Shows a pop up message with the passed string as the message
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
    
    //Just a button to temporarily test things
    @IBAction func btnTestTap(_ sender: Any) {
        //Button for testing different things
    }
}











