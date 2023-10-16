//  ViewController.swift
//  PVLite
//
//  Created by Erik Taylor on 3/3/23.
//  This is the main view controller that displays a map and let's user plot points and lines on the map

import UIKit
import UniformTypeIdentifiers
import Foundation
import MobileCoreServices
import MapKit
import ZIPFoundation
import FirebaseStorage
import AVFoundation
import Gzip

//Main Map Screen
class ViewController: UIViewController, UIDocumentPickerDelegate, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate, UITextViewDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    //Map Related Items
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    var crosshairView: UIView!
    
    //Buttons and Labels on Map
    @IBOutlet weak var btnCrosshair: ToggleButton!
    @IBOutlet weak var btnCenter: ToggleButton!
    @IBOutlet weak var btnBaseMap: ToggleButton!
    @IBOutlet weak var btnDirections: ToggleButton!
    @IBOutlet weak var btnImport: UIButton!
    @IBOutlet weak var btnExport: UIButton!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var btnZoomIn: UIButton!
    @IBOutlet weak var btnZoomOut: UIButton!
    @IBOutlet weak var btnRotate: UIButton!
    @IBOutlet weak var btnInsert: UIButton!
    @IBOutlet weak var lblInfo: UITextView!
    @IBOutlet weak var lblPoleCount: UITextView!
    
    
    
    //Poles.txt contents (poles, Owners, TLAs, etc...)
    var poles: [Pole] = [] //MARK: This contains all poles and their data. Essentially the poles table
    var Owners = [String]()
    var TLAs = [String]()
    var SFXs = [String]()
    var PAs = [String]()
    var polesDictionary: [String: Pole] = [:] //Dictionary for easy lookup

    //Counters
    var insertCounter: Int32 = 0 //Tracks insert count
    var counter: Int = 0 //For incremental values in VSUMInfo and elsewhere if needed
    var polesCompleted: Int = 0 //Tracks poles clicked for a workarea (regardless of date)
    var polesClicked: Int = 0 //Tracks poles clicked (with date in mind)
    
    //Map Objects
    var annotations = [CustomPointAnnotation()] //Annotations (pins on map)
    var currentPolyline: MKPolyline? //A polyline for directions
    var otherPoints = [CLLocationCoordinate2D]() //Holds other coordinate data for objects (reference poles, transformers, etc...)
    var otherAnnotations = [CustomPointAnnotation()] //Holds other coordinate data for objects (reference poles, transformers, etc...)
    var displayedPolylineOverlays: Set<Int> = [] //Array for the polylines within the given map region
    var polylineDict: [Int: MKPolyline] = [:] //Holds polylines such as primary lines
    var polylineDictSecondary: [Int: MKPolyline] = [:] //Holds polylines such as primary lines
    var multiPolylineDict: [Int : MKMultiPolyline] = [:]
    
    //Other
    var fileURL: String = "" //Stores a file path
    var poleFileDate: String = "" //Used to store date on poles file
    let settings = UserDefaults.standard //To read settings
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium) //Haptic feedback
    var circleImageCache: [UIColor: UIImage] = [:] //Stores pole symbols + colors
    var redBorderView: RedBorderView?
    var moveModeOverlay: UIView?
    var poleToMove: Pole?
    var poleToMoveIndex: Int?
    var shouldMoveAnnotation = false
    var totalMapItems: Int = 0
    var updateTimer: Timer?
    var polePaddingSize: Int?
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer?
    var sessionQueue: DispatchQueue = DispatchQueue(label: "session queue") // Dedicated queue for session configuration

    
    
//MARK: View Functions________________________________________________________________________________________
    //Startup code -- Load Map and Visual Settings
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //MARK: If you want to clear all user defaults, enable this, but the comment it out after ran once
        //resetUserDefaults()
        
        initializeMap()

        initializeLocationManager()
        
        initializeUIButtons()
        
        initializeLabels()
        
        initializeGestureRecgonizers()
        
        initializeBorder()
        
        initializeSettings()
        
        //Side menu that expands to show layers (needs work)
        let sideMenu = ExpandableSideMenu(frame: view.bounds)
        view.addSubview(sideMenu)
        sideMenu.parentViewController = self
        
        captureSession = AVCaptureSession()
    }
    
    //Each Time View is Loaded, Check if User has a Username (TODO: replace with login screen)
    override func viewDidAppear(_ animated: Bool) {
        let username = getUsername()
        if !username.isEmpty {
            lblInfo.text = "Hi \(username), import a poles file to continue..."
        } else {
            changeUsername()
        }
    }
//MARK: End View Functions________________________________________________________________________________________
    
    
    
    
//MARK: Map Functions________________________________________________________________________________________
    //Change how Objects Render on Map
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        //For objets that are not poles
        if annotation.title == "Other" {
            guard let customAnnotation = annotation as? CustomPointAnnotation else {
                return nil
            }
            let reuseIdentifier = annotation.subtitle ?? ""
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier!) as? CustomAnnotationView
            
            let annotationSize: CGSize
            switch reuseIdentifier {
            case "Reference":
                annotationSize = CGSize(width: 9, height: 9)
            case "Transformer":
                annotationSize = CGSize(width: 20, height: 20)
            case "Light":
                annotationSize = CGSize(width: 11, height: 11)
            default:
                annotationSize = CGSize(width: 0, height: 0)
            }
            
            if annotationView == nil {
                annotationView = CustomAnnotationView(annotation: customAnnotation, reuseIdentifier: reuseIdentifier, size: annotationSize)
                annotationView?.isEnabled = false
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }else{
            //How poles are rendered. Can change the color of the pins here
            guard let annotation = annotation as? MKPointAnnotation else {
                return nil
            }

            let identifier = "PoleAnnotation"
            var view: PoleAnnotation

            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PoleAnnotation {
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                view = PoleAnnotation(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
            }

            view.mapView = map // Set the mapView property

            // Update the pin color based on the poleDataColorDict dictionary
            var pinColor = UIColor.red // default color

            // Create a dictionary mapping pole data to colors
            let poleDataColorDict: [String: UIColor] = [
                "LTON": .yellow,
                "LTOFF": .black,
                "NLT": .purple,
                "DELETE": .systemMint,
            ]

            if let pole = polesDictionary[(annotation.title ?? "")!] {
                for (data, color) in poleDataColorDict {
                    if pole.poledata.contains(data) || pole.comments.contains(data) {
                        pinColor = color
                        break
                    }
                }
            }

            // Make the symbol a circle
            view.image = circleImage(for: pinColor)

            // Disable clustering (fades symbols in/out based on zoom level)
            view.clusteringIdentifier = nil

            //Get a count of total objects and 'reset' map if number gets too high
            //totalMapItems += (mapView.annotations.count + mapView.overlays.count)

            //print(totalMapItems)

            return view
        }
    }
    
    // Create a structure to store annotations and their corresponding MKMapPoints for quick lookup
    struct AnnotationData {
        let annotation: MKAnnotation
        let mapPoint: MKMapPoint
    }

    var polesEnabled: Bool = true
    
    
    // Adds Point Objects Besides Poles Based on the Current Map Region and a Map Zoom Level. Poles are Added Last (no zoom restriction)
    func addAnnotationsForVisibleRegion(region: MKCoordinateRegion) {
        let visibleMapRect = map.visibleMapRect

            // Calculate the size of the visible map region in square kilometers.
            let regionWidthKm = region.span.latitudeDelta * 111
            let regionHeightKm = region.span.longitudeDelta * 111
            let visibleRegionSizeKm2 = regionWidthKm * regionHeightKm

            // Preprocess otherAnnotations and annotations into AnnotationData for quick lookup
            let otherAnnotationData = otherAnnotations.map { AnnotationData(annotation: $0, mapPoint: MKMapPoint($0.coordinate)) }
            let annotationData = annotations.map { AnnotationData(annotation: $0, mapPoint: MKMapPoint($0.coordinate)) }

            // Check if the visible region size is below the threshold of 1 square kilometer
            if visibleRegionSizeKm2 <= 5  { //1
                for other in otherAnnotationData {
                    if visibleMapRect.contains(other.mapPoint) {
                        // Directly add the annotation if it's in the visible region, no distance check to other annotations
                        map.addAnnotation(other.annotation)
                    }
                }
            } else {
                // Remove all existing annotations if the visible region size exceeds the threshold.
                map.removeAnnotations(map.annotations)
            }

        //map.removeAnnotations(map.annotations)

            // Add poles only if poles are enabled
            if polesEnabled {
                for annotation in annotationData {
                    if visibleMapRect.contains(annotation.mapPoint) {
                        map.addAnnotation(annotation.annotation)
                    }
                }
            }
    }
    




    func addPolylinesForVisibleRegion(region: MKCoordinateRegion) {
        let visibleMapRect = map.visibleMapRect

        let regionWidthKm = region.span.latitudeDelta * 111
        let regionHeightKm = region.span.longitudeDelta * 111
        let visibleRegionSizeKm2 = regionWidthKm * regionHeightKm

        var newDisplayedPolylineOverlays: Set<Int> = []

        var primaryMax: Double = 0.0
        if settings.object(forKey: "PrimaryMax") != nil {
            primaryMax = Double(settings.integer(forKey: "PrimaryMax"))
        }
        if visibleRegionSizeKm2 <= 30 {
            for (objectID, polyline) in polylineDict {
                if visibleMapRect.intersects(polyline.boundingMapRect) {
                    var shouldAddPolyline = false

                    for i in 0..<polyline.pointCount {
                        let mapPoint = polyline.points()[i]
                        let thresholdDistance: Double = 5000
                        var isWithinThreshold = false

                        for annotation in map.annotations {
                            let annotationMapPoint = MKMapPoint(annotation.coordinate)
                            let distance = mapPoint.distance(to: annotationMapPoint)
                            if distance <= thresholdDistance {
                                isWithinThreshold = true
                                break
                            }
                        }

                        if isWithinThreshold {
                            shouldAddPolyline = true
                            break
                        }
                    }

                    if shouldAddPolyline {
                        if !displayedPolylineOverlays.contains(objectID) {
                            map.addOverlay(polyline)
                        }
                        newDisplayedPolylineOverlays.insert(objectID)
                    }
                }
            }
        } else if visibleRegionSizeKm2 > 20 {
            for (objectID, polyline) in polylineDict {
                if polyline.title == "WorkArea" {
                    map.addOverlay(polyline)
                    newDisplayedPolylineOverlays.insert(objectID)
                }
            }
        } else {
            let currentOverlays = map.overlays.filter { !($0 is MKPolyline) }
            map.removeOverlays(currentOverlays)
        }

        if visibleRegionSizeKm2 <= 5 {
            for (objectID, multiPolyline) in multiPolylineDict {
                var shouldAddMultiPolyline = false

                for polyline in multiPolyline.polylines {
                    if visibleMapRect.intersects(polyline.boundingMapRect) {
                        for i in 0..<polyline.pointCount {
                            let mapPoint = polyline.points()[i]
                            let thresholdDistance: Double = 2
                            var isWithinThreshold = false

                            for annotation in map.annotations {
                                if annotation.title != "Other" {
                                    let annotationMapPoint = MKMapPoint(annotation.coordinate)
                                    let distance = mapPoint.distance(to: annotationMapPoint)
                                    if distance <= thresholdDistance {
                                        isWithinThreshold = true
                                        break
                                    }
                                }
                            }

                            if isWithinThreshold {
                                shouldAddMultiPolyline = true
                                break
                            }
                        }

                        if shouldAddMultiPolyline {
                            break
                        }
                    }
                }

                if shouldAddMultiPolyline {
                    if !displayedPolylineOverlays.contains(objectID) {
                        map.addOverlay(multiPolyline)
                    }
                    newDisplayedPolylineOverlays.insert(objectID)
                }
            }
        } else {
            let currentOverlays = map.overlays.filter { !($0 is MKPolyline) }
            map.removeOverlays(currentOverlays)
        }

        let overlaysToRemove = displayedPolylineOverlays.subtracting(newDisplayedPolylineOverlays)
        for objectID in overlaysToRemove {
            if let overlay = polylineDict[objectID] {
                map.removeOverlay(overlay)
            }
            if let overlay = polylineDictSecondary[objectID] {
                map.removeOverlay(overlay)
            }
        }

        displayedPolylineOverlays = newDisplayedPolylineOverlays
    }
    
    
    //When the Map Region Changes, Add Poles and Other Layers Accordingly
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        //map.removeAnnotations(map.annotations)
        
        // Add new annotations for the visible region.
        addAnnotationsForVisibleRegion(region: mapView.region)
        if !polylineDict.isEmpty{
            addPolylinesForVisibleRegion(region: mapView.region)
        }
        if !polylineDictSecondary.isEmpty{
            addPolylinesForVisibleRegion(region: mapView.region)
        }
        if !multiPolylineDict.isEmpty{
            addPolylinesForVisibleRegion(region: mapView.region)
        }
        
    }
    
    
    //Disables the User from Accidentally Selecting Their Own Location on the Map
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        if let userLocationAnnotationView = map.view(for: map.userLocation) {
            userLocationAnnotationView.isSelected = false
        }
    }
    
    
    //When a Pole is Selected on the Map, Open the Selected Pole's Details Screen
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        
        //Vibrate
        feedbackGenerator.impactOccurred()

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
            //Increase pole counter
            if selectedPole.suppdata != "CHECKED"{
                polesClicked += 1
            }

            //Show poledetails screen
            performSegue(withIdentifier: "mapToPoleSegue", sender: selectedPole)
        }
    }
    
    
    //For Line Layers, Change how they Render
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        
        
        if let multiPolyline = overlay as? MKMultiPolyline {
            let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.85)
                let renderer = MKMultiPolylineRenderer(multiPolyline: multiPolyline)
                renderer.strokeColor = color
                renderer.lineWidth = 1.0
                return renderer
            }
        
        
        // Check if the object to display is a polyline, turn it light blue
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        
        
        
        if polyline.title == "Primary"{
            //Check if a color setting is saved
            if let colorData = UserDefaults.standard.object(forKey: "PrimaryColor") as? Data,
               let savedColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? UIColor {
                let color = savedColor
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
                return renderer
            }else{
                let color = UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
                return renderer
            }

        }else{
            //Default
            let color = UIColor(red: 0.98, green: 0.0, blue: 0.0, alpha: 0.8)
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = color
            //renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
            renderer.lineWidth = 2
            return renderer
        }
        
        

    }
    
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        if newState == .ending {
            let newCoordinate = view.annotation!.coordinate
            if let index = poles.firstIndex(where: { $0.SRCID == view.annotation?.title ?? "" }) {
                poles[index].comments = ""
                poles[index].X = newCoordinate.longitude
                poles[index].Y = newCoordinate.latitude
                lblInfo.text = "Successfully moved and updated pole: \(poles[index].SRCID)"
                writeToFile(fileName: "poles_active"){}
            }
        }
    }
    
    
    //For Moving Poles
    @objc private func  handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if shouldMoveAnnotation, let index = poleToMoveIndex {
                let touchLocation = gestureRecognizer.location(in: map)
                let newCoordinate = map.convert(touchLocation, toCoordinateFrom: map)

                // Find the corresponding annotation and update its coordinate
                if let annotation = map.annotations.first(where: { ($0 as? MKPointAnnotation)?.title == poles[index].SRCID }) as? MKPointAnnotation {
                    annotation.coordinate = newCoordinate
                    poles[index].comments = ""
                    poles[index].X = newCoordinate.longitude
                    poles[index].Y = newCoordinate.latitude
                }

                // Reset the flag and the reference to the pole
                shouldMoveAnnotation = false
                poleToMoveIndex = nil
            
//            // Remove the grey overlay view
//                   moveModeOverlay?.removeFromSuperview()
//                   moveModeOverlay = nil
            
            redBorderView?.isHidden = true
            
            lblInfo.text = "Successfully moved and updated pole: \(poles[index].SRCID)"
            writeToFile(fileName: "poles_active"){}
            }
    }
    
    
    //Center Map on User's Location if Option is Selected
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        if btnCenter.isOn{
            map.setCenter(userLocation.coordinate, animated: true)
        }
        if btnDirections.isOn {
               // If the timer is not initialized or is invalidated, create a new one
               if updateTimer == nil || !(updateTimer?.isValid ?? false) {
                   updateTimer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: false, block: { [weak self] _ in
                       self?.updateDistanceAndETA()
                   })
               }
           } else {
               // Invalidate the timer if the directions button is off
               updateTimer?.invalidate()
               updateTimer = nil
           }
    }
    
    //Map startup state
    func initializeMap(){
        map.showsUserLocation = true
        map.delegate = self
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.isPitchEnabled = false
        map.userTrackingMode = .follow
            
        let mapType = settings.string(forKey: "MapType") ?? "Standard"
        map.mapType = mapType == "Satellite" ? .hybrid : .standard
    }
//MARK: End Map Functions________________________________________________________________________________________
    
    
    
    
//MARK: Send and Receive Data from Other Views___________________________________________________________________
    //Sets Pole Object in Pole Details Screen
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
    
    
    //When Pole Details Screen is Closed, the Pole is Returned Here
    func didReceiveValue(_ value: Pole) {
        
        
        var tempStr = ""
        
        //MARK: See if i can attempt a move pole function
        if value.comments == "MOVE" {
                if let index = poles.firstIndex(where: { $0.SRCID == value.SRCID }) {
                    poleToMoveIndex = index
                    shouldMoveAnnotation = true
                    tempStr = "Tap new location of selected pole..."
                    // Create and show the grey overlay view
                    redBorderView?.isHidden = false
                }
            }
        
        
        
        
        
        //Update label to move or not
        if tempStr != ""{
            lblInfo.text = tempStr
        }else{
            lblInfo.text = "Done Editing Pole: \(value.SRCID)"
        }
        //Update previously selected pole with current data and update annotation pin
        
        for pole in poles {
            //Go through poles and match based on SRCID MARK: More Efficient Way for this?
            if pole.SRCID == value.SRCID{
                pole.poledata = value.poledata
                pole.comments = value.comments
                pole.suppdata = "CHECKED"   //All PVLite clicked poles will have CHECKED in suppdata
                pole.VSUMInfo = updateVSUMInfo(pole: pole)
            }
        }
        //Update the annotation MARK: Again, More Efficient way? Can do this when going through poles to avoid two loops?
        for annotation in annotations {
            if annotation.title == "\"" + value.SRCID + "\"" || annotation.title == value.SRCID{
                //Matched, update the annotation
                annotation.subtitle = value.poledata
                annotation.annotationColor = .green
                
                if let annotationView = map.view(for: annotation) {
                    annotationView.setNeedsDisplay()
                }
            }
            if annotation.annotationColor == .green{
                polesCompleted += 1
            }
            lblPoleCount.text = "\(polesCompleted) / \(annotations.count)"
            
        }
        polesCompleted = 0
        writeToFile(fileName: "poles_active"){} //Every time a poles is clicked, update the active poles file
        
        
        //Check if user is in 'guide' mode and give directions to next pole if so
        if btnDirections.isOn{
            if let polyline = currentPolyline {
                map.removeOverlay(polyline)
                currentPolyline = nil
            }
            getDirectionsToClosestAnnotation()
        }
    }
//MARK: End Send and Receive data from other screens________________________________________________________________________
    
    
    
    
//MARK: Locate + Update Pole Fuctions________________________________________________________________________________________
    //Creates and returns a VSUMInfo string for pole MARK: Only thing missing is State column in VSUMInfo[1]
    func updateVSUMInfo(pole: Pole) -> String{
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyyMMddHHmmss" // set timestamp format
//        if pole.VSUMInfo == ""{
//            //Blank VSUMInfo, create a blank default one
//            //print("\n\n\n\n\nBlank vsuminfo\n\nn\n\n")
//            pole.VSUMInfo = "||||"
//        }
//
//        var components = pole.VSUMInfo.components(separatedBy: "|") // split string into array
//        components[0] = getUsername()
//        components[2] = dateFormatter.string(from: Date()) // update 2nd index with timestamp
//        //Put a incremental value next, but check if at 999 first
//        if counter == 999{
//            //reset
//            counter = 0
//        }
//        components[3] = String(format: "%03d%", counter)
//        counter+=1 //increment the counter
//        let updatedString = components.joined(separator: "|") // join array back into string
//
//
//        return updatedString
        
        let dateFormatter = DateFormatter()
           dateFormatter.dateFormat = "yyyyMMddHHmmss" // set timestamp format

           var components = pole.VSUMInfo.components(separatedBy: "|") // split string into array

           while components.count < 4 { // Add empty elements if components does not have enough elements
               components.append("")
           }

           components[0] = getUsername()
           components[2] = dateFormatter.string(from: Date()) // update 2nd index with timestamp
           //Put an incremental value next, but check if at 999 first
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
    
    
    //Get directions to closest pole
    func getDirectionsToClosestAnnotation(){
        guard let userLocation = map.userLocation.location else { return }
        // Find the closest annotation to the user's location that doesn't have a certain color
        guard let closestAnnotation = annotations
            .compactMap({ $0 })
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
            let polyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            
            self.map.addOverlay(polyline)
            // Save the new polyline to the currentPolyline variable
            self.currentPolyline = polyline
            
            // Set the label to show ETA time to pole
                let travelTime = route.expectedTravelTime
                let timeString = String(format: "%.0f min", travelTime / 60)
            
            let distance = route.distance * 0.000621371 // Convert to miles (1 meter = 0.000621371 miles)
                let distanceString = String(format: "%.2f mi", distance)

            self.lblInfo.text = "ETA:\(timeString)\t\tDistance: \(distanceString)"
        }
    }

    func updateDistanceAndETA() {
        guard let userLocation = map.userLocation.location else { return }
        
        // Find the closest annotation to the user's location that doesn't have a certain color
        guard let closestAnnotation = annotations
            .compactMap({ $0 })
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
            
            // Set the label to show ETA time to pole
            let travelTime = route.expectedTravelTime
            let timeString = String(format: "%.0f min", travelTime / 60)
            
            let distance = route.distance * 0.000621371 // Convert to miles (1 meter = 0.000621371 miles)
            let distanceString = String(format: "%.2f mi", distance)
            
            self.lblInfo.text = "ETA:\(timeString)\t\tDistance: \(distanceString)"
        }
    }
//MARK: End Locate + Update Pole Fuctions________________________________________________________________________________________
    
    
    
    
//MARK: File picker + Reading/Writing to Files________________________________________________________________________________
    //Presents the files app to let user select the files
    @IBAction func btnOpenFiles(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
                
            let alertController = UIAlertController(title: nil, message: "How would you like to proceed?", preferredStyle: .actionSheet)
            
            let documentPickerAction = UIAlertAction(title: "Import from file", style: .default) { _ in
                let types: [UTType] = [UTType.plainText, UTType(filenameExtension: "zip")].compactMap { $0 }
                let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types)
                documentPicker.delegate = self
                documentPicker.allowsMultipleSelection = false
                self.present(documentPicker, animated: true, completion: nil)
            }
            
            let scanQRCodeAction = UIAlertAction(title: "Scan QR Code", style: .default) { _ in
                // Call your method to start the QR code scanning process.
                
                self.sessionQueue.async { [weak self] in
                            guard let self = self else { return }
                            if self.captureSession.isRunning {
                                DispatchQueue.main.async {
                                    self.captureSession.stopRunning()
                                    self.previewLayer?.removeFromSuperlayer()
                                    self.previewLayer = nil
                                }
                            } else {
                                self.setupCaptureSession()
                            }
                        }
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(documentPickerAction)
            alertController.addAction(scanQRCodeAction)
            alertController.addAction(cancelAction)
            
            if let popoverPresentationController = alertController.popoverPresentationController {
                popoverPresentationController.sourceView = self.view  // to present in the center of the view
                popoverPresentationController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverPresentationController.permittedArrowDirections = []  // to hide the arrow of the popover
            }
            
            self.present(alertController, animated: true, completion: nil)

    }
    
    
    //Reads the Poles and Other Layers (OWNR/TLAs/etc...)
    private func readPolesFile(selectedFileURL: URL) {
        do {
            
            //Check if poles has correct format: poles_dateTimeStamp.txt
            if let range = selectedFileURL.lastPathComponent.range(of: "^poles_(\\w+)\\.txt$", options: .regularExpression) {
                let someString = String(selectedFileURL.lastPathComponent[range].dropFirst(6).dropLast(4))
                //someString holds the date of the poles file
                self.poleFileDate = someString
                self.setSetting(value: someString, settingName: "PolesFileDate")
            } else {
                self.showMessage(message: "Poles file does not follow typical poles file naming structure. Proceed with caution.")
                self.poleFileDate = ""
                self.setSetting(value: "", settingName: "PolesFileDate")
            }
            
            
            let fileContents = try String(contentsOf: selectedFileURL)
            let stringArr = fileContents.components(separatedBy: CharacterSet.newlines)
            
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
            writeToFile(fileName: "poles_active"){}
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
    }
    
    
    
    
    //Add poles to map and Poles array:
    func plotCoord(stringArr: [String]){
        
        //Filter out empty strings before processing
            let nonEmptyPoints = stringArr.filter { !$0.isEmpty }

            //Clear poles and counts
            map.removeAnnotations(annotations)
            annotations = []
            polesCompleted = 0

            for point in nonEmptyPoints {
                let tempPole = Pole()
                let tempData = splitCommaDelimitedString(point)
                tempPole.setData(strArr: tempData)
                poles.append(tempPole)
                polesDictionary[tempPole.SRCID] = tempPole // Store in dictionary for quick lookup

                guard let latDouble = Double(tempData[1]), let longDouble = Double(tempData[0]) else {
                    continue
                }

                let coordinate = CLLocationCoordinate2D(latitude: latDouble, longitude: longDouble)
                let annotation = CustomPointAnnotation()

                annotation.coordinate = coordinate
                annotation.title = tempData[6] //SRCID
                annotation.subtitle = tempPole.poledata
                annotation.type = "Poles"

                // Set the pole color here
                if tempPole.SRCID.contains("INSERT"){
                    annotation.annotationColor = .blue
                } else if tempPole.suppdata == "CHECKED" {
                    annotation.annotationColor = .green
                } else {
                    annotation.annotationColor = .red
                }

                annotations.append(annotation)

                map.addAnnotation(annotation)

                let annotationCoordinate = annotation.coordinate
                let regionRadius: CLLocationDistance = 1000
                let region = MKCoordinateRegion(center: annotationCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
                map.setRegion(region, animated: true)
            }
            lblInfo.text = "Pole(s) mapped..."
    }
    
    
    //Reads other file types MARK: For now, just Primary, Transformers, and Reference
    private func readOtherFile(selectedFileURL : URL){
        do {
            
            let fileContents = try String(contentsOf: selectedFileURL)
            var stringArr = fileContents.components(separatedBy: CharacterSet.newlines)
            stringArr.removeFirst() // Remove X,Y column
            
            //Test which file has been selected:
            if selectedFileURL.lastPathComponent == "Primary.txt"{
                var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
                
                for line in stringArr {
                    if !line.isEmpty {
                        let components = line.components(separatedBy: ",")
                        if components.count == 4,
                           let objectID = Int(components[0]),
                           let index = Int(components[1]),
                           let x = Double(components[2]),
                           let y = Double(components[3]) {
                            
                            let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
                            if var coordinates = tempPolylineCoordinatesDict[objectID] {
                                // Insert the coordinate at the correct index
                                while coordinates.count <= index {
                                    coordinates.append(CLLocationCoordinate2D())
                                }
                                coordinates[index] = coordinate
                                tempPolylineCoordinatesDict[objectID] = coordinates
                            } else {
                                tempPolylineCoordinatesDict[objectID] = [coordinate]
                            }
                        }
                    }
                }
                
                // Create MKPolyline objects for each set of coordinates and store them in the dictionary
                for (objectID, coordinates) in tempPolylineCoordinatesDict {
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polylineDict[objectID] = polyline
                    polylineDict[objectID]?.title = "Primary"
                }
                
            }else if selectedFileURL.lastPathComponent == "Secondary.txt"{
                
                
                //ATTEMPTING MULTIPOLYLINE HERE
                var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
                
                
                for line in stringArr {
                        if !line.isEmpty {
                            let components = line.components(separatedBy: ",")
                            if components.count == 4,
                               let objectID = Int(components[0]),
                               let index = Int(components[1]),
                               let x = Double(components[2]),
                               let y = Double(components[3]) {
                                
                                let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
                                if var coordinates = tempPolylineCoordinatesDict[objectID] {
                                    // Insert the coordinate at the correct index
                                    coordinates.insert(coordinate, at: index)
                                    tempPolylineCoordinatesDict[objectID] = coordinates
                                } else {
                                    tempPolylineCoordinatesDict[objectID] = [coordinate]
                                }
                            }
                        }
                    }
                
                // Create MKPolyline objects for each set of coordinates and store them in the dictionary
                    for (objectID, coordinates) in tempPolylineCoordinatesDict {
                        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                        polyline.title = "Secondary"
                        
                        if let existingMultiPolyline = multiPolylineDict[objectID] {
                            let updatedPolylines = existingMultiPolyline.polylines + [polyline]
                            multiPolylineDict[objectID] = MKMultiPolyline(updatedPolylines)
                        } else {
                            let multiPolyline = MKMultiPolyline([polyline])
                            multiPolylineDict[objectID] = multiPolyline
                        }
                    }
                
                
                
                
                
                
            }
            
            
            
            
            else if selectedFileURL.lastPathComponent == "WorkArea.txt"{
                var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
                
                for line in stringArr {
                    if !line.isEmpty {
                        let components = line.components(separatedBy: ",")
                        if components.count == 4,
                           let objectID = Int(components[0]),
                           let index = Int(components[1]),
                           let x = Double(components[2]),
                           let y = Double(components[3]) {
                            
                            let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
                            if var coordinates = tempPolylineCoordinatesDict[objectID] {
                                // Insert the coordinate at the correct index
                                while coordinates.count <= index {
                                    coordinates.append(CLLocationCoordinate2D())
                                }
                                coordinates[index] = coordinate
                                tempPolylineCoordinatesDict[objectID] = coordinates
                            } else {
                                tempPolylineCoordinatesDict[objectID] = [coordinate]
                            }
                        }
                    }
                }
                
                // Create MKPolyline objects for each set of coordinates and store them in the dictionary
                for (objectID, coordinates) in tempPolylineCoordinatesDict {
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polylineDict[objectID] = polyline
                    polylineDict[objectID]?.title = "WorkArea"
                }
                
            }
            
            
            
            
            
            else if selectedFileURL.lastPathComponent == "Reference.txt" || selectedFileURL.lastPathComponent == "Transformer.txt"{
                for point in stringArr {
                    guard !point.isEmpty else { continue }
                    let tempData = splitCommaDelimitedString(point)
                    
                    if let lat = Double(tempData[1]), let long = Double(tempData[0]) {
                        
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        let annotation = CustomPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = "Other"
                        
                        switch selectedFileURL.lastPathComponent {
                        case "Reference.txt":
                            if tempData.count > 2 && tempData[2] == "Light" {
                                annotation.subtitle = "Light"
                            } else {
                                annotation.subtitle = "Reference"
                            }
                            
                        case "Transformer.txt":
                            annotation.subtitle = "Transformer"
                        default:
                            annotation.subtitle = "Other"
                        }
                        
                        otherAnnotations.append(annotation)
                    }
                    
                }
            }
            lblInfo.text = "Object(s) mapped..."
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
        
    }
    

    //When user selects a poles file, check if an active poles file already exists, and ask the user if they want to overwrite
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        guard let selectedFileURL = urls.first else {
            return
        }
        
        if selectedFileURL.lastPathComponent.contains(".zip"){
            //Check if zip file and if so, unzip it to pvlite folder
            if let documentsURL = documentsDirectoryURL() {
                let destinationURL = documentsURL.appendingPathComponent("unzippedFiles")
                unzipFile(at: selectedFileURL, to: destinationURL)
            } else {
                print("Unable to get the Documents directory URL")
            }
        }else//Check if there is an active file and the user selected something besides that active file
        if doesFileExist(fileName: "poles_active") && selectedFileURL.lastPathComponent != "poles_active.txt"{
            //Ask user if they want to open active poles file
            if selectedFileURL.lastPathComponent.contains("poles"){
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
                //Attempting to add a 'layer' file here...
                //File should just contain x/y coords
                self.readOtherFile(selectedFileURL: selectedFileURL)
            }


        }else{
            // Read the contents of the selected file
            self.readPolesFile(selectedFileURL: selectedFileURL)
        }
        // Dismiss the document picker
        controller.dismiss(animated: true, completion: nil)
    }
    
    
    //GEOSET FUNCTIONS
    func loadGeoset(filePath: URL){

    }
    
    //END GEOSET FUNCTIONS
    
    func documentsDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        
        do {
            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsURL
        } catch {
            print("Error getting the Documents directory URL: \(error)")
            return nil
        }
    }
    
    
    //If user does not select a file, do nothing
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User cancelled document picker
        lblInfo.text = "No Poles file selected. Select a poles file to continue..."
        // Dismiss the document picker
        controller.dismiss(animated: true, completion: nil)
    }
    
    
    //Writes the poles and other content (OWNRs, TLAs, etc...) to a file of given name as param
    func writeToFile(fileName: String, completion: @escaping () -> Void){
        
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
            
            completion()
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
    
    
    //Zip poles and any pictures
    func zipCompletedAndJPGFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
               return
           }

           let fileManager = FileManager.default
           let destinationURL = documentsDirectory.appendingPathComponent("archive.zip")

           do {
               // Remove the existing zip file if it exists
               if fileManager.fileExists(atPath: destinationURL.path) {
                   try fileManager.removeItem(at: destinationURL)
               }

               // Create a new zip file
               let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])

               let archive = Archive(url: destinationURL, accessMode: .create)
               for fileURL in files {
                   let fileExtension = fileURL.pathExtension
                   let isCompletedTextFile = fileExtension == "txt" && fileURL.lastPathComponent.contains("completed")
                   let isJPEGFile = fileExtension == "jpg"

                   if isCompletedTextFile || isJPEGFile {
                       try archive?.addEntry(with: fileURL.lastPathComponent, relativeTo: documentsDirectory)
                   }
               }

               print("Zipped files to \(destinationURL.path)")
           } catch {
               print("Error zipping files: \(error)")
           }
    }

    
    //Unzips a given zip file to a destination
    func unzipFile(at sourceURL: URL, to destinationURL: URL) {
        let fileManager = FileManager()
        
        let customFolderName = sourceURL.deletingPathExtension().lastPathComponent
        let customDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(customFolderName)


            do {
                try fileManager.createDirectory(at: customDestinationURL, withIntermediateDirectories: true, attributes: nil)
                try fileManager.unzipItem(at: sourceURL, to: customDestinationURL)
                deleteMacOSXFolder(in: customDestinationURL)
                lblInfo.text = "File successfully unzipped..."
                let message = "Tap on Browse in the bottom right corner and navigate to the shared folder location under \"Shared\" (Example: 192.168.0.1)."
                let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                    let documentPicker = UIDocumentPickerViewController(documentTypes: [UTType.plainText.identifier, "public.zip-archive"], in: .import)
                    documentPicker.delegate = self
                    documentPicker.allowsMultipleSelection = false
                    documentPicker.directoryURL = customDestinationURL
                    self.present(documentPicker, animated: true, completion: nil)
                }
                alertController.addAction(okAction)
                
                present(alertController, animated: true, completion: nil)

            } catch {
                
            }
    }
    
    func deleteMacOSXFolder(in folderURL: URL) {
        let fileManager = FileManager()
        let macOSXFolderURL = folderURL.appendingPathComponent("__MACOSX")
        
        if fileManager.fileExists(atPath: macOSXFolderURL.path) {
            do {
                try fileManager.removeItem(at: macOSXFolderURL)
                print("Deleted __MACOSX folder successfully")
            } catch {
                print("Error deleting __MACOSX folder: \(error)")
            }
        }
    }

    func uploadFileToFirebase() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let destinationURL = documentsDirectory.appendingPathComponent("archive.zip")

        // Create a Storage reference with the book name
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let fileRef = storageRef.child("archive.zip")

        // Upload the file to the path "images/archive.zip"
        let uploadTask = fileRef.putFile(from: destinationURL, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading file: \(error)")
            } else {
                print("Upload succeeded!")
            }
        }
    }
//MARK: End File picker + Writing to Files________________________________________________________________________________________
    
    
    
    
//MARK: Getting and Setting of Defaults (App Settings)________________________________________________________________________
    //Set a string setting
    func setSetting(value: String, settingName: String){
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: settingName)
    }
    
    //Read and return a string setting
    func getSetting(settingName: String) -> String{
        if let setting: String = UserDefaults.standard.string(forKey: settingName){
            return setting
        }else{
            return ""
        }
    }
    
    //Used on startup to get initial settings
    func initializeSettings() {
        if settings.object(forKey: "TouchRadius") != nil {
            polePaddingSize = settings.integer(forKey: "TouchRadius")
        } else {
            polePaddingSize = 20 // default touch radius
        }
    }
//MARK: End Getting and Setting of Defaults (App Settings)____________________________________________________________________
    
    
    

//MARK: Button and Switch Functions________________________________________________________________________________________
    //If switch is enabled, get directions to the nearest unclicked pole
    @IBAction func btnDirectionsTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
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
        feedbackGenerator.impactOccurred() //Haptic Feedback
        //Construct and export the poles to a local text file for now
        writeToFile(fileName: "poles_\(getSetting(settingName: "PolesFileDate"))_completed"){
            //Zip the file and any jpgs
            self.zipCompletedAndJPGFiles()
            self.uploadFileToFirebase()
        }
        
        showMessage(message: "Export Successful...")
        
    }
    
    
    //Add a new pole to the map MARK: Make a setting where inserts are allowed or not
    @IBAction func btnInsertPoleTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
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
        
        writeToFile(fileName: "poles_active"){}
    }
    
    
    //Turns on or off crosshair on map
    @IBAction func btnCrosshairTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        if btnCrosshair.isOn{
            
            let crossSize: CGFloat = 20
            crosshairView = UIView(frame: CGRect(x: UIScreen.main.bounds.midX - crossSize/2,
                                                 y: UIScreen.main.bounds.midY - crossSize/2,
                                                 width: crossSize,
                                                 height: crossSize))
            crosshairView.backgroundColor = UIColor.clear
            map.addSubview(crosshairView)
            
            let crossLine1 = UIView(frame: CGRect(x: crossSize/4,
                                                  y: crossSize/2 - 1,
                                                  width: crossSize/2,
                                                  height: 2))
            crossLine1.backgroundColor = UIColor.red
            crosshairView.addSubview(crossLine1)
            
            let crossLine2 = UIView(frame: CGRect(x: crossSize/2 - 1,
                                                  y: crossSize/4,
                                                  width: 2,
                                                  height: crossSize/2))
            crossLine2.backgroundColor = UIColor.red
            crosshairView.addSubview(crossLine2)
            crosshairView?.isHidden = false
        }else{
            crosshairView?.isHidden = true
        }
    }
    
    
    //Switch appearance of map to satellite or hybrid
    @IBAction func btnBaseMapTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        if btnBaseMap.isOn{
            //Satellite view
            map.mapType = .hybrid
        }else{
            //Standard
            map.mapType = .standard
        }
    }
    
    
    //Brings up settings menu
    @IBAction func btnSettingsTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        //Show poledetails screen
        performSegue(withIdentifier: "mapToSettingsSegue", sender: nil)
    }
    
    
    //Zooms in on map
    @IBAction func btnZoomInTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        // Get the current region
        let currentRegion = map.region
        
        // Calculate the new span values
        let newLatitudeDelta = currentRegion.span.latitudeDelta / 2
        let newLongitudeDelta = currentRegion.span.longitudeDelta / 2
        
        // Create a new region with the new span values and the same center
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: MKCoordinateSpan(latitudeDelta: newLatitudeDelta, longitudeDelta: newLongitudeDelta))
        
        // Set the new region to the map view
        map.setRegion(newRegion, animated: false)
    }
    
    
    //Zooms out off map
    @IBAction func btnZoomOutTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        // Get the current region
        let currentRegion = map.region
        
        // Calculate the new span values
        let newLatitudeDelta = min(currentRegion.span.latitudeDelta * 2, 180)
        let newLongitudeDelta = min(currentRegion.span.longitudeDelta * 2, 360)
        
        // Create a new region with the new span values and the same center
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: MKCoordinateSpan(latitudeDelta: newLatitudeDelta, longitudeDelta: newLongitudeDelta))
        
        // Set the new region to the map view
        map.setRegion(newRegion, animated: false)
    }
    
    
    //Rotates map
    @IBAction func btnRotateMap(_ sender: Any) {
        
        feedbackGenerator.impactOccurred() //Haptic Feedback
        
        // Calculate the new heading
        let newHeading = map.camera.heading + 30
        
        // Create a new camera object with the new heading
        let newCamera = MKMapCamera(lookingAtCenter: map.centerCoordinate, fromDistance: map.camera.altitude, pitch: map.camera.pitch, heading: newHeading)
        
        // Animate the rotation
        UIView.animate(withDuration: 0.25) {
            self.map.camera = newCamera
        }
    }
    
    //Just for visual effect, is checked if on or off elsewhere
    @IBAction func btnCenterTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
    }
    
    //On startup, give buttons blurred appearance
    func initializeUIButtons() {
        let buttons = [btnCrosshair, btnCenter, btnBaseMap, btnDirections, btnImport, btnExport, btnSettings, btnZoomIn, btnZoomOut, btnRotate, btnInsert]
        
        for button in buttons {
            setButtonApperance(button: button!)
        }
    }
//MARK: End Button and Switch Functions________________________________________________________________________________________
    
    
    
    
//MARK: Settings Functions________________________________________________________________________________________
    // Get Primary line size from UserDefaults
    func getPrimaryLineSizeFromUserDefaults() -> Int {
        if let lineSize = UserDefaults.standard.object(forKey: "PrimaryLineSize") as? Int {
            return lineSize
        } else {
            return 1
        }
    }
    
    
    //Get username
    func getUsername() -> String {
        return settings.string(forKey: "Username") ?? ""
    }
    
    
    //Change or create a username
    @objc func changeUsername() {
        makeUsername()
    }
    
    
    //Change or create a username
    func makeUsername(){
        let alert = UIAlertController(title: "Enter Username", message: "Enter VSum username. This should be first name + last name initial.", preferredStyle: .alert)
        alert.addTextField()
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            guard let text = alert?.textFields?[0].text else { return }
            //Set textfield to new username
            if self.containsOnlyLetters(string: text) && text != ""{
                self.settings.set(text, forKey: "Username")
                self.lblInfo.text = "Hi \(text)!"
            } else {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Add a delay before presenting the alert again
                    self.makeUsername() // Present the alert again
                }
            }
        })
        present(alert, animated: true)
    }
//MARK: End Settings Functions________________________________________________________________________________________
    
    
  
    
//MARK: Misc Functions________________________________________________________________________________________
    //When pole count label is tapped, give a summary of poles clicked MARK: This is just hardcoded for now for lighting TODO
    @objc func lblPoleCountTapped() {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        //Show number of poles clicked and breakdown for light
        let targetTexts = ["LTON","LTOFF","NLT","DELETE"]
        var deleteCount: Int = 0
        var counts: [String: Int] = [:]
        for target in targetTexts{
            counts[target] = 0
        }
        //Loop through poles
        for pole in poles {
            let poleDataComponents = pole.poledata.split(separator: ",")
            for target in targetTexts {
                let targetCount = poleDataComponents.filter { $0 == target }.count
                counts[target]! += targetCount
            }
            if pole.comments.contains("DELETE"){
                deleteCount += 1
            }
        }
        
        var output = ""
        var total: Int = 0
        for target in targetTexts {
            output += "\(target): \(counts[target]!)\n"
            
        }
        for count in counts.values{
            total += count
        }
        
        showMessage(message: "Poles Counted Today: \(getPolesCounted())\n\nBreakdown:\n\(output)\n\nTotal Lights: \(total)")
    }
    
    
    //Return number of poles that have been clicked on today
    func getPolesCounted() -> Int{
        //Search poles array for poles that were clicked on today's date
        var total: Int = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // set timestamp format
        for pole in poles {
            if pole.VSUMInfo.contains(dateFormatter.string(from: Date())){
                total += 1
            }
        }
        return total
        
    }
    
    
    //Takes a comma delimited string and returns the String array. Ignores commas inside ""s
    func splitCommaDelimitedString(_ str: String) -> [String] {
        let pattern = #"((?<=^|,)".*?"(?=,|$)|(?<=^|,)[^,]*?(?=,|$))"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: str, options: [], range: NSRange(str.startIndex..., in: str))
        let parts = matches.map { match -> String in
            let range = Range(match.range, in: str)!
            var extracted = String(str[range])
            // Remove double quotes if present
            if extracted.hasPrefix("\"") && extracted.hasSuffix("\"") {
                extracted = String(extracted.dropFirst().dropLast())
            }
            return extracted
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
    
    
    //Gives buttons a blur effect
    func setButtonApperance(button: UIButton){
        // Create a blur effect
        let blurEffect = UIBlurEffect(style: .light) // .light or .extraLight or .dark

        // Create an effect view
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        
        // Round the corners
        visualEffectView.layer.cornerRadius = 20
        visualEffectView.clipsToBounds = true

        // Add the visual effect view to the main view
        view.addSubview(visualEffectView)

        // Add the picker view to the visual effect view
        visualEffectView.contentView.addSubview(button)

        // Set up constraints for the visual effect view
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: button.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        // Set up constraints for the picker view
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            // add specific width constraint to the picker view if required
            // pickerView.widthAnchor.constraint(equalToConstant: specificWidth),
        ])
    }
    
    
    //Returns whether string contains only letters or not
    func containsOnlyLetters(string: String) -> Bool {
        return string.range(of: "[^a-zA-Z]", options: .regularExpression) == nil
    }
    
    
    //Create and cache a circle symbol based on color
    func circleImage(for color: UIColor) -> UIImage {
        
        
        if let cachedImage = circleImageCache[color] {
            return cachedImage
        }

        let circleSize = CGSize(width: 20, height: 20)
        let padding: CGFloat = CGFloat(Float(polePaddingSize!)) // Adjust the padding as needed
        let totalSize = CGSize(width: circleSize.width + 2 * padding, height: circleSize.height + 2 * padding)

        UIGraphicsBeginImageContextWithOptions(totalSize, false, 0)
        let context = UIGraphicsGetCurrentContext()

        context?.setFillColor(UIColor.clear.cgColor) // Set the padding color to clear
        context?.fill(CGRect(origin: .zero, size: totalSize))

        context?.setFillColor(color.cgColor) // Set the circle color
        let circleRect = CGRect(x: padding, y: padding, width: circleSize.width, height: circleSize.height)
        context?.fillEllipse(in: circleRect)

        let circleImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        circleImageCache[color] = circleImage

        return circleImage!
    }
    
    
    //Clears all user defaults
    func resetUserDefaults(){
        let defaults = UserDefaults.standard

        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()
    }
    
    
    //Used on startup to get user location
    func initializeLocationManager(){
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
    
    
    //Used on startup to set label appearances
    func initializeLabels() {
        let labels = [lblInfo, lblPoleCount]
        
        for label in labels {
            label?.backgroundColor = label?.backgroundColor?.withAlphaComponent(0.7)
            label?.layer.cornerRadius = 10
        }
    }
    
    
    //Used on startup to set gesture recognizers
    func initializeGestureRecgonizers(){
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(lblPoleCountTapped))
        lblPoleCount.addGestureRecognizer(tapGestureRecognizer)
            
        let poleMoveGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        map.addGestureRecognizer(poleMoveGestureRecognizer)
    }
    
    
    //Used on startup to create the red border that displays when items are in a moving state
    func initializeBorder(){
        redBorderView = RedBorderView(frame: map.bounds)
        redBorderView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        redBorderView!.backgroundColor = .clear
        redBorderView?.isUserInteractionEnabled = false
        map.addSubview(redBorderView!)
        redBorderView?.isHidden = true
    }
    
    
    func removeAllPoleAnnotations() {
        let polesToRemove = map.annotations.filter { annotation in
                // Check if the annotation is of type CustomPointAnnotation (assumed to be poles)
                guard let customAnnotation = annotation as? CustomPointAnnotation else {
                    return false
                }
                
                // Check if the annotation type is "Poles" (assumed to be poles)
                if customAnnotation.type == "Poles" {
                    return true
                }

                return false
            }

            map.removeAnnotations(polesToRemove)
    }

    
    //Just a button to temporarily test things
    @IBAction func btnTestTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        
        
        
        
    }
    
    
    
    
    func setupCaptureSession() {
        sessionQueue.async { [weak self] in
                guard let self = self else { return }
                guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                    self.failed()
                    return
                }
                do {
                    let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                    self.captureSession.beginConfiguration() // Begin configuration
                    if self.captureSession.canAddInput(videoInput) {
                        self.captureSession.addInput(videoInput)
                    } else {
                        self.failed()
                        return
                    }
                    
                    let metadataOutput = AVCaptureMetadataOutput()
                    if self.captureSession.canAddOutput(metadataOutput) {
                        self.captureSession.addOutput(metadataOutput)
                        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                        metadataOutput.metadataObjectTypes = [.qr]
                    } else {
                        self.failed()
                        return
                    }
                    self.captureSession.commitConfiguration() // Commit configuration
                    
                    self.captureSession.startRunning() // Keep this line here
                    
                    DispatchQueue.main.async {
                        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                        self.previewLayer?.frame = self.view.layer.bounds
                        if let previewLayer = self.previewLayer {
                            self.view.layer.addSublayer(previewLayer)
                        }
                    }
                } catch {
                    self.failed()
                }
            }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        
    }
    
    func found(code: String) {
        guard let decodedData = Data(base64Encoded: code) else {
            print("Failed to decode Base64 string")
            return
        }
        
        do {
            let decompressedData = try decodedData.gunzipped()
            guard let decompressedString = String(data: decompressedData, encoding: .utf8) else {
                print("Failed to convert decompressed data to string")
                return
            }
            
            //print(decompressedString)
            
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("decoded_file.txt")
            do {
                try decompressedString.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save the decompressed text: \(error)")
            }
            
            
            //Try to put poles
            
            if doesFileExist(fileName: "poles_active"){
                //Ask user if they want to open active poles file
                
                    let alertController = UIAlertController(title: "Active Poles", message: "You already have an active poles file that hasn't been completed; importing new poles will overwrite that currently active poles file. Continue?", preferredStyle: .alert)
                    
                    let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
                        //Handle Yes action
                        self.poles.removeAll()
                        self.readPolesFile(selectedFileURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("decoded_file.txt"))
                    }
                    
                    let noAction = UIAlertAction(title: "No", style: .cancel) { (action) in
                        // Handle No action
                    }
                    
                    alertController.addAction(yesAction)
                    alertController.addAction(noAction)
                    
                    present(alertController, animated: true, completion: nil)
                    
                    
                }
            
            
        } catch {
            print("Failed to decompress data: \(error)")
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    
    
    
//MARK: End Misc Functions________________________________________________________________________________________
}


//Extension to allow coorindates for a polyline
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}












