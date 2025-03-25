//  ViewController.swift
//  PVLite
//
//  Created by Erik Taylor on 3/3/23.
//  Main Map View where Users can Import Data to Display on Map

import UIKit
import UniformTypeIdentifiers
import Foundation
import MobileCoreServices
import MapKit
import ZIPFoundation
import FirebaseStorage
import Firebase
import AVFoundation
import AVKit
import Gzip
import CoreImage
import FirebaseAuth
import FirebaseDatabase



//Main Map Screen
class ViewController: UIViewController, UIDocumentPickerDelegate, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate, UITextViewDelegate, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, FileListViewControllerDelegate {
    
    
    //Map Related Items
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    var crosshairView: UIView!
    
    
    //Buttons and Labels on Map
    @IBOutlet weak var btnCrosshair: ToggleButton!
    @IBOutlet weak var btnCenter: ToggleButton!
    @IBOutlet weak var btnBaseMap: ToggleButton!
    @IBOutlet weak var btnDirections: ToggleButton!
    @IBOutlet weak var btnDrawWiring: UIButton!
    @IBOutlet weak var btnImport: UIButton!
    @IBOutlet weak var btnExport: UIButton!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var btnZoomIn: UIButton!
    @IBOutlet weak var btnZoomOut: UIButton!
    @IBOutlet weak var btnRotate: UIButton!
    @IBOutlet weak var btnInsert: UIButton!
    @IBOutlet weak var btnRevert: UIButton!
    @IBOutlet weak var btnRemove: UIButton!
    @IBOutlet weak var lblInfo: UITextView!
    @IBOutlet weak var lblPoleCount: UITextView!
    @IBOutlet weak var btnPairPV: ToggleButton!
    @IBOutlet weak var btnTest: UIButton!
    @IBOutlet weak var btnPVPairAction: UIButton!
    
    
    //Poles contents (poles, Owners, TLAs, etc...)
    var poles: [Pole] = [] //This contains all poles and their data. Essentially the poles table
    var Owners = [String]()
    var TLAs = [String]()
    var SFXs = [String]()
    var PAs = [String]()
    var polesDictionary: [String: Pole] = [:] //Dictionary for easy lookup
    
    
    //Counters
    var counter: Int = 0 //For incremental values in VSUMInfo and elsewhere if needed
    var polesCompleted: Int = 0 //Tracks poles clicked for a workarea (regardless of date)
    
    
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
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    var circleImageCache: [UIColor: UIImage] = [:] //Stores pole symbols + colors
    var redBorderView: RedBorderView?
    var moveModeOverlay: UIView?
    var poleToMove: Pole?
    var poleToMoveIndex: Int?
    var shouldMoveAnnotation = false
    var updateTimer: Timer?
    var polePaddingSize: Int?
    var polesEnabled: Bool = true
    var isInDeleteMode: Bool = false
    var isDrawingMode: Bool = false
    var currentWireline: MKPolyline?
    var userIcon: UIImage?
    var currentLocation: CLLocation?
    var isLblInfoExpanded = false //Used for the info label
    
    
    //Camera Operations
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    
    //QR Images
    var qrImages: [UIImage] = []
    var currentIndex: Int = 0
    let imageView = UIImageView()
    let nextButton = UIButton()
    let maxDataSize = 1250
    var scannedData: String = ""
    var scannedQRCount: Int = 0
    var fileCount: Int = 0
    var lastScannedCode: String?
    var stopButton: UIButton?
    var cancelButton: UIButton?
    var lblQRInfo: UILabel?
    var overlayView: UIView?
    
    
    //File System
    var storageFileName: String = ""
    var originalTimestamp: String = ""
    var waName: String = ""
    
    
    //Misc
    var recentMediaFile: String = ""
    
    
    //Firebase
    let email = "jeriktaylor@gmail.com"
    let password = "+Bmbp2>XSh"
    
    
    //PoleVAULT Pairing Items
    var picObjectID: String = ""
    var inPairMode: Bool = false
    var pvPairReturnPayload: String = ""
    var isDrawingModeEnabled = false
    var currentWirePolyline: MKPolyline?
    var currentCoordinates: [CLLocationCoordinate2D] = []
    var rectangleView: UIView!
    var currentNavOverlay: MKOverlay!
    var pvPairID: String?
    var navigationTimer: Timer?
    var scanningMode: ScanningMode = .qrCode
    var needSimpleQR: Bool = false
    var needPVPairPic: Bool = false
    
    //New cred locked DB
    var db: DatabaseReference {
            let dbURL = "https://venturesum.firebaseio.com/"
            let db = Database.database(url: dbURL)
            return db.reference()
        }
    
    
    //MARK: VIEW FUNCTIONS
    //Startup code -- Load Map and Visual Settings (√)
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //***If you want to clear all user defaults(settings), enable this, but then comment it out after ran once***
        //resetUserDefaults()

        //Clear log file if older than 1 week
        checkAndResetLogFile()
        
        writeToLogFile(message: "App startup...")
        
        initializeMap()
        
        initializeLocationManager()
        
        configureLocationManager()
        
        initializeUIButtons()
        
        initializeLabels()
        
        initializeGestureRecgonizers()
        
        initializeRedBorder()
        
        initializeSettings()
        
        //Side menu that expands to show layers (needs work)
        //        let sideMenu = ExpandableSideMenu(frame: view.bounds)
        //        view.addSubview(sideMenu)
        //        sideMenu.parentViewController = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleTextViewExpansion))
                lblInfo.addGestureRecognizer(tapGesture)
                lblInfo.isUserInteractionEnabled = true
        
        
        //QR Code Export
        setupQRExportImageView()
        setupQRExportNextButton()
        imageView.isHidden = true
        nextButton.isHidden = true
        
        writeToLogFile(message: "Map initialized...")
        
        //Sign into Firebase for future operations
        signIn(email: self.email, password: self.password) { success, error in
            if success{
                //Do nothing
            }else{
                self.showMessage(message: "Unable to sign in to Firebase; some features may not be available... Try checking internet connection...")
            }
        }
        
    }

    @objc func toggleTextViewExpansion() {
        // Create a background overlay view
        let overlayView = UIView(frame: self.view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlayView.alpha = 0
        overlayView.tag = 999
        self.view.addSubview(overlayView)

        // Add a tap gesture to dismiss the popover when tapping on the overlay
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissPopover(_:)))
        overlayView.addGestureRecognizer(tapGesture)

        // Create a UITextView to display the full text
        let popoverTextView = UITextView(frame: CGRect(x: 20, y: self.view.frame.height / 4, width: self.view.frame.width - 40, height: self.view.frame.height / 5))
        popoverTextView.backgroundColor = UIColor.systemGray4.withAlphaComponent(1) // Light grey
        popoverTextView.layer.cornerRadius = 10
        popoverTextView.layer.masksToBounds = true
        popoverTextView.text = lblInfo.text
        popoverTextView.font = lblInfo.font
        popoverTextView.textColor = UIColor.white
        popoverTextView.textAlignment = .center
        popoverTextView.isEditable = false
        popoverTextView.isSelectable = true
        popoverTextView.isScrollEnabled = true
        popoverTextView.alpha = 0
        popoverTextView.tag = 999
        self.view.addSubview(popoverTextView)

        // Add a tap gesture to the popoverTextView to dismiss on tap
        let popoverTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissPopover(_:)))
        popoverTextView.addGestureRecognizer(popoverTapGesture)

        // Delay adjustment of vertical centering until the layout is complete
        DispatchQueue.main.async {
            if let text = popoverTextView.text, !text.isEmpty {
                let textHeight = popoverTextView.contentSize.height
                let viewHeight = popoverTextView.bounds.height
                let topOffset = max((viewHeight - textHeight) / 2, 0)
                popoverTextView.contentInset = UIEdgeInsets(top: topOffset, left: 0, bottom: 0, right: 0)
            }
        }

        // Animate the appearance of the overlay and popover
        UIView.animate(withDuration: 0.3) {
            overlayView.alpha = 1
            popoverTextView.alpha = 1
        }
    }

    @objc func dismissPopover(_ sender: UITapGestureRecognizer) {
        // Remove the overlay and popover views
        for subview in self.view.subviews where subview.tag == 999 {
            UIView.animate(withDuration: 0.3, animations: {
                subview.alpha = 0
            }) { _ in
                subview.removeFromSuperview()
            }
        }
    }



    
    
    //Each Time View is Loaded, Check if User has a Username (√)
    override func viewDidAppear(_ animated: Bool) {
        let username = getUsername()
        if !username.isEmpty {
            lblInfo.text = "Hi \(username)! Scan a QR code or import a poles file to continue..."
            writeToLogFile(message: "Username is: \(username)")
        } else {
            makeUsername()
        }
    }
    //MARK: END VIEW FUNCTIONS
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: MAP FUNCTIONS
    //Map Startup state (√)
    func initializeMap(){
        map.showsUserLocation = true
        map.delegate = self
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.isPitchEnabled = false
        map.userTrackingMode = .follow
        
        let mapType = settings.string(forKey: "MapType") ?? "Standard"
        map.mapType = mapType == "Satellite" ? .hybrid : .mutedStandard
    }
    
    
    
    //Change how Objects Render on Map
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.title == "Pic" {
            let identifier = "PicAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image with white tint
            let image = UIImage(systemName: "camera.fill")?.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            if annotation.subtitle == "Captured"{
                imageView.tintColor = .green
            }else{
                imageView.tintColor = .white
            }
            annotationView?.addSubview(imageView)
            annotationView?.image = image

            
            // Adjust the frame size of the image
            annotationView?.frame.size = CGSize(width: 20, height: 15)
            
            return annotationView
        } else if annotation.title == "QR" {
            let identifier = "QRAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image with white tint
            let image = UIImage(systemName: "qrcode")?.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            if annotation.subtitle == "Captured"{
                imageView.tintColor = .green
            }else{
                imageView.tintColor = .white
            }
            annotationView?.addSubview(imageView)
            annotationView?.image = image

            
            // Adjust the frame size of the image
            annotationView?.frame.size = CGSize(width: 20, height: 15)
            
            return annotationView
        }
        
        else if annotation.title == "BarCode" {
            let identifier = "barCodeAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image with white tint
            let image = UIImage(systemName: "barcode")?.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            if annotation.subtitle == "Captured"{
                imageView.tintColor = .green
            }else{
                imageView.tintColor = .white
            }
            annotationView?.addSubview(imageView)
            annotationView?.image = image

            
            // Adjust the frame size of the image
            annotationView?.frame.size = CGSize(width: 20, height: 15)
            
            return annotationView
        }
        
        else if annotation.title == "Video" {
            let identifier = "VideoAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image with white tint
            let image = UIImage(systemName: "video.fill")?.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            imageView.tintColor = .white
            annotationView?.addSubview(imageView)
            annotationView?.image = image

            
            // Adjust the frame size of the image
            annotationView?.frame.size = CGSize(width: 20, height: 15)
            
            return annotationView
        }
        else if annotation.title == "POI" {
            let identifier = "POI"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set the image with white tint
            let image = UIImage(systemName: "exclamationmark.circle.fill")?.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            imageView.tintColor = .white
            annotationView?.addSubview(imageView)
            annotationView?.image = image

            
            // Adjust the frame size of the image
            annotationView?.frame.size = CGSize(width: 20, height: 15)
            
            return annotationView
        }
        
        //For objets that are not poles
        else if annotation.title == "Other" {
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
            
            annotationView?.zPriority = .min
            
            return annotationView
        }else{
            // Handling poles
                    guard let poleAnnotation = annotation as? CustomPointAnnotation else {
                        return nil
                    }
                    
                    let identifier = "PoleAnnotation"
                    var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PoleAnnotation
                    
                    if annotationView == nil {
                        annotationView = PoleAnnotation(annotation: poleAnnotation, reuseIdentifier: identifier)
                        annotationView?.canShowCallout = true
                        annotationView?.zPriority = .max
                    } else {
                        annotationView?.annotation = poleAnnotation
                    }
                    
                    // Refresh view contents
                    annotationView?.image = circleImage(for: poleAnnotation.annotationColor, size: 20)
                    
                    annotationView?.textLabel.text = createStackedText(from: poleAnnotation.subtitle ?? "")
                    
                    if let pole = polesDictionary[poleAnnotation.title ?? ""] {
                        annotationView?.staticTextLabel.text = createStackedText(from: pole.initialData)
                        
                        let color: UIColor
                        if pole.VSUMInfo.contains("VERIFY") {
                            color = poleAnnotation.annotationColor
                        } else if pole.suppdata == "CHECKED" {
                            color = .green
                        } else {
                            color = poleAnnotation.annotationColor
                        }
                        
                        annotationView?.image = circleImage(for: color, size: 20)
                        annotationView?.zPriority = .max
                    }
                    
                    annotationView?.clusteringIdentifier = nil
                    
                    return annotationView
        }
    }
    
    
    
    //Adds Point Objects Besides Poles Based on the Current Map Region and a Map Zoom Level. Poles are Added Last (no zoom restriction) (√)
    func addAnnotationsForVisibleRegion(region: MKCoordinateRegion) {
        //Calculate map region in square kilometers
        let visibleMapRect = map.visibleMapRect
        let regionWidthKm = region.span.latitudeDelta * 111
        let regionHeightKm = region.span.longitudeDelta * 111
        let visibleRegionSizeKm2 = regionWidthKm * regionHeightKm
        
        //Preprocess otherAnnotations and annotations into AnnotationData for quick lookup
        let otherAnnotationData = otherAnnotations.map { AnnotationData(annotation: $0, mapPoint: MKMapPoint($0.coordinate)) }
        let annotationData = annotations.map { AnnotationData(annotation: $0, mapPoint: MKMapPoint($0.coordinate)) }
        
        //Check if region size is less than the threshold of 10 square kilometers (this number can be modified)
        if visibleRegionSizeKm2 <= 10 {
            otherAnnotationData.forEach { other in
                if visibleMapRect.contains(other.mapPoint) {
                    //Directly add the annotation if it's in the visible region, no distance check to other annotations
                    map.addAnnotation(other.annotation)
                }
            }
        } else {
            //Remove all existing annotations if the visible region size exceeds the threshold.
            map.removeAnnotations(map.annotations)
        }
        
        //Add poles only if poles are enabled via side menu
        if polesEnabled {
            annotationData.forEach { annotation in
                if visibleMapRect.contains(annotation.mapPoint) {
                    map.addAnnotation(annotation.annotation)
                }
            }
        }
    }

    
    
    //Adds polylines to map based on a set zoom level MARK: Needs work (ugly) TODO
    func addPolylinesForVisibleRegion(region: MKCoordinateRegion) {
        let visibleMapRect = map.visibleMapRect
        
        let regionWidthKm = region.span.latitudeDelta * 111
        let regionHeightKm = region.span.longitudeDelta * 111
        let visibleRegionSizeKm2 = regionWidthKm * regionHeightKm
        
        var newDisplayedPolylineOverlays: Set<Int> = []
        
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
    
    
    
    //When the Map Region Changes, Add Poles and Other Layers Accordingly (√)
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Add annotations and polylines for the visible region
        addAnnotationsForVisibleRegion(region: mapView.region)
        if !(polylineDict.isEmpty && polylineDictSecondary.isEmpty && multiPolylineDict.isEmpty) {
            addPolylinesForVisibleRegion(region: mapView.region)
        }
        
        // Convert the threshold from square miles (0.09) to square kilometers
        let thresholdSquareKilometers = 0.09 * 2.58999
        
        // Calculate the area of the current map region
        let region = mapView.region
        let currentAreaSquareKilometers = region.span.latitudeDelta * region.span.longitudeDelta * 111 * 111
        
        // Show or hide labels based on the current area
        let shouldShowLabels = currentAreaSquareKilometers <= thresholdSquareKilometers
        for annotation in mapView.annotations {
            if let view = mapView.view(for: annotation) as? PoleAnnotation {
                view.textLabel.isHidden = !shouldShowLabels
                view.staticTextLabel.isHidden = !shouldShowLabels
            }
        }
        
        // Use the center of the map view as the new point for the polyline
        if isDrawingModeEnabled {
            let centerPoint = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
            let centerCoordinate = mapView.convert(centerPoint, toCoordinateFrom: mapView)
            currentCoordinates.append(centerCoordinate)
            updateWirePolyline()
        }
        
    }
    
    
    
    //Disables the User from Selecting Their Own Location on the Map (√)
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        mapView.view(for: mapView.userLocation)?.isSelected = false
    }
    
    
    
    //Removes a Pole from the Map, Poles Array, and poles_active File (√)
    func removePoleAndAnnotation(for annotation: CustomPointAnnotation) {
        map.removeAnnotation(annotation)
        
        //Remove the annotation from the annotations array and the poles array based on SRCID
        annotations.removeAll { $0.title == annotation.title }
        poles.removeAll { $0.SRCID == annotation.title }
        
        //Update poles file
        writeToFile(fileName: "poles_active") {}
    }
    
    
    
    //When a Pole is Selected on the Map, Open the Selected Pole's Details Screen or Delete Pole (√)
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        feedbackGenerator.impactOccurred() //Vibrate
        
        
        // Deselect user location annotation view
        if view == mapView.view(for: mapView.userLocation) {
            view.isSelected = false
            return
        }
        
        // Check if the app is in delete mode
        if isInDeleteMode {
            if let annotation = view.annotation as? CustomPointAnnotation {
                removePoleAndAnnotation(for: annotation)
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }
        }else if isDrawingMode{
            mapView.deselectAnnotation(view.annotation, animated: false)
            return //User is drawing wiring, don't allow pole selection
        }else {
            
            if let annotation = view.annotation, annotation.title == "Pic", let filename = annotation.subtitle {
                // Show the picture if the annotation title is "Pic"
                showPicture(filename: filename)
            }else if let annotation = view.annotation, annotation.title == "BarCode", let filename = annotation.subtitle {
                // Show the picture if the annotation title is "Pic"
                showPicture(filename: filename)
            }else if let annotation = view.annotation, annotation.title == "Video", let filename = annotation.subtitle {
                // Show the picture if the annotation title is "Pic"
                showVideo(filename: filename)
            }else if let annotation = view.annotation, annotation.title == "POI"{
                // Show the POI message
                showMessage(message: ((annotation.subtitle ?? "No POI comment") ?? "No POI Comment"))
            } else if let poleAnnotationView = view as? PoleAnnotation {
                //Change the symbol color to green
                poleAnnotationView.image = circleImage(for: .green, size: 12)
                
                //Get the selected pole based on SRCID
                if let srcid = view.annotation?.title, let selectedPole = getSelectedPole(srcid: srcid!) {
                    // Increase pole counter if not already "CHECKED"
                    selectedPole.wasChecked = true
                    if selectedPole.suppdata != "CHECKED" {
                        selectedPole.suppdata = "CHECKED"
                    }
                    
                    // Perform segue to show pole details
                    performSegue(withIdentifier: "mapToPoleSegue", sender: selectedPole)
                }
                
                // Deselect the annotation so it can be selected again later
                mapView.deselectAnnotation(view.annotation, animated: true)
            }
        }
    }


    
    //For Line Layers, Change how they Render TODO: Make this less ugly
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        //        if let multiPolyline = overlay as? MKMultiPolyline {
        //            let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.85)
        //            let renderer = MKMultiPolylineRenderer(multiPolyline: multiPolyline)
        //            renderer.strokeColor = color
        //            renderer.lineWidth = 1.0
        //            return renderer
        //        }
        
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        if polyline.title == "Primary"{
            //Check if a color setting is saved, else use default color
            if let colorData = UserDefaults.standard.object(forKey: "PrimaryColor") as? Data,
               let savedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                let color = savedColor
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                renderer.lineWidth = 3
                renderer.lineDashPattern = [NSNumber(value: 4), NSNumber(value: 8)]
                return renderer
            } else{
                let color = UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                //renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
                renderer.lineWidth = 3
                renderer.lineDashPattern = [NSNumber(value: 4), NSNumber(value: 8)]
                return renderer
            }
            
        }else if polyline.title == "Survey_Link"{
            let color = UIColor.yellow
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = color
            renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
            return renderer
            
        }else if polyline.title == "Transmission" {
            let color = UIColor.white
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = color
            renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
            return renderer
        }else{
            //Default - Secondary
            let color = UIColor(red: 0.98, green: 0.0, blue: 0.0, alpha: 0.8)
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = color
            //renderer.lineWidth = CGFloat(getPrimaryLineSizeFromUserDefaults())
            renderer.lineWidth = 1
            return renderer
        }
    }
    
    
    
    //Moves Pole to Tapped Location and Updates Values (√)
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
            
            redBorderView?.isHidden = true
            
            lblInfo.text = "Successfully moved and updated pole: \(poles[index].SRCID)"
            writeToFile(fileName: "poles_active"){}
        }
    }
    
    
    
    //Get User Location on Start (√)
    func initializeLocationManager(){
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
    
    
    
    //Find/follow User's location
    func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading() // Start receiving heading updates
    }
    
    
    //Either follow user or get new directions update
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        currentLocation = locations.last
        if btnCenter.isOn {
            map.setCenter(userLocation.coordinate, animated: true)
        }
        if btnDirections.isOn {
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: false) { [weak self] _ in
                self?.getDirectionsToClosestAnnotation()
            }
        } else {
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }
    
    
    
    //Figure out direction of travel, does not seem to work right now TODO:
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return } // Check for valid heading accuracy
        if let mapView = self.map {
            if let userLocationView = mapView.view(for: mapView.userLocation) {
                // Define the offset angle in degrees, e.g., 90 degrees if the image faces east
                let offsetAngle = 150.0
                
                // Normalize the heading value
                let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
                
                // Convert the sum of the true heading and offset angle from degrees to radians
                let rotation = CGFloat((heading + offsetAngle) / 180.0 * .pi)
                
                // Apply the rotation transformation with the offset
                userLocationView.transform = CGAffineTransform(rotationAngle: rotation)
            }
        }
    }
    //MARK: END MAP FUNCTIONS
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: SEND AND RECEIVE DATA FROM OTHER VIEWS
    //Sets Pole Object and Shows Pole Details Screen (√)
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Perform segue to show pole details menu
        if let pole = sender as? Pole {
            let poleDetailsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PoleDetailsViewController") as! PoleDetailsViewController
            poleDetailsViewController.modalPresentationStyle = .fullScreen //Set the presentation style to full screen
            poleDetailsViewController.didSendValue = { [weak self] value in
                self?.didReceiveValue(value)
            }
            
            //Send selected pole and project config (owners, attributes, etc...)
            poleDetailsViewController.pole = pole
            poleDetailsViewController.Owners = Owners
            poleDetailsViewController.TLAs = TLAs
            poleDetailsViewController.SFXs = SFXs
            poleDetailsViewController.PAs = PAs
            
            present(poleDetailsViewController, animated: true, completion: nil)
        }
    }
    
    
    //When Pole Details Screen is Closed, the Pole is Returned Here (√)
    func didReceiveValue(_ value: Pole) {
        var tempStr = ""
        
        if value.comments == "MOVE", let index = poles.firstIndex(where: { $0.SRCID == value.SRCID }) {
            poleToMoveIndex = index
            shouldMoveAnnotation = true
            tempStr = "Tap new location of selected pole..."
            redBorderView?.isHidden = false
        }
        
        //Update label to move or not
        lblInfo.text = tempStr.isEmpty ? "Done Editing Pole: \(value.SRCID)" : tempStr
        
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
        
        // Find the corresponding annotation view and update it
        if let annotationToUpdate = map.annotations.first(where: { ($0 as? MKPointAnnotation)?.title == value.SRCID }) as? MKPointAnnotation {
            annotationToUpdate.subtitle = value.poledata
            if let annotationView = map.view(for: annotationToUpdate) as? PoleAnnotation {
                annotationView.textLabel.text = createStackedText(from: (value.poledata + value.comments + "\n" + (value.surveyPole?.surveyStr ?? "")))
            }
        }
        
        // Check if there is a survey pole coordinate and add a new annotation
        if let surveyPoleCoordinate = value.surveyPole?.coordinate, surveyPoleCoordinate.latitude != 0.0 {
            let surveyAnnotation = MKPointAnnotation()
            surveyAnnotation.coordinate = surveyPoleCoordinate
            surveyAnnotation.title = "Survey Location"
            map.addAnnotation(surveyAnnotation)
            
            if let originalPoleCoordinate = poles.first(where: { $0.SRCID == value.SRCID }) {
                let coordinates = [CLLocationCoordinate2D(latitude: originalPoleCoordinate.Y, longitude: originalPoleCoordinate.X), surveyPoleCoordinate]
                let polyline = MKPolyline(coordinates: coordinates, count: 2)
                polyline.title = "Survey_Link"
                map.addOverlay(polyline)
            }
        }
        
        polesCompleted = 0
        writeToFile(fileName: "\(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "")/poles_active"){} //Every time a poles is clicked, update the active poles file
        //writeToFile(fileName: "poles_active.txt"){} //Every time a poles is clicked, update the active poles file
        
        //Check if user is in 'guide' mode and give directions to next pole if so
        if btnDirections.isOn, let polyline = currentPolyline {
            map.removeOverlay(polyline)
            currentPolyline = nil
            getDirectionsToClosestAnnotation()
        }
    }
    
    //MARK: END SEND AND RECEIVE DATA FROM OTHER VIEWS
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: Locate + Update Pole Fuctions
    
    //Creates and returns a VSUMInfo string for pole (√) MARK: Only thing missing is State column in VSUMInfo[1]
    func updateVSUMInfo(pole: Pole) -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        
        var components = pole.VSUMInfo.components(separatedBy: "|")
        components += Array(repeating: "", count: max(0, 4 - components.count))
        
        components[0] = getUsername()
        components[2] = dateFormatter.string(from: Date())
        components[3] = String(format: "%03d", (counter < 999) ? counter : { counter = 0; return 0 }()) //Counter to generate unique VSUMInfo
        counter += 1
        
        return components.joined(separator: "|")
    }
    
    
    
    //Searches array of poles and returns the matched pole based on SRCID
    func getSelectedPole(srcid: String) -> Pole? {
        return poles.first { $0.SRCID == srcid.replacingOccurrences(of: "\"", with: "") }
    }
    
    
    
    //Get directions to closest pole (√)
    func getDirectionsToClosestAnnotation(){
        
        if let existingPolyline = currentPolyline {
            map.removeOverlay(existingPolyline)
            currentPolyline = nil
        }
        
        //Find the closest pole to the user's location that doesn't have a certain color
        guard let userLocation = map.userLocation.location else { return }
        guard let closestAnnotation = annotations
            .compactMap({ $0 })
            .filter({ $0.annotationColor != .green }) // skip poles that have already been clicked
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
            self.currentPolyline = polyline
            
            // Set the label to show ETA time to pole
            let travelTime = route.expectedTravelTime
            let timeString = String(format: "%.0f min", travelTime / 60)
            
            let distance = route.distance * 0.000621371 // Convert to miles (1 meter = 0.000621371 miles)
            let distanceString = String(format: "%.2f mi", distance)
            
            self.lblInfo.text = "ETA:\(timeString)\t\tDistance: \(distanceString)"
        }
    }
    
    
    
    //Duplicate version of getDirections TODO: Figure out why this is used in the first place (driving issues?)
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
    
    
    
    //Removes all poles from map (Currently used in side menu to hide poles) (√)
    func removeAllPoleAnnotations() {
        let polesToRemove = map.annotations.filter { ($0 as? CustomPointAnnotation)?.type == "Poles" }
        map.removeAnnotations(polesToRemove)
    }
    //MARK: End Locate + Update Pole Fuctions
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: File picker + Reading/Writing to Files
    
    //Opens a document selector or lets user capture QC code (√)
    @IBAction func btnOpenFiles(_ sender: Any) {
        feedbackGenerator.impactOccurred()
        
        let alertController = UIAlertController(title: nil, message: "How would you like to proceed?", preferredStyle: .actionSheet)
        
        let scanQRCodeAction = UIAlertAction(title: "Scan QR Code", style: .default) { _ in
            self.setupQRCodeScanning()
        }
        
        let importFromURLAction = UIAlertAction(title: "Download Backups/Uploads", style: .default) { _ in
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    if let fileListVC = storyboard.instantiateViewController(withIdentifier: "FirebaseStorageWorkAreasVC") as? FirebaseStorageWorkAreasVC {
                        fileListVC.delegate = self // Set the delegate to the parent view controller
                        self.present(fileListVC, animated: true, completion: nil)
                    }
            
        }
        
        let documentPickerAction = UIAlertAction(title: "Import from file", style: .default) { _ in
            let types: [UTType] = [UTType.plainText, UTType.json, UTType(filenameExtension: "zip")].compactMap { $0 }
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true)
        }
        
        
        
        
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        [scanQRCodeAction, importFromURLAction, documentPickerAction, cancelAction].forEach { alertController.addAction($0) }
        
        // Check if the view controller is being presented on an iPad.
        if let popoverController = alertController.popoverPresentationController {
            // Set the source view and source rect if the sender is a view.
            if let senderView = sender as? UIView {
                popoverController.sourceView = senderView
                popoverController.sourceRect = senderView.bounds
            } else {
                // Fallback to center of the screen if the sender is not a view.
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        
        present(alertController, animated: true)
    }
    
    
    
    //Reads the Poles and Other Layers (OWNR/TLAs/etc...)
    private func readPolesFile(selectedFileURL: URL) {
        do {
            writeToLogFile(message: "Attempting to readPoleFile from: \(selectedFileURL.absoluteString)")
            let fileContents = try String(contentsOf: selectedFileURL)
            
            var arrays = fileContents.components(separatedBy: "_END_").map { $0.components(separatedBy: .newlines) }
            arrays.removeLast()  //Remove empty element
            
            
            //Clear any old arrays
            Owners.removeAll()
            TLAs.removeAll()
            SFXs.removeAll()
            PAs.removeAll()
            
            
            //MARK: FIRST - Read Poles
            if arrays.indices.contains(0) {
                var poles = arrays[0]
                if !poles.isEmpty {
                    poles.removeFirst()
                    self.plotCoord(stringArr: poles)
                } else {
                    //No poles
                    print("Error: poles array is empty.")
                    writeToLogFile(message: "Poles file in readPolesFile was blank...")
                }
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
            writeToFile(fileName: "\(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "(No WorkArea Found)")/poles_active"){}
            
            print("Should have written poles data to: \("\(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "(No WorkArea Found)")/poles_active.txt")")
            writeToLogFile(message: "ReadPolesFile should have written file to: \("\(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "(No WorkArea Found)")/poles_active.txt")")
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            writeToLogFile(message: "Error reading file in readPolesFile: \(error.localizedDescription)")
            showMessage(message: "Unable to read poles file. Attempting to load poles from last used WA")
            let folder = selectedFileURL.deletingLastPathComponent()
            self.readPolesGeoJSON(selectedFileURL: folder.appendingPathComponent("poles.geojson"))
        }
    }
    
    
    
    //Reads the Poles and Other Layers from .geojson (OWNR/TLAs/etc...)
    private func readPolesGeoJSON(selectedFileURL: URL) {
        do {
            writeToLogFile(message: "Attempting to read poles from: \(selectedFileURL.absoluteString)...")
            let jsonData = try Data(contentsOf: selectedFileURL)
            let polesData = try JSONDecoder().decode(PoleFeatureCollection.self, from: jsonData)
            
            // Clear existing annotations and data arrays
            map.removeAnnotations(annotations)
            annotations.removeAll()
            polesCompleted = 0
            
            // Process each pole feature from the GeoJSON
            for feature in polesData.features {
                let coordinates = feature.geometry.coordinates
                let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                
                let tempPole = Pole()
                tempPole.setDataJSON(json: feature)
                tempPole.initialData = tempPole.poledata
                poles.append(tempPole)
                polesDictionary[tempPole.SRCID] = tempPole // Store in dictionary for quick lookup
                
                let annotation = CustomPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = tempPole.SRCID
                annotation.subtitle = tempPole.poledata
                annotation.type = "Poles"
                annotation.initialData = tempPole.initialData
                
                annotations.append(annotation)
                map.addAnnotation(annotation)
            }
            let annotationCoordinate = annotations[0].coordinate
            let regionRadius: CLLocationDistance = 1000
            let region = MKCoordinateRegion(center: annotationCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
            map.setRegion(region, animated: true)
            
            lblInfo.text = "Pole(s) mapped..."
            writeToLogFile(message: "\(polesDictionary.count) poles loaded.")
            
            
            // Get the folder path from the selected file URL
            let folderPath = selectedFileURL.deletingLastPathComponent()
            
            // Read additional files from the same folder
            let ownerFileURL = folderPath.appendingPathComponent("OWNR.txt")
            let tlaFileURL = folderPath.appendingPathComponent("TLA.txt")
            let sfxFileURL = folderPath.appendingPathComponent("SFX.txt")
            let paFileURL = folderPath.appendingPathComponent("PA.txt")
            
            //MARK: SECOND - Read Owners
            if var ownerData = try? String(contentsOf: ownerFileURL) {
                ownerData = ownerData.replacingOccurrences(of: "OWNR:", with: "")
                Owners = ownerData.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            //MARK: THIRD - Read TLA (Three Letter Attacher)
            if let tlaData = try? String(contentsOf: tlaFileURL) {
                TLAs = tlaData.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            //MARK: FOURTH - Read SFX (Attacher Attributes ex. "Dead", "Riser", etc... )
            if let sfxData = try? String(contentsOf: sfxFileURL) {
                SFXs = sfxData.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            //MARK: FIFTH - Read PA (Pole Attributes)
            if let paData = try? String(contentsOf: paFileURL) {
                PAs = paData.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            
        } catch {
            print("Error reading GeoJSON file: \(error)")
            writeToLogFile(message: "Error reading file in readPolesGeoJSON: \(error)")
            showMessage(message: "Error occured reading poles file: \(error)")
        }
    }
    
    
    
    //Reads the Poles and Other Layers from .txt (OWNR/TLAs/etc...)
    private func readPolesFileQR(selectedFileURL: URL) {
        do {
            writeToLogFile(message: "Attempting to readPolesFileQR from: \(selectedFileURL.absoluteString)")
            
            var fileContents = try String(contentsOf: selectedFileURL)
            
            fileContents = processText(fileContents)
            
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
                if !poles.isEmpty {
                    poles.removeFirst()
                    self.plotCoord(stringArr: poles)
                } else {
                    // handle the error situation, perhaps throw an error or log it
                    print("Error: poles array is empty.")
                }
            }
            
            //MARK: SECOND - Read Owners
            if arrays.indices.contains(4) {
                let ownerArray = arrays[4]
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
            if arrays.indices.contains(1) {
                let paArray = arrays[1]
                for line in paArray{
                    PAs.append(line)
                }
            }
            
            
            //Create a file for the poles
            writeToFile(fileName: "poles_active"){}
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            writeToLogFile(message: "Error reading file in readPolesFileQR: \(error.localizedDescription)")
        }
    }
    
    
    
    func processText(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("PA_DATE") {
                lines.insert("_END_", at: index)
                break // Assuming there is only one PA_DATE line to modify
            }
        }
        
        let processedText = lines.joined(separator: "\n").replacingOccurrences(of: "_END_", with: "_END_\n")
        return processedText
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
            tempPole.initialData = tempPole.poledata
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
            annotation.initialData = tempPole.initialData
            
                        // Set the pole color here
//                        if tempPole.SRCID.contains("INSERT"){
//                            annotation.annotationColor = .blue
//                        } else if tempPole.suppdata == "CHECKED" {
//                            annotation.annotationColor = .green
//                        }else if tempPole.poledata.contains("GMAP") {
//                            annotation.annotationColor = .yellow
//                        }else if !tempPole.poledata.contains("ATT") && !tempPole.poledata.contains("AT&T"){
//                            annotation.annotationColor = .gray
//                        }else {
//                            annotation.annotationColor = .red
//                        }
            
            if tempPole.suppdata == "CHECKED" {
                annotation.annotationColor = .green
            }else {
                annotation.annotationColor = .red
            }
            
            
            annotations.append(annotation)
            
            map.addAnnotation(annotation)
            
            
        }
        
        let annotationCoordinate = annotations[0].coordinate
        let regionRadius: CLLocationDistance = 1000
        let region = MKCoordinateRegion(center: annotationCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        map.setRegion(region, animated: true)
        
        lblInfo.text = "Pole(s) mapped..."
        writeToLogFile(message: "\(annotations.count) objects should have been added to map...")
    }
    
    
    
    //Reads other file types MARK: For now, just Primary, Secondary, Transformers, and Reference
    private func readOtherFile(selectedFileURL : URL){
        do {
            
            let fileContents = try String(contentsOf: selectedFileURL)
            var stringArr = fileContents.components(separatedBy: CharacterSet.newlines)
            
            
            //JSON FILES
            if selectedFileURL.lastPathComponent == "OH_Primary.geojson" {
                writeToLogFile(message: "Attempting to read primary file...")
                
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    let featureCollection = try JSONDecoder().decode(JsonMultiLineObject.self, from: jsonData)
                    for feature in featureCollection.features {
                        for lineCoordinates in feature.geometry.coordinates {
                            var polylineCoordinates = [CLLocationCoordinate2D]()
                            for coordinatePair in lineCoordinates {
                                let coordinate = CLLocationCoordinate2D(latitude: coordinatePair[1], longitude: coordinatePair[0])
                                polylineCoordinates.append(coordinate)
                            }
                            let polyline = MKPolyline(coordinates: polylineCoordinates, count: polylineCoordinates.count)
                            polyline.title = feature.properties.UNIQUEID
                            map.addOverlay(polyline)
                            
                            let id = Int(polyline.title!)
                            
                            polylineDict[id!] = polyline
                            polylineDict[id!]?.title = "Primary"
                            
                            
                        }
                    }
                    writeToLogFile(message: "Finished reading primary file...")
                }
            }else if selectedFileURL.lastPathComponent == "OH_Secondary.geojson" {
                writeToLogFile(message: "Attempting to read secondary file...")
                
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    let featureCollection = try JSONDecoder().decode(JsonMultiLineObject.self, from: jsonData)
                    for feature in featureCollection.features {
                        for lineCoordinates in feature.geometry.coordinates {
                            var polylineCoordinates = [CLLocationCoordinate2D]()
                            for coordinatePair in lineCoordinates {
                                let coordinate = CLLocationCoordinate2D(latitude: coordinatePair[1], longitude: coordinatePair[0])
                                polylineCoordinates.append(coordinate)
                            }
                            let polyline = MKPolyline(coordinates: polylineCoordinates, count: polylineCoordinates.count)
                            polyline.title = feature.properties.UNIQUEID
                            map.addOverlay(polyline)
                        }
                    }
                    writeToLogFile(message: "Finished reading secondary file...")
                }
            }else if selectedFileURL.lastPathComponent == "OH_Transmission.geojson" {
                writeToLogFile(message: "Attempting to read transmission file...")
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    do {
                        let featureCollection = try JSONDecoder().decode(JsonMultiLineObject.self, from: jsonData)
                        for feature in featureCollection.features {
                            for lineCoordinates in feature.geometry.coordinates {
                                var polylineCoordinates = [CLLocationCoordinate2D]()
                                for coordinatePair in lineCoordinates {
                                    let coordinate = CLLocationCoordinate2D(latitude: coordinatePair[1], longitude: coordinatePair[0])
                                    polylineCoordinates.append(coordinate)
                                }
                                let polyline = MKPolyline(coordinates: polylineCoordinates, count: polylineCoordinates.count)
                                polyline.title = "Transmission"//feature.properties.UNIQUEID
                                map.addOverlay(polyline)
                            }
                        }
                    } catch {
                        print("Error decoding JSON: \(error)")
                    }
                    writeToLogFile(message: "Finished reading transmission file...")
                }
            }else if selectedFileURL.lastPathComponent == "OH_Xfmr.geojson" {
                writeToLogFile(message: "Attempting to read transformer file...")
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    let transformerCollection = try JSONDecoder().decode(JsonPointObject.self, from: jsonData)
                    for feature in transformerCollection.features {
                        let coordinates = feature.geometry.coordinates
                        let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                        let annotation = CustomPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = "Other"
                        annotation.subtitle = "Transformer"
                        
                        otherAnnotations.append(annotation)
                    }
                    writeToLogFile(message: "Finished reading transformer file...")
                }
            }else if selectedFileURL.lastPathComponent == "poles_all.geojson" {
                writeToLogFile(message: "Attempting to read reference poles file...")
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    do {
                        let poleCollection = try JSONDecoder().decode(PoleFeatureCollection.self, from: jsonData)
                        for feature in poleCollection.features {
                            let coordinates = feature.geometry.coordinates
                            let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                            let annotation = CustomPointAnnotation()
                            annotation.coordinate = coordinate
                            annotation.title = "Other"
                            annotation.subtitle = "Reference"
                            
                            otherAnnotations.append(annotation)
                        }
                    } catch {
                        print("Error decoding poles data: \(error)")
                    }
                    writeToLogFile(message: "Finished reading reference pole file...")
                }
            }else if selectedFileURL.lastPathComponent == "Premark_Base.geojson" {
                writeToLogFile(message: "Attempting to read premarks file...")
                // Process JSON file
                if let jsonData = fileContents.data(using: .utf8) {
                    do {
                        let textFeatureCollection = try JSONDecoder().decode(JsonTextObject.self, from: jsonData)
                        for feature in textFeatureCollection.features {
                            // Assuming only one pair of coordinates per feature (Point only)
                            let coordinate = CLLocationCoordinate2D(latitude: feature.geometry.coordinates[1], longitude: feature.geometry.coordinates[0])
                            let annotation = MKPointAnnotation()
                            annotation.coordinate = coordinate
                            annotation.title = feature.properties.label  // Assuming you want to display the label as the title
                            
                            map.addAnnotation(annotation)  // Assuming you have access to a map view object
                        }
                    } catch {
                        print("Error decoding Premark Base data: \(error)")
                    }
                    writeToLogFile(message: "Finished reading premarks file...")
                }
            }
            
            //END JSON FILES
            
            
            
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            writeToLogFile(message: "Error readingOtherFile (\(selectedFileURL.lastPathComponent): \(error.localizedDescription)")
        }
        
    }
    
    
    
    private func readWiring(selectedFileURL: URL) {
        do {
            let fileContents = try String(contentsOf: selectedFileURL)
            var stringArr = fileContents.components(separatedBy: CharacterSet.newlines)
            stringArr.removeFirst()  // Remove X,Y column
            
            var currentSection: String?
            var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
            var endCount = 0
            
            for line in stringArr {
                if line == "_END_" {
                    // Process the accumulated data for the current section
                    processSectionData(section: currentSection, dataDict: tempPolylineCoordinatesDict)
                    // Reset for the next section
                    tempPolylineCoordinatesDict.removeAll()
                    endCount += 1
                    // Determine the next section based on the count of _END_ occurrences
                    switch endCount {
                    case 1:
                        currentSection = "Secondary"
                    case 2:
                        currentSection = "Transformer"
                    default:
                        currentSection = nil
                    }
                } else if line.isEmpty {
                    // Skip empty lines
                    continue
                } else {
                    if currentSection == nil {
                        // This is the first block of data (Primary)
                        currentSection = "Primary"
                    }
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
            // Process the last section data if any
            processSectionData(section: currentSection, dataDict: tempPolylineCoordinatesDict)
            
            lblInfo.text = "Wiring object(s) mapped..."
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
    }
    
    
    
    private func processSectionData(section: String?, dataDict: [Int: [CLLocationCoordinate2D]]) {
        guard let section = section else { return }
        
        for (objectID, coordinates) in dataDict {
            switch section {
            case "Primary":
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = section
                polylineDict[objectID] = polyline
                
            case "Secondary":
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                if let existingMultiPolyline = multiPolylineDict[objectID] {
                    let updatedPolylines = existingMultiPolyline.polylines + [polyline]
                    multiPolylineDict[objectID] = MKMultiPolyline(updatedPolylines)
                } else {
                    let multiPolyline = MKMultiPolyline([polyline])
                    multiPolylineDict[objectID] = multiPolyline
                }
                
            case "Transformer":
                for coordinate in coordinates {
                    let annotation = CustomPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = "Other"
                    annotation.subtitle = "Transformer"
                    otherAnnotations.append(annotation)
                }
                
            default:
                print("Unknown section: \(section)")
            }
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
            if selectedFileURL.lastPathComponent.contains("poles") && !selectedFileURL.lastPathComponent.contains("poles_all.geojson") && !selectedFileURL.lastPathComponent.contains("poles.geojson"){
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
                
                
            }else if selectedFileURL.lastPathComponent == "poles.geojson"{
                readPolesGeoJSON(selectedFileURL: selectedFileURL)
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
        
        guard var documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        //If no active WA, write to base documents, else write to WA folder
        if waName.isEmpty{
            print("No active WA")
        }else{
            
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
        //let fileURL = documentsDirectory.appendingPathComponent("\(fileName).txt")
        
        do {
            try allPoles.write(to: fileURL, atomically: true, encoding: .utf8) //Changed to true
            // Delete the active poles file
            let fileManager = FileManager.default
            
            //            if fileName == "poles_active"{
            //                try fileManager.removeItem(at: documentsDirectory.appendingPathComponent("poles_active.txt"))
            //                showMessage(message: "Poles uploaded as complete. Use PoleVAULT to import completed poles.")
            //            }
            
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
        
        do {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.unzipItem(at: sourceURL, to: destinationURL)
            deleteMacOSXFolder(in: destinationURL)  // Assuming this function cleans up any unwanted macOS system files
            lblInfo.text = "File successfully unzipped..."
            
            // Invoke the document picker
            //presentDocumentPicker(in: destinationURL)
        } catch {
            print("Error during unzip process: \(error)")
        }
    }
    
    
    
    func presentDocumentPicker(in directoryURL: URL) {
        let contentTypes: [UTType] = [.plainText, .archive]  // Specify the file types
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.directoryURL = directoryURL  // Set the directory URL to the folder where files are unzipped
        
        present(documentPicker, animated: true, completion: nil)
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
        _ = fileRef.putFile(from: destinationURL, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading file: \(error)")
            } else {
                print("Upload succeeded!")
            }
        }
    }
    
    
    
    func pathForFileInDocumentsDirectory(_ fileName: String) -> String? {
        let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentDirectoryURL?.appendingPathComponent(fileName).path
    }
    
    
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    //MARK: End File picker + Writing to Files
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: Getting and Setting of Defaults (App Settings)
    
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
        
        
        if getUsername() == "ERIKT"{
//            if let image = UIImage(named: "Tesla-M3.jpg") {
//                // Resize the image
//                userIcon = resizeImage(image: image, targetSize: CGSize(width: 75, height: 75))
//            }
        }else{
//            if let image = UIImage(named: "4Runner.jpg") {
//                // Resize the image
//                userIcon = resizeImage(image: image, targetSize: CGSize(width: 75, height: 75))
//            }
        }
        
        
    }
    
    
    
    //Clears All User Defaults (Settings) (√)
    func resetUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }
    
    //MARK: End Getting and Setting of Defaults (App Settings)
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: Button and Switch Functions
    
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
        feedbackGenerator.impactOccurred() // Haptic Feedback
        
        writeToLogFile(message: "User tapped export.")
        
        let fileManager = FileManager.default
        guard let waName = UserDefaults.standard.string(forKey: "WorkAreaName"), !waName.isEmpty else {
            self.showMessage(message: "WorkArea name not set or empty.")
            return
        }
        
        writeToLogFile(message: "WorkArea name is set as: \(waName)")
        
        let components = storageFileName.components(separatedBy: "-")
        if let lastComponent = components.last {
            originalTimestamp = lastComponent
        } else {
            
        }
        
        
        do {
            let workAreaPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(waName)
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Collect media files from the base documents directory
            let mediaFiles = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "jpg" || $0.pathExtension == "mp4" || $0.absoluteURL.lastPathComponent == "media.csv"}
            
            writeToLogFile(message: "Found \(mediaFiles.count) media files to include with export.")
            
            let csvFileName = "poles_checked.csv"
            let csvFileURL = workAreaPath.appendingPathComponent(csvFileName)
            var csvText = "X,Y,comments,poledata,suppdata,VSUMInfo,SRCID,SRCOWN\n"
            let checkedPoles = poles.filter { $0.suppdata == "CHECKED" }
            for pole in checkedPoles {
                csvText += pole.toExportString() + "\n"
            }
            try csvText.write(to: csvFileURL, atomically: true, encoding: .utf8)
            
            writeToLogFile(message: "Created poles_checked.csv.")
            
            let fileURLs = try fileManager.contentsOfDirectory(at: workAreaPath, includingPropertiesForKeys: nil)
            let zipFileName = getFirebaseExportName() + ".zip"
            let zipFileURL = workAreaPath.appendingPathComponent(zipFileName)
            
            if fileManager.fileExists(atPath: zipFileURL.path) {
                try fileManager.removeItem(at: zipFileURL)
            }
            
            guard let archive = Archive(url: zipFileURL, accessMode: .create) else {
                showMessage(message: "Failed to create zip file.")
                return
            }
            
            // Add files to the zip archive
            for fileURL in fileURLs + mediaFiles {
                let fileName = fileURL.lastPathComponent
                let basePath = fileURL.deletingLastPathComponent()
                try archive.addEntry(with: fileName, relativeTo: basePath)
            }
            
            writeToLogFile(message: "Created export zip file.")
            
            // Remove media files after zipping
            for fileURL in mediaFiles {
                try fileManager.removeItem(at: fileURL)
                print("Removed \(fileURL.lastPathComponent) from local storage.")
            }
            
            writeToLogFile(message: "Removed any non-zipped media files.")
            
            // Upload the zip file
            let storageRef = Storage.storage().reference().child("PV/\(zipFileName)")
            
            writeToLogFile(message: "Attempting to upload zip file to Firebase...")
            _ = storageRef.putFile(from: zipFileURL, metadata: nil) { metadata, error in
                if let error = error {
                    self.writeToLogFile(message: "Error uploading file: \(error.localizedDescription)")
                    self.showMessage(message: "Error uploading file: \(error.localizedDescription)")
                    return
                }
                
                
//                let fileString = "PV/" + zipFileName
//                let itemsToShare = [fileString]
//                let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
//                activityViewController.excludedActivityTypes = [.addToReadingList, .openInIBooks]
                
                
                let keepFiles = ["location.txt", "OH_Primary.geojson","OH_Secondary.geojson","OH_Transmission.geojson","OH_Xfmr.geojson","OWNR.txt","PA.txt","poles.geojson","poles_active.txt","poles_all.geojson","Premark_Base.geojson","SFX.txt","TLA.txt"]
                
                self.removeFiles(filenamesToKeep: keepFiles, in: workAreaPath)
                
                //This allows user to export FB url
//                if let popoverController = activityViewController.popoverPresentationController {
//                    popoverController.sourceView = self.view
//                    popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
//                    popoverController.permittedArrowDirections = []
//                }
//                
//                self.present(activityViewController, animated: true, completion: nil)
                
                
                self.writeToLogFile(message: "Successfully uploaded export to Firebase.")
                self.showMessage(message: "Export complete.")
            }
        } catch {
            writeToLogFile(message: "Error occurred during export process: \(error.localizedDescription)")
            showMessage(message: "Error processing files: \(error.localizedDescription)")
        }
    }
    
    
    
    func removeFiles(filenamesToKeep: [String], in directory: URL){
        let fileManager = FileManager.default
        
        do {
            // Get the contents of the directory
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            // Iterate through each file in the directory
            for file in contents {
                if !filenamesToKeep.contains(file.lastPathComponent) {
                    // If the file is not in the keep list, delete it
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("An error occurred: \(error)")
        }
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
        
        writeToFile(fileName: "poles_active"){}
    }
    
    
    
    //Turns on or off crosshair on map
    @IBAction func btnCrosshairTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        if btnCrosshair.isOn{
            
            let crossSize: CGFloat = 20
            crosshairView = UIView(frame: CGRect(x: map.bounds.midX - crossSize/2,
                                                 y: map.bounds.midY - crossSize/2,
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
            map.mapType = .mutedStandard
        }
    }
    
    
    
    //Brings up settings menu
    @IBAction func btnSettingsTap(_ sender: Any) {
        feedbackGenerator.impactOccurred() //Haptic Feedback
        //Show poledetails screen
        performSegue(withIdentifier: "mapToSettingsSegue", sender: nil)
        showMessage(message: "Settings are coming soon...")
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
        let buttons = [btnCrosshair, btnCenter, btnBaseMap, btnDirections, btnImport, btnExport, btnSettings, btnZoomIn, btnZoomOut, btnRotate, btnInsert, btnDrawWiring, btnRemove, btnRevert]
        
        for button in buttons {
            setButtonApperance(button: button!)
            addButtonLongPressGesture(to: button!)
        }
    }
    
    
    
    //Removes a pole object from the map
    @IBAction func btnRemoveTap(_ sender: Any) {
        //Put a red border around the screen to show a "delete" mode
        isInDeleteMode = !isInDeleteMode
        if isInDeleteMode {
            map.layer.borderWidth = 2 // Set the border width
            map.layer.borderColor = UIColor.red.cgColor
            lblInfo.text = "Tap on poles remove them from the map"
        } else {
            map.layer.borderWidth = 0
            lblInfo.text  = "Done removing poles"
        }
    }
    
    
    //Action button for polevault pair mode
    @IBAction func btnPVPairActionTap(_ sender: Any) {
        // Check which type of action is required
        if btnPVPairAction.titleLabel?.text == "Scan QR Code" {
            needSimpleQR = true
            setupQRCodeScanning()
        } else if btnPVPairAction.titleLabel?.text == "Scan Bar Code" {
            setupBarcodeScanning()
        } else if btnPVPairAction.titleLabel?.text == "Take Picture" {
            needPVPairPic = true
            
            // Existing code to take a picture
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .camera
            present(imagePickerController, animated: true, completion: nil)
        }
    }
    
    
    //Just a button to temporarily test things
    @IBAction func btnLoadRecentData(_ sender: Any) {
        feedbackGenerator.impactOccurred()
        
        let alert = UIAlertController(title: "Load Recent WA", message: "Would you like to load data for WorkArea: \(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "(No WorkArea Found)")? This will overwrite all current data...", preferredStyle: .alert)
        
        // Add the "Yes" action
        let yesAction = UIAlertAction(title: "Yes", style: .default) { [unowned self] _ in
            guard let waName = UserDefaults.standard.string(forKey: "WorkAreaName"), !waName.isEmpty else {
                self.showMessage(message: "WorkArea name not set or empty.")
                return
            }
            
            let workAreaPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(waName)
            
            // Ensure the directory exists before attempting to load files from it
            if FileManager.default.fileExists(atPath: workAreaPath.path) {
                // List of all geojson files you intend to load
                let filesToLoad = [
                    "poles_all.geojson", "OH_Primary.geojson", "OH_Secondary.geojson",
                    "OH_Transmission.geojson", "OH_Xfmr.geojson", "Premark_Base.geojson"
                ]
                
                // Load each file
                filesToLoad.forEach { fileName in
                    let fileURL = workAreaPath.appendingPathComponent(fileName)
                    self.readOtherFile(selectedFileURL: fileURL)
                }
                
                let fileURL = workAreaPath.appendingPathComponent("poles_active.txt")
                
                print("Attempting to load poles_active from \(fileURL.absoluteString)")
                
                //Clear current poles
                poles = []
                
                self.readPolesFile(selectedFileURL: fileURL)
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("poles_all.geojson"))
                //self.readPolesGeoJSON(selectedFileURL: workAreaPath.appendingPathComponent("poles.geojson"))
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("OH_Primary.geojson"))
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("OH_Secondary.geojson"))
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("OH_Transmission.geojson"))
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("OH_Xfmr.geojson"))
                self.readOtherFile(selectedFileURL: workAreaPath.appendingPathComponent("Premark_Base.geojson"))
                
            } else {
                self.showMessage(message: "No directory found for the specified WorkArea: \(waName). You may need to reimport from PoleVAULT.")
            }
        }
        alert.addAction(yesAction)
        
        // Add the "No" action
        let noAction = UIAlertAction(title: "No", style: .cancel)
        alert.addAction(noAction)
        
        // Present the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    
    @IBAction func btnPvPairTap(_ sender: Any) {
        feedbackGenerator.impactOccurred()
    }
    //MARK: End Button and Switch Functions
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: QR Codes
    //Lets user scan QR code to get poles from PV (√)
    private func setupQRCodeScanning() {
        self.writeToLogFile(message: "User requested to scan QR code. Creating QR Code scanner...")
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            qrInitializeFailed()
            return
        }
        
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(metadataOutput) else {
            qrInitializeFailed()
            return
        }
        
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        startQRScanningSession()
        
        let scanRect = addScanningGuideOverlay()
        let metadataOutputRect = previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
        metadataOutput.rectOfInterest = metadataOutputRect
        
        let buttonWidth = (view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right) / 2
        let buttonY = scanRect.maxY + 20
        
        // Create and configure lblQRInfo
        lblQRInfo = UILabel(frame: CGRect(x: 0, y: scanRect.minY - 60, width: view.bounds.width, height: 50))
        lblQRInfo?.text = "Scan QR Code(s) from PoleVAULT"
        lblQRInfo?.textAlignment = .center
        lblQRInfo?.backgroundColor = .black
        if let label = lblQRInfo {
            view.addSubview(label)
        }
        
        // Setup cancelButton
        cancelButton = UIButton(frame: CGRect(x: view.safeAreaInsets.left, y: buttonY, width: buttonWidth, height: 50))
        cancelButton?.backgroundColor = .gray
        cancelButton?.setTitle("Cancel", for: .normal)
        cancelButton?.addTarget(self, action: #selector(btnCancelScanning(_:)), for: .touchUpInside)
        if let button = cancelButton {
            view.addSubview(button)
        }
        
        // Setup stopButton
        stopButton = UIButton(frame: CGRect(x: view.safeAreaInsets.left + buttonWidth, y: buttonY, width: buttonWidth, height: 50))
        stopButton?.backgroundColor = UIColor(red: 34/255.0, green: 139/255.0, blue: 34/255.0, alpha: 1.0)
        stopButton?.setTitle("Done", for: .normal)
        stopButton?.addTarget(self, action: #selector(btnDoneScanning(_:)), for: .touchUpInside)
        if let button = stopButton {
            view.addSubview(button)
        }
        
        self.writeToLogFile(message: "QR Code scanner created.")
    }
    
    
    
    //Show error if device does not support or allow camera access (√)
    func qrInitializeFailed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    
    
    //Captures QR code, makes sure it has not already been scanned, then process QR code (√)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
//        self.writeToLogFile(message: "QR Code found, scanning data...")
//        
//        if let metadataObject = metadataObjects.first {
//                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
//                guard let stringValue = readableObject.stringValue else { return }
//
//                // Play sound or vibrate to indicate a successful scan
//                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
//
//                // Stop the scanning session immediately
//                captureSession.stopRunning()
//            }
//
//            dismiss(animated: true)
//
//            // Ensure all UI updates happen on the main thread
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self, let metadataObject = metadataObjects.first else { return }
//
//                // Stop scanning
//                self.captureSession.stopRunning()
//
//                // Safely unwrap the scanned code and handle duplicates
//                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
//                      let stringValue = readableObject.stringValue else { return }
//
//                // Avoid processing the same code again
//                if stringValue == self.lastScannedCode {
//                    // Restart scanning after a short delay
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                        self.captureSession.startRunning()
//                    }
//                } else {
//                    // Update the last scanned code
//                    self.lastScannedCode = stringValue
//
//                    // Check if it's a QR code or a barcode and handle accordingly
//                    switch readableObject.type {
//                    case .qr:
//                        // Handle QR code data
//                        self.showScanSuccessIndicator()  // Optional: Show success UI feedback
//                        self.qrDataFound(code: stringValue)
//                        
//
//                    default:
//                        // If it's an unsupported code type, log or handle it if needed
//                        print("Unsupported code type: \(readableObject.type)")
//                    }
//                }
//            }
        
        self.writeToLogFile(message: "Code found, scanning data...")
            
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                      let stringValue = readableObject.stringValue else { return }
                
                // Play sound or vibrate to indicate a successful scan
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                // Stop the scanning session immediately
                captureSession.stopRunning()
                
                // Update the last scanned code
                self.lastScannedCode = stringValue
                
                // Handle code based on scanning mode
                switch scanningMode {
                case .qrCode:
                    if readableObject.type == .qr {
                        self.showScanSuccessIndicator()
                        self.qrDataFound(code: stringValue)
                    } else {
                        // Ignore other code types
                        return
                    }
                case .barCode:
                    if readableObject.type != .qr {
                        self.showScanSuccessIndicator()
                        self.barcodeDataFound(code: stringValue)
                    } else {
                        // Ignore QR codes when scanning barcodes
                        return
                    }
                }
            }
    }
    
    
    
    //Attempt to decompress the qr data string (√)
    func qrDataFound(code: String) {
        
        print("QR Code found: \(code)")
        
        if needSimpleQR{
            self.writeToLogFile(message: "QR Code scanned: \(code)")
            self.updateReturnField(with: code)
            needSimpleQR = false
            cleanupScanningUI()
            lblInfo.text = "QR Code scanned successfully."
        }else{
            guard let decodedData = Data(base64Encoded: code) else {
                self.writeToLogFile(message: "Was unable to decode QR code string.")
                showMessage(message: "Unable to scan QR code, please try again.")
                return
            }
            
            do {
                let decompressedData = try decodedData.gunzipped()
                guard let decompressedString = String(data: decompressedData, encoding: .utf8) else {
                    self.writeToLogFile(message: "Was unable to decompress QR code string.")
                    showMessage(message: "Unable to scan QR code, please try again.")
                    return
                }
                scannedData += decompressedString
                
                if scannedData.contains("FRBASE") {
                    // Call saveScannedData here, but don't reset scannedData yet
                    saveScannedData()
                }
            } catch {
                self.writeToLogFile(message: "Was unable to decompress QR code string.")
                showMessage(message: "Unable to scan QR code, please try again.")
            }
        }
        
        
    }
    
    
    func barcodeDataFound(code: String) {
        // Handle the barcode data, e.g., print it to the console
        self.writeToLogFile(message: "Barcode data found: \(code)")
        lblInfo.text = "Bar code scanned successfully."
        
        //Need to upload code text to firebase as return data
        updateReturnField(with: code)
        
        // Stop scanning and clean up UI
        self.captureSession.stopRunning()
        cleanupScanningUI()
    }

    
    func setupScanningUI(scanRect: CGRect, infoText: String) {
        let buttonWidth = (view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right) / 2
        let buttonY = scanRect.maxY + 20
        
        // Configure lblQRInfo
        lblQRInfo = UILabel(frame: CGRect(x: 0, y: scanRect.minY - 60, width: view.bounds.width, height: 50))
        lblQRInfo?.text = infoText
        lblQRInfo?.textAlignment = .center
        lblQRInfo?.backgroundColor = .black
        if let label = lblQRInfo {
            view.addSubview(label)
        }
        
        // Setup cancelButton
        cancelButton = UIButton(frame: CGRect(x: view.safeAreaInsets.left, y: buttonY, width: buttonWidth, height: 50))
        cancelButton?.backgroundColor = .gray
        cancelButton?.setTitle("Cancel", for: .normal)
        cancelButton?.addTarget(self, action: #selector(btnCancelScanning(_:)), for: .touchUpInside)
        if let button = cancelButton {
            view.addSubview(button)
        }
        
        // Setup stopButton
        stopButton = UIButton(frame: CGRect(x: view.safeAreaInsets.left + buttonWidth, y: buttonY, width: buttonWidth, height: 50))
        stopButton?.backgroundColor = UIColor(red: 34/255.0, green: 139/255.0, blue: 34/255.0, alpha: 1.0)
        stopButton?.setTitle("Done", for: .normal)
        stopButton?.addTarget(self, action: #selector(btnDoneScanning(_:)), for: .touchUpInside)
        if let button = stopButton {
            view.addSubview(button)
        }
    }

    func cleanupScanningUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
            self.previewLayer.removeFromSuperlayer()
            self.lblQRInfo?.removeFromSuperview()
            self.stopButton?.removeFromSuperview()
            self.cancelButton?.removeFromSuperview()
            self.overlayView?.removeFromSuperview()
            
            // Reset state variables if needed
            self.scannedData = ""
            self.scannedQRCount = 0
            self.fileCount += 1
            self.lastScannedCode = nil
        }
    }
    
    
    
    
    //If the stop button on QR view is tapped, save data and either continue to more QR codes or stop (√)
    @IBAction func btnDoneScanning(_ sender: Any) {
        self.writeToLogFile(message: "User tapped Done during QR Code scanning.")
        cleanupScanningUI()
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            self.captureSession.stopRunning()
//            self.previewLayer.removeFromSuperlayer()
//            self.lblQRInfo?.removeFromSuperview()
//            self.stopButton?.removeFromSuperview()
//            self.cancelButton?.removeFromSuperview()
//            self.overlayView?.removeFromSuperview()
//            
//            // Additional UI or state reset here
//            self.scannedData = ""
//            self.scannedQRCount = 0
//            self.fileCount += 1
//            self.lastScannedCode = nil
//        }
    }
    
    
    
    //If cancel button on QR view is tapped, close the QR view (√)
    @objc func btnCancelScanning(_ sender: UIButton) {
        self.writeToLogFile(message: "User cancelled QR Code scanning.")
        cleanupScanningUI()
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            self.captureSession.stopRunning()
//            self.previewLayer.removeFromSuperlayer()
//            self.lblQRInfo?.removeFromSuperview()
//            self.stopButton?.removeFromSuperview()
//            self.cancelButton?.removeFromSuperview()
//            self.overlayView?.removeFromSuperview()
//        }
    }
    
    
    
    //Begins camera capturing (√)
    func startQRScanningSession() {
        DispatchQueue.global().async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    
    
    //Checks whether QR points to FireBase Storage or to data contained within the QR, then loads data accordingly TODO: Make this work with both QR types
    func saveScannedData() {
        
        //If QR Code string is prefixed with FRBASE, then grab data from Cloud
        if scannedData.contains("FRBASE"){
            self.writeToLogFile(message: "Attempting to go to Firebase to retrieve data...")
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    self.showMessage(message: "Error occured while trying to import data. Check connection and try again.")
                    self.writeToLogFile(message: "Error occured while trying to get data from Firebase. Error: \(error.localizedDescription)")
                    return
                }

                
                // Reference to Firebase Storage
                let storageRef = Storage.storage().reference()
                let zipFilePath = self.scannedData.replacingOccurrences(of: "FRBASE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) // Path to the zip file
                let fileRef = storageRef.child(zipFilePath)
                
                // Save original file name (used for export later)
                let url = URL(fileURLWithPath: zipFilePath)
                self.writeToLogFile(message: "Attempting to grab data from file: \(url.absoluteString)")
                self.storageFileName = url.deletingPathExtension().lastPathComponent
                
                let maxSize: Int64 = 10 * 1024 * 1024  // Max size: 10MB
                
                // Download the zip file data
                fileRef.getData(maxSize: maxSize) { data, error in
                    guard let data = data else {
                        self.showMessage(message: "Error downloading zip file: \(String(describing: error))")
                        self.writeToLogFile(message: "Error downloading zip file from Firebase. Error: \(String(describing: error))")
                        return
                    }
                    
                    // Get the URL for the Documents directory in the app's sandbox
                    guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("Failed to locate the document directory")
                        return
                    }
                    
                    // Figure out WA name from file path
                    let components = self.storageFileName.components(separatedBy: "-")
                    if components.count >= 3 {
                        self.waName = components[2] // This will include ".zip"
                        UserDefaults.standard.set(self.waName, forKey: "WorkAreaName") // Save WA Name to settings
                        self.writeToLogFile(message: "Set WorkArea name setting to: \(self.waName)")
                        let fileName: String = "\(components[0])\(components[1])\(components[2])"
                        UserDefaults.standard.set(fileName, forKey: "StorageFileName") // Save Original Zip File name to settings
                        self.writeToLogFile(message: "Set Storage File Name setting to: \(fileName)")
                    }
                    
                    // Create a destination URL for the zip file and the folder to contain the unzipped files
                    let fileURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/downloadedFile.zip")
                    let folderURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/")
                    
                    // Ensure the folder exists before trying to write to it
                    if FileManager.default.fileExists(atPath: folderURL.path) {
                        // Present an alert to ask the user if they want to overwrite the existing files
                        let alertController = UIAlertController(title: "Overwrite Files?", message: "Data for \(self.waName) already exists. Do you want to overwrite the older data?", preferredStyle: .alert)
                        let overwriteAction = UIAlertAction(title: "Overwrite", style: .destructive) { _ in
                            self.writeToLogFile(message: "User chose to overwrite data for the WorkArea.")
                            self.handleFileOverwrite(folderURL: folderURL, fileURL: fileURL, data: data)
                        }
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                        
                        alertController.addAction(overwriteAction)
                        alertController.addAction(cancelAction)
                        
                        DispatchQueue.main.async {
                            self.present(alertController, animated: true)
                        }
                    } else {
                        do {
                            // Create the folder if it does not exist
                            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                            self.saveAndUnzipData(data: data, fileURL: fileURL, folderURL: folderURL)
                            
                            //Close QR window
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                self.captureSession.stopRunning()
                                self.previewLayer.removeFromSuperlayer()
                                self.lblQRInfo?.removeFromSuperview()
                                self.stopButton?.removeFromSuperview()
                                self.cancelButton?.removeFromSuperview()
                                self.overlayView?.removeFromSuperview()
                                
                                // Additional UI or state reset here
                                self.scannedData = ""
                                self.scannedQRCount = 0
                                self.fileCount += 1
                                self.lastScannedCode = nil
                            }
                            
                        } catch {
                            print("Error creating folder: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    
    
    func handleFileOverwrite(folderURL: URL, fileURL: URL, data: Data) {
        do {
            // Attempt to delete the existing folder
            try FileManager.default.removeItem(at: folderURL)
            // Recreate the directory
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            saveAndUnzipData(data: data, fileURL: fileURL, folderURL: folderURL)
            print("Existing files for WorkArea \(self.waName) overwritten.")
            self.writeToLogFile(message: "Existing files for WorkArea \(self.waName) overwritten.")
            
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.captureSession?.stopRunning()
                self.previewLayer?.removeFromSuperlayer()
                self.lblQRInfo?.removeFromSuperview()
                self.stopButton?.removeFromSuperview()
                self.cancelButton?.removeFromSuperview()
                self.overlayView?.removeFromSuperview()
                
                // Additional UI or state reset here
                self.scannedData = ""
                self.scannedQRCount = 0
                self.fileCount += 1
                self.lastScannedCode = nil
            }
        } catch {
            print("Error while overwriting WorkArea folder: \(error)")
        }
    }
    
    
    
    func saveAndUnzipData(data: Data, fileURL: URL, folderURL: URL) {
        do {
            try data.write(to: fileURL)
            self.unzipFile(at: fileURL, to: folderURL)
            
            try FileManager.default.removeItem(at: fileURL)
            
            //Check if folder contains a poles_active.txt file and use this instead of poles.geojson
            
                
            let polesActivePath = folderURL.appendingPathComponent("poles_active.txt")
                    
            if FileManager.default.fileExists(atPath: polesActivePath.path) {
                poles = []
                print("Poles_active alread exists, should load it correctly")
                self.readPolesFile(selectedFileURL: polesActivePath)
                
            }else{
                self.readPolesGeoJSON(selectedFileURL: folderURL.appendingPathComponent("poles.geojson"))
                
            }
            
            //Read all layers
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("poles_all.geojson"))
            
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("OH_Primary.geojson"))
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("OH_Secondary.geojson"))
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("OH_Transmission.geojson"))
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("OH_Xfmr.geojson"))
            self.readOtherFile(selectedFileURL: folderURL.appendingPathComponent("Premark_Base.geojson"))
        } catch {
            print("Error saving or unzipping file: \(error)")
        }
    }
    
    
    
    //Creates a 'box' for the user to place the QR code in
    func addScanningGuideOverlay() -> CGRect {
        // Create a new view for the overlay
        let overlayView = UIView(frame: previewLayer.frame)
        overlayView.backgroundColor = UIColor.clear
        self.overlayView = overlayView
        view.addSubview(overlayView)
        
        // Create a layer to darken the area outside the scanning area
        let darkLayer = CAShapeLayer()
        let path = UIBezierPath(rect: overlayView.bounds)
        let scanRect = CGRect(x: 0, y: (overlayView.bounds.height - view.bounds.width) / 2, width: view.bounds.width, height: view.bounds.width)
        
        
        path.append(UIBezierPath(rect: scanRect).reversing())
        darkLayer.path = path.cgPath
        darkLayer.fillColor = UIColor(white: 0, alpha: 0.5).cgColor
        overlayView.layer.addSublayer(darkLayer)
        
        // Create a border around the scanning area
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(rect: scanRect).cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.lineWidth = 2
        overlayView.layer.addSublayer(borderLayer)
        
        return scanRect
    }
    
    
    
    //On successful capture of QR code, show a checkmark to user (√)
    func showScanSuccessIndicator() {
        let overlayView = UIView(frame: previewLayer.frame)
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        
        let label = UILabel()
        label.text = "✓"
        label.font = UIFont.systemFont(ofSize: 48)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = overlayView.bounds
        
        overlayView.addSubview(label)
        view.addSubview(overlayView)
        
        //Remove label after delay
        UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
            overlayView.alpha = 0
        }) { _ in
            overlayView.removeFromSuperview()
        }
    }
    
    
    
    //Creates a hidden view that is used to show QR codes to export (√)
    private func setupQRExportImageView() {
        let size = min(view.frame.size.width, view.frame.size.height * 0.6) // Adjust the size as needed
        imageView.frame = CGRect(x: 0, y: (view.frame.size.height - size) / 2, width: size, height: size)
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true // Initially hidden
        view.addSubview(imageView)
    }
    
    
    
    //Creates a 'Next' button that is shown on the QC Export view (√)
    private func setupQRExportNextButton() {
        nextButton.frame = CGRect(x: 0, y: imageView.frame.maxY + 10, width: view.frame.size.width, height: 50)
        nextButton.setTitle("Next", for: .normal)
        nextButton.backgroundColor = UIColor(red: 0/255, green: 106/255, blue: 145/255, alpha: 1)
        nextButton.addTarget(self, action: #selector(showNextQRCode), for: .touchUpInside)
        nextButton.isHidden = true // Initially hidden
        view.addSubview(nextButton)
    }
    
    
    
    //Show any QR codes in list and close QR export view if none (√)
    @objc func showNextQRCode() {
        if !qrImages.isEmpty {
            if currentIndex < qrImages.count - 1 {
                // Move to the next QR code
                currentIndex += 1
                imageView.image = qrImages[currentIndex]
                
                // Update button title with the current index and total count
                let title = "Next (\(currentIndex + 1) of \(qrImages.count))"
                nextButton.setTitle(title, for: .normal)
            } else {
                // Hide imageView and nextButton after the last QR code
                imageView.isHidden = true
                nextButton.isHidden = true
                
                qrImages = []
            }
        }
    }
    
    
    
    //Returns the actual QR code image from a text input (√)
    func createQRCode(from text: String) -> UIImage? {
        let data = text.data(using: .utf8)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            if let qrImage = filter.outputImage {
                let scaleX = imageView.frame.size.width / qrImage.extent.size.width
                let scaleY = imageView.frame.size.width / qrImage.extent.size.height
                let transformedImage = qrImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                return UIImage(ciImage: transformedImage)
            }
        }
        return nil
    }
    
    
    
    //Compresses input text(√)
    func compress(text: String) -> Data? {
        return try? text.data(using: .utf8)?.gzipped()
    }
    
    
    
    //Generates QR codes for a given txt file. If data would be cut off, it creates a new QR code from the start of the given line (√)
    func generateQRCodeImages(from filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        guard let text = try? String(contentsOf: fileURL) else {
            print("Failed to read from URL: \(fileURL)")
            return
        }
        
        let lines = text.components(separatedBy: .newlines)
        var chunk = ""
        
        imageView.isHidden = true
        nextButton.isHidden = true
        
        for line in lines {
            if line == "_END_" {
                break //Stop processing when "_END_" is encountered
            }
            
            if (chunk.count + line.count + 1) > maxDataSize { //+1 for newline
                if let compressedData = compress(text: chunk) {
                    let base64String = compressedData.base64EncodedString()
                    if let image = createQRCode(from: base64String) {
                        qrImages.append(image)
                    }
                }
                chunk = ""
            }
            chunk += line + "\n"
        }
        
        if !chunk.isEmpty {
            if let compressedData = compress(text: chunk) {
                let base64String = compressedData.base64EncodedString()
                if let image = createQRCode(from: base64String) {
                    qrImages.append(image)
                }
            }
        }
        
        if !qrImages.isEmpty {
            currentIndex = 0
            imageView.image = qrImages[currentIndex]
            imageView.isHidden = false
            nextButton.isHidden = false
            // Set initial title for the "Next" button
            let title = "Next (\(currentIndex + 1) of \(qrImages.count))"
            nextButton.setTitle(title, for: .normal)
        }
        
    }
    
    
    private func setupBarcodeScanning() {
        self.writeToLogFile(message: "User requested to scan Bar code. Creating Barcode scanner...")
        scanningMode = .barCode
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            qrInitializeFailed()
            return
        }
        
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(metadataOutput) else {
            qrInitializeFailed()
            return
        }
        
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        // Set metadataObjectTypes to include popular barcode types
        let supportedBarCodeTypes: [AVMetadataObject.ObjectType] = [
            .ean8,
            .ean13,
            .code128,
            .code39,
            .code39Mod43,
            .code93,
            .pdf417,
            .dataMatrix,
            .upce,
            .itf14,
            .interleaved2of5,
            .aztec
        ]
        
        let availableBarCodeTypes = metadataOutput.availableMetadataObjectTypes.filter { supportedBarCodeTypes.contains($0) }
        metadataOutput.metadataObjectTypes = availableBarCodeTypes
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        startQRScanningSession()
        
        let scanRect = addScanningGuideOverlay()
        let metadataOutputRect = previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
        metadataOutput.rectOfInterest = metadataOutputRect
        
        // Configure UI elements
        setupScanningUI(scanRect: scanRect, infoText: "Scan Bar Code")
        
        self.writeToLogFile(message: "Barcode scanner created.")
    }
    //MARK: End QR Codes
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: Settings Functions
    
    //Get Primary line size from settings (√)
    func getPrimaryLineSizeFromUserDefaults() -> Int {
        return UserDefaults.standard.object(forKey: "PrimaryLineSize") as? Int ?? 1
    }
    
    
    
    //Get username from settings (√)
    func getUsername() -> String {
        var username = settings.string(forKey: "Username") ?? ""
            
            // Check if the username contains any lowercase letters
            if username != username.uppercased() {
                // Convert to uppercase
                username = username.uppercased()
                // Update the stored value in UserDefaults
                settings.set(username, forKey: "Username")
            }
            
            return username
    }
    
    
    
    //Change or create a username (√)
    func makeUsername() {
        let alert = UIAlertController(title: "Enter Username", message: "Enter VSum username. This should be first name + last name initial. Example: JOEYJ", preferredStyle: .alert)
            
            alert.addTextField { textField in
                // Set the text field to capitalize all characters
                textField.autocapitalizationType = .allCharacters
                // Optionally, set the keyboard appearance to default
                textField.keyboardType = .default
            }
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
                guard let text = alert?.textFields?.first?.text, !text.isEmpty, self?.containsOnlyLetters(string: text) == true else {
                    self?.makeUsername()
                    return
                }
                
                // Convert the input text to uppercase
                let uppercaseText = text.uppercased()
                
                self?.settings.set(uppercaseText, forKey: "Username")
                self?.lblInfo.text = "Hi \(uppercaseText)!"
                
                self?.writeToLogFile(message: "User set username as: \(uppercaseText)")
            })
            
            present(alert, animated: true)
    }
    
    //MARK: End Settings Functions
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: MEDIA FUNCTIONS (SCANNING OPERATIONS, CAMERA, ETC...)
    //Will display a locally stored image based on a filename
    func showPicture(filename: String?) {
        guard let filename = filename else { return }
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            let imageViewController = UIViewController()
            imageViewController.view.backgroundColor = .white
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = imageViewController.view.frame
            imageViewController.view.addSubview(imageView)
            
            self.present(imageViewController, animated: true, completion: nil)
        }
    }
    
    
    //Will play a locally stored video based on a filename
    func showVideo(filename: String?) {
        guard let filename = filename else { return }
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        // Check if the video file exists at the specified URL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Video file does not exist at the given path")
            return
        }

        // Create an AVPlayer instance with the URL of the video file
        let player = AVPlayer(url: fileURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        // Present the player view controller
        DispatchQueue.main.async {
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play() // Automatically start playing the video
            }
        }
    }
    
    
    func addAnnotationAtCurrentLocation(fileName: String, type: String) {
        // Get the center point of the map view
        let mapCenterPoint = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        
        // Convert the center point to a coordinate
        let centerCoordinate = map.convert(mapCenterPoint, toCoordinateFrom: map)
        
        // Create an annotation with the center coordinate
        let annotation = CustomPointAnnotation()
        annotation.coordinate = centerCoordinate
        if type == "Pic"{
            annotation.title = "Pic"
            annotation.subtitle = fileName
        }else if type == "Video"{
            annotation.title = "Video"
            annotation.subtitle = fileName
        }else{
            annotation.title = "POI"
            annotation.subtitle = "POI"
        }
        
        
        // Add the annotation to the map view
        //map.addAnnotation(annotation)
        otherAnnotations.append(annotation)
        
        //Append pic or video to media file
        
    }
    
    
    func addAnnotationAtCurrentLocation(fileName: String, type: String, desc: String) {
        // Get the center point of the map view
        let mapCenterPoint = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        
        // Convert the center point to a coordinate
        let centerCoordinate = map.convert(mapCenterPoint, toCoordinateFrom: map)
        
        // Create an annotation with the center coordinate
        let annotation = CustomPointAnnotation()
        annotation.coordinate = centerCoordinate
        if type == "Pic"{
            annotation.title = "Pic"
            annotation.subtitle = fileName
        }else if type == "Video"{
            annotation.title = "Video"
            annotation.subtitle = fileName
        }else{
            annotation.title = "POI"
            annotation.subtitle = desc
        }
        
        
        // Add the annotation to the map view
        //map.addAnnotation(annotation)
        otherAnnotations.append(annotation)
        
        //Append pic or video to media file
        
    }
    
    
    func appendToMediaFile(comment: String, fileName: String, coordinate: CLLocationCoordinate2D, type: String, prjID: String) {
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()
        let mediaFilePath = documentsDirectory.appendingPathComponent("media.csv")
        
        let cleanComment = comment.replacingOccurrences(of: ",", with: "") // Strip commas from the comment
        let csvLine = "\"\(cleanComment)\",\(coordinate.latitude),\(coordinate.longitude),\(fileName),\(type),\(prjID)\n"
        
        if !fileManager.fileExists(atPath: mediaFilePath.path) {
            // If the file doesn't exist, create it and add the header
            let header = "comments,X,Y,fileName,Type,PrjID\n"
            do {
                try header.write(to: mediaFilePath, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to write header to media file: \(error)")
            }
        }
        
        // Append the new line to the existing file
        if let fileHandle = try? FileHandle(forWritingTo: mediaFilePath) {
            fileHandle.seekToEndOfFile()
            if let data = csvLine.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            print("Can't open fileHandle for media file")
        }
    }
    
    
    @objc func handleLongPressOnInsertButton(gesture: UILongPressGestureRecognizer) {
        
        if gesture.state == .began {
                let actionSheet = UIAlertController(title: "Select Media Type", message: "Choose an option", preferredStyle: .actionSheet)
                
                // Option to capture a picture
                let pictureAction = UIAlertAction(title: "Picture", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    let imagePickerController = UIImagePickerController()
                    imagePickerController.delegate = self
                    imagePickerController.sourceType = .camera
                    imagePickerController.mediaTypes = ["public.image"]
                    self.present(imagePickerController, animated: true, completion: nil)
                }
                
                // Option to capture a video
                let videoAction = UIAlertAction(title: "Video", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    let imagePickerController = UIImagePickerController()
                    imagePickerController.delegate = self
                    imagePickerController.sourceType = .camera
                    imagePickerController.mediaTypes = ["public.movie"]
                    imagePickerController.videoQuality = .typeMedium
                    self.present(imagePickerController, animated: true, completion: nil)
                }
                
                // Option to create simple POI
                let generalPOI = UIAlertAction(title: "Comment", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    let alertController = UIAlertController(title: "Add Comments?", message: "Add any extra POI comments?", preferredStyle: .alert)
                    alertController.addTextField { textField in
                        textField.placeholder = "Additional Comments"
                    }
                    
                    let submitAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        if let textField = alertController.textFields?.first, let userInput = textField.text {
                            let mapCenterPoint = CGPoint(x: self.map.bounds.midX, y: self.map.bounds.midY)
                            let currentLocation = self.map.convert(mapCenterPoint, toCoordinateFrom: self.map)
                            
                            self.addAnnotationAtCurrentLocation(fileName: "", type: "POI", desc: userInput)
                            self.appendToMediaFile(comment: userInput, fileName: "", coordinate: currentLocation, type: "TEXT", prjID: "FIXME")
                        }
                    }
                    
                    let cancelAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
                    alertController.addAction(submitAction)
                    alertController.addAction(cancelAction)
                    
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
                
                // Cancel action
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                
                actionSheet.addAction(pictureAction)
                actionSheet.addAction(videoAction)
                actionSheet.addAction(generalPOI)
                actionSheet.addAction(cancelAction)
                
                // For iPad: Set the popoverPresentationController properties
                if let popoverController = actionSheet.popoverPresentationController {
                    popoverController.sourceView = self.view // The view containing the anchor rectangle for the popover.
                    popoverController.sourceRect = CGRect(x: gesture.location(in: self.view).x, y: gesture.location(in: self.view).y, width: 1, height: 1)
                    popoverController.permittedArrowDirections = .any
                }
                
                DispatchQueue.main.async {
                    self.present(actionSheet, animated: true, completion: nil)
                }
            }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            saveImageToDocuments(image: image)
        } else if let videoUrl = info[.mediaURL] as? URL {
            // Handle video URL
            saveVideoToDocuments(videoUrl: videoUrl)
        }
        picker.dismiss(animated: true) {
            
            if self.needPVPairPic{
                //Don't do anything
                self.needPVPairPic = false
            }else{
                let alertController = UIAlertController(title: "Add Comments?", message: "Add any extra POI comments?", preferredStyle: .alert)
                alertController.addTextField { textField in
                    textField.placeholder = "Additional Comments"
                }
                
                let submitAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    
                    // Assuming alertController is not optional and directly accessible
                    if let textField = alertController.textFields?.first, let userInput = textField.text {
                        let mapCenterPoint = CGPoint(x: strongSelf.map.bounds.midX, y: strongSelf.map.bounds.midY)
                        
                        // Convert the center point to a coordinate
                        let currentLocation = strongSelf.map.convert(mapCenterPoint, toCoordinateFrom: strongSelf.map)
                        
                        if self!.recentMediaFile.contains(".jpg"){
                            strongSelf.appendToMediaFile(comment: userInput, fileName: strongSelf.recentMediaFile, coordinate: currentLocation, type: "MEDIA", prjID: "FIXME")
                        }else if self!.recentMediaFile.contains(".mp4"){
                            strongSelf.appendToMediaFile(comment: userInput, fileName: strongSelf.recentMediaFile, coordinate: currentLocation, type: "MEDIA", prjID: "FIXME")
                        }else{
                            strongSelf.appendToMediaFile(comment: userInput, fileName: strongSelf.recentMediaFile, coordinate: currentLocation, type: "TEXT", prjID: "FIXME")
                        }
                        
                        
                    }
                }
                
                
                let cancelAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
                
                alertController.addAction(submitAction)
                alertController.addAction(cancelAction)
                
                // Present the alert controller
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            
            
        }
    }
    
    
    
    func saveImageToDocuments(image: UIImage) {
        
        if inPairMode{
            print("In pair mode")
            saveImageToDocumentsFolder(image, idString: picObjectID)
        }else{
            guard let data = image.jpegData(compressionQuality: 0.01) else { return }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss" // Set timestamp format
            let timestamp = dateFormatter.string(from: Date()) // Get current timestamp
            let filename = "POI_\(timestamp).jpg"
            recentMediaFile = filename
            let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
            
            do {
                try data.write(to: fileURL)
                addAnnotationAtCurrentLocation(fileName: filename, type: "Pic")
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    
    
    func saveVideoToDocuments(videoUrl: URL) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss" // Set timestamp format
        let timestamp = dateFormatter.string(from: Date()) // Get current timestamp
        let filename = "POI_\(timestamp).mp4" // Define the filename for the video
        recentMediaFile = filename
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)

        do {
            // Copy the video file from the source URL to the new location
            try FileManager.default.copyItem(at: videoUrl, to: fileURL)
            addAnnotationAtCurrentLocation(fileName: filename, type: "Video") // Optionally, add an annotation if needed
            print("Video saved successfully: \(fileURL)")
        } catch {
            print("Error saving video: \(error)")
        }
    }
    
    
    func uploadImageToFirebase(localFileURL: URL, imageName: String) {
        // Create a Storage reference
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Create a reference to the file you want to upload
        let imagesRef = storageRef.child("Images/\(imageName)")
        
        // Upload the file to the path "images/imageName"
        let uploadTask = imagesRef.putFile(from: localFileURL, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                self.showMessage(message: "Error uploading image. Please try again.")
                return
            }
            
            // Upload succeeded
            print("Image uploaded to Firebase Storage at path: images/\(imageName)")
            
            // Now update the Return field with the storage path
            let storagePath = "Images/\(imageName)"
            self.updateReturnField(with: storagePath)
        }
        
        // Optional: Monitor upload progress
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            print("Upload is \(percentComplete)% complete")
        }
    }
    //MARK: End Media Functions
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: PoleVAULT PAIRING
    func enterPVPairMode() {
        inPairMode = true
        
        lblInfo.text = "Entering PV Pair Mode... Use PoleVAULT to export item to this map."
        
            // Fetch initial data and draw polyline
            fetchNavigationDataAndDrawPolyline()

            // Optionally set up a timer to ping Firebase every 10 seconds
        navigationTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(fetchNavigationDataAndDrawPolyline), userInfo: nil, repeats: true)
        }
    
    
    
    func exitPVPairMode() {
        inPairMode = false
        
        if let overlay = currentNavOverlay {
            self.map.removeOverlay(overlay)
            currentNavOverlay = nil
        }

        lblInfo.text = "Exited PV Pair Mode..."
        
        // Invalidate the timer to stop Firebase updates
        navigationTimer?.invalidate()
        navigationTimer = nil
        
        btnPVPairAction.isHidden = true
    }
    
    
    
    //Draws a red line on road to given coordinate
    func drawPolyline(to coordinate: CLLocationCoordinate2D) {
            
            let sourceCoordinate = map.userLocation.coordinate
            let destinationCoordinate = coordinate
            
            let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
            
            let directionRequest = MKDirections.Request()
            directionRequest.source = MKMapItem(placemark: sourcePlacemark)
            directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
            directionRequest.transportType = .automobile
            
            let directions = MKDirections(request: directionRequest)
            directions.calculate { (response, error) in
                if let error = error {
                    print("Error calculating directions: \(error)")
                    
                    return
                }
                
                guard let response = response else {
                    print("No response")
                    return
                }
                
                let route = response.routes[0]
                
                // Remove the old route overlay if it exists
                if let currentRouteOverlay = self.currentNavOverlay {
                    self.map.removeOverlay(currentRouteOverlay)
                }
                
                // Add the new route overlay
                self.currentNavOverlay = route.polyline
                self.map.addOverlay(route.polyline)
                //self.map.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    
    
    //Adds a camera object at coordinate
    func addPicAnnotation(at coordinate: CLLocationCoordinate2D, id: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Pic"
        annotation.subtitle = id
        map.addAnnotation(annotation)
        btnPVPairAction.isHidden = false
        btnPVPairAction.setTitle("Take Picture", for: .normal)

    }
    
    
    
    //Adds a QR object at coordinate
    func addQRCodeAnnotation(at coordinate: CLLocationCoordinate2D, id: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "QR"
        annotation.subtitle = id
        map.addAnnotation(annotation)
        btnPVPairAction.isHidden = false
        btnPVPairAction.setTitle("Scan QR Code", for: .normal)

    }
    
    
    
    //Adds a Bar Code object at coordinate
    func addBRCodeAnnotation(at coordinate: CLLocationCoordinate2D, id: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "BarCode"
        annotation.subtitle = id
        map.addAnnotation(annotation)
        btnPVPairAction.isHidden = false
        btnPVPairAction.setTitle("Scan Bar Code", for: .normal)

    }
    

    func getCurrentLocation(){
        
        let latitude = currentLocation!.coordinate.latitude
        let longitude = currentLocation!.coordinate.longitude
            
        // Format the latitude and longitude as a string
        //flipped lat long to work with Wes' PV code
        let latLongString = String(format: "%.6f,%.6f", longitude, latitude)
     
        updateReturnField(with: latLongString)
    }
    
    
    
    // Fetch data from Firebase and draw polyline if ID has changed
    @objc func fetchNavigationDataAndDrawPolyline() {
        
        let ref = self.db.database.reference(withPath: "/Navigation/\(self.getUsername())")
        ref.observeSingleEvent(of: .value) { snapshot,_  in
            guard let value = snapshot.value as? [String: Any] else {
                self.showMessage(message: "No coordinates found. Please use PoleVAULT to select location to get directions for.")
                return
            }
            if let x = value["X"] as? Double, let y = value["Y"] as? Double, let id = value["ID"] as? String{
                if id == self.pvPairID {
                    //Do nothing, ID hasn't changed
                }else{
                    
                    self.pvPairID = id
                    //Clear the return value in anticiaption of new return data
                    ref.child("Return").setValue(nil) { error, _ in
                            if let error = error {
                                // Handle the error
                                print("Error clearing Return field: \(error.localizedDescription)")
                                self.writeToLogFile(message: "Error clearing Return field: \(error.localizedDescription)")
                            } else {
                                // Success
                                print("Successfully cleared Return field.")
                                self.writeToLogFile(message: "Successfully cleared Return field.")
                            }
                        }
                    
                    
                    let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
                    
                    if id.starts(with: "PIC"){
                        self.picObjectID = id.replacingOccurrences(of: "PIC", with: "")
                        self.addPicAnnotation(at: coordinate, id: id)
                        self.drawPolyline(to: coordinate)
                        self.lblInfo.text = "PV requesting picture at location..."
                        
                    }else if id.starts(with: "MAPFRBASE"){
                        //Go to zip file location and download map
                        let url = id.replacingOccurrences(of: "MAPFRBASE:", with: "")
                        self.downloadFileFromFB(location: url)
                        self.lblInfo.text = "Downloading map data from Firebase..."
                        
                    }else if id.starts(with: "QRC"){
                        self.picObjectID = id.replacingOccurrences(of: "QRC", with: "")
                        self.addQRCodeAnnotation(at: coordinate, id: id)
                        self.drawPolyline(to: coordinate)
                        self.lblInfo.text = "PV requesting QR Code scanned at location..."
                    }
                    
                    else if id.starts(with: "BRC"){
                        self.picObjectID = id.replacingOccurrences(of: "BRC", with: "")
                        self.addBRCodeAnnotation(at: coordinate, id: id)
                        self.drawPolyline(to: coordinate)
                        self.lblInfo.text = "PV requesting Bar Code scanned at location..."
                        
                    }
                    
                    else if id.starts(with: "LOC"){
                        self.calculateDistanceAndETA(to: coordinate)
                        self.drawPolyline(to: coordinate)
                        self.lblInfo.text = "PV sent directions to location..."
                    }
                    
                    else if id.starts(with: "GPS"){
                        self.getCurrentLocation()
                        self.lblInfo.text = "PV requesting current location..."
                    }
                    
                    else if id.starts(with: "BYE"){
                        //Exit PV Mode
                        self.updateReturnField(with: "ADIOS")
                        self.exitPVPairMode()
                        //Unlock all buttons
                        let buttons = [self.btnCrosshair, self.btnBaseMap, self.btnDirections, self.btnImport, self.btnExport, self.btnSettings, self.btnInsert, self.btnDrawWiring, self.btnRemove, self.btnRevert]
                        
                        for button in buttons {
                            button?.isEnabled = true
                            button?.isHidden = false
                        }
                        
                        self.btnPairPV.isOn = false
                    }
                    
                    else{
                        self.drawPolyline(to: coordinate)
                    }
                    
                    
                    //self.openInAppleMaps(coordinate: coordinate, placeName: "PoleVAULT Location")
                }
                
            }
        }
    }
    
    
    func updateReturnField(with value: String) {
        // Get a reference to the database path "/Navigation/username"
        let userPath = "/Navigation/\(getUsername())"
        let ref = db.database.reference(withPath: userPath)
        
        // Set the value for the field "Return" to the given value
        ref.child("Return").setValue(value) { error, _ in
            if let error = error {
                // Handle the error
                print("Error updating Return field: \(error.localizedDescription)")
                self.writeToLogFile(message: "Error updating Return field: \(error.localizedDescription)")
            } else {
                // Success
                print("Successfully updated Return field with value: \(value)")
                self.writeToLogFile(message: "Successfully updated Return field with value: \(value)")
            }
        }
    }
    
    
    @objc func togglePVMode(){
        if btnPairPV.isOn{
            enterPVPairMode()
            //Lock all buttons besides Nav
            let buttons = [btnCrosshair, btnDirections, btnImport, btnExport, btnSettings, btnInsert, btnDrawWiring, btnRemove, btnRevert]
            
            for button in buttons {
                button?.isEnabled = false
                button?.isHidden = true
            }
        }else{
            exitPVPairMode()
            //Unlock all buttons
            let buttons = [btnCrosshair, btnBaseMap, btnDirections, btnImport, btnExport, btnSettings, btnInsert, btnDrawWiring, btnRemove, btnRevert]
            
            for button in buttons {
                button?.isEnabled = true
                button?.isHidden = false
            }
        }
        
    }
    
    enum ScanningMode {
        case qrCode
        case barCode
    }
    //MARK: End PoleVAULT Pairing
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: LOG FILE OPERATIONS
    // Function to reset the log file
    func resetLogFile() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let logFileURL = urls[0].appendingPathComponent("log.txt")
        
        // Wipe the file
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
    
    
    
    // Function to write to the log file
    func writeToLogFile(message: String) {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let logFileURL = urls[0].appendingPathComponent("log.txt")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logMessage = "\(timestamp): \(message)\n"
        
        // Append the message to the log file
        if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            // If the file does not exist, create it and then write the message
            try? logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    
    
    // Function to check and reset the log file if needed
    func checkAndResetLogFile() {
        let userDefaults = UserDefaults.standard
        let currentDate = Date()
        
        // Check if the initial date is stored in User Defaults
        if let storedDate = userDefaults.object(forKey: "LogFileDate") as? Date {
            // Calculate the difference in days between the current date and the stored date
            
            let calendar = Calendar.current
            if let daysDifference = calendar.dateComponents([.day], from: storedDate, to: currentDate).day, daysDifference >= 7 {
                // If the difference is at least a week (7 days), reset the log file
                resetLogFile()
                // Update the stored date to the current date
                userDefaults.set(currentDate, forKey: "LogFileDate")
            }
        } else {
            // If no date is stored, set the initial date to the current date
            userDefaults.set(currentDate, forKey: "LogFileDate")
        }
    }
    //MARK: END LOG FILE OPERATIONS
    //--------------------------
    //--------------------------
    //--------------------------
    //--------------------------
    //MARK: MISC FUNCTIONS
    //Return poles clicked for the day (√)
    func getPolesCounted() -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        //Check if the current date is present in VSUMInfo for each pole
        return poles.reduce(0) { $0 + ($1.VSUMInfo.contains(dateFormatter.string(from: Date())) ? 1 : 0) }
    }
    

    
    //Takes a comma delimited string and returns the String array. Ignores commas inside ""s (√)
    func splitCommaDelimitedString(_ str: String) -> [String] {
            var result = [String]()
            var current = ""
            var insideQuotes = false
            
            for char in str {
                if char == "\"" {
                    insideQuotes.toggle()
                } else if char == "," && !insideQuotes {
                    result.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            
            // Append the last element
            result.append(current)
            
            // Trim whitespaces and quotes from each element
            result = result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            
            return result
    }
    
    
    
    //Shows a Pop Up Message (√)
    func showMessage(message: String) {
        DispatchQueue.main.async {
            if let topController = self.topViewController() {
                let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                topController.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    
    
    //Returns the top most ViewController. Used with showMessage to ensure message appears to user 'on top' of everything (√)
    func topViewController(_ base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })?
        .windows
        .first(where: { $0.isKeyWindow })?.rootViewController) -> UIViewController? {
            if let nav = base as? UINavigationController {
                return topViewController(nav.visibleViewController)
            }
            if let tab = base as? UITabBarController {
                if let selected = tab.selectedViewController {
                    return topViewController(selected)
                }
            }
            if let presented = base?.presentedViewController {
                return topViewController(presented)
            }
            return base
        }
    
    
    
    //Gives Buttons a Blurred Effect (√)
    func setButtonApperance(button: UIButton){
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurEffectView.layer.cornerRadius = 20
        blurEffectView.clipsToBounds = true
        
        button.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(blurEffectView)
        blurEffectView.contentView.addSubview(button)
        
        NSLayoutConstraint.activate([
            blurEffectView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: button.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            button.centerXAnchor.constraint(equalTo: blurEffectView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: blurEffectView.centerYAnchor)
        ])
    }
    
    
    
    //Returns whether a String only Contains Letters (√)
    func containsOnlyLetters(string: String) -> Bool {
        return string.range(of: "[^a-zA-Z]", options: .regularExpression) == nil
    }
    
    
    
    //Create and cache a circle symbol based on color (√)
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
    
    
    
    //Create and cache a circle symbol based on color (√)
    func circleImage(for color: UIColor, size: Int) -> UIImage {
        
        if let cachedImage = circleImageCache[color] {
            return cachedImage
        }
        
        let circleSize = CGSize(width: size, height: size)
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
    
    
    
    //Create Uniform Label Appearances (UILabels) (√)
    func initializeLabels() {
        let labels = [lblInfo, lblPoleCount]
        for label in labels {
            label?.backgroundColor = label?.backgroundColor?.withAlphaComponent(0.7)
            label?.layer.cornerRadius = 10
        }
    }
    
    
    
    //Used on startup to set gesture recognizers (√)
    func initializeGestureRecgonizers(){
        let recogPoleMove = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        map.addGestureRecognizer(recogPoleMove)
        
        //let recogDrawWiringTap = UITapGestureRecognizer(target: self, action: #selector(handleDrawWiringTap(_:)))
        //map.addGestureRecognizer(recogDrawWiringTap)
        
        btnDrawWiring.addTarget(self, action: #selector(toggleDrawingMode), for: .touchUpInside)
        
        btnPairPV.addTarget(self, action: #selector(togglePVMode), for: .touchUpInside)
    }
    
    
    
    //Used on startup to create the red border that displays when items are in a moving state (√)
    func initializeRedBorder(){
        redBorderView = RedBorderView(frame: map.bounds)
        redBorderView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        redBorderView!.backgroundColor = .clear
        redBorderView?.isUserInteractionEnabled = false
        map.addSubview(redBorderView!)
        redBorderView?.isHidden = true
    }
    
    
    
    //Show description of UIButtons on long press (√)
    @objc func handleLongPressOnButton(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            feedbackGenerator.impactOccurred()
            if let button = gesture.view as? UIButton {
                let message = getButtonMessage(for: button)
                showMessage(message: message)
            }
        }
    }
    
    
    
    //Single out long press on draw wiring button (need draw wiring to remove all wiring) (√) TODO: Incorprate removing of wiring with delete button?
    func addButtonLongPressGesture(to button: UIButton) {
        if button == btnDrawWiring{
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnDrawButton(gesture:)))
            button.addGestureRecognizer(longPressGesture)
        }else if button == btnInsert{
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnInsertButton(gesture:)))
            button.addGestureRecognizer(longPressGesture)
            
        }else{
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnButton))
            button.addGestureRecognizer(longPressGesture)
        }
    }
    

    
    //Removes all drawn secondary from map (√)
    @objc func handleLongPressOnDrawButton(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            feedbackGenerator.impactOccurred()
            let overlays = map.overlays.filter { $0 is MKPolyline && $0.title == "UserSecondary"}
            map.removeOverlays(overlays)
        }
    }
    
    
    
    //Return description for each button's purpose (√)
    func getButtonMessage(for button: UIButton) -> String {
        let messages: [UIButton: String] = [
            btnCrosshair: "Shows a red crosshair at the center of the map. Useful for inserts.",
            btnCenter: "Centers the map on the User's location. The map will update with the User's movement.",
            btnBaseMap: "Switches between different map types.",
            btnDirections: "Shows a line indicating the driving directions to the closest unchecked pole. If this option is on and the User taps a pole, it will then give directions to the next closest pole.",
            btnImport: "Gives the User the option to import data from a file or to scan a QR code.",
            btnExport: "Gives the User the option to export poles data to the Cloud or to a QR code.",
            btnSettings: "Lets the User change certain settings for layers and the app.",
            btnZoomIn: "Zooms closer to the map.",
            btnZoomOut: "Zooms away from the map.",
            btnRotate: "Rotates the map a certain degree.",
            btnInsert: "Inserts an Insert pole onto the map.",
            btnRemove: "Removes a pole from the map",
            btnRevert: "Restore last used data.",
            btnPairPV: "Looks for location selected in PoleVAULT and will provide directions to point on this map."
        ]
        
        return messages[button] ?? "Button..."
    }
    
    
    
    //Returns a new line delimited string based on commas (think csv) TODO: Make this work with
    func createStackedText(from commaSeparatedString: String) -> String {
        //        return commaSeparatedString.components(separatedBy: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
        //Turning this off temporarily to test using a premark base layer instead TODO: Turn back on eventually

        return commaSeparatedString.components(separatedBy: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
    }
    
    
    
    //Resizes a given image
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
        
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }
        
        return scaledImage
    }
    
    
    
    //Returns the FireBase Export zip file export name using location.txt info
    func getFirebaseExportName() -> String{
        
        let workAreaName = UserDefaults.standard.string(forKey: "WorkAreaName") ?? "ERROR"
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("\(workAreaName)/location.txt")
        
        do {
            let content = try String(contentsOf: filePath, encoding: .utf8)
            if let parsedData = parseText(from: content) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMddHHmmss" // Set timestamp format
                let timestamp = dateFormatter.string(from: Date()) // Get current timestamp
                
                let outputString = "\(parsedData.username)-\(parsedData.projectID)-\(parsedData.workArea)-\(originalTimestamp)_Complete_\(timestamp)"
                return outputString
            } else {
                print("Failed to parse the content")
                return ""
            }
        } catch {
            print("Failed to read from file at \(filePath): \(error)")
            return ""
        }
    }
    
    
    
    func parseText(from content: String) -> (username: String, projectID: String, workArea: String)? {
        let components = content.split(separator: "|").map(String.init)
        
        guard let workArea = components.first(where: { !$0.contains(":") }),
              let projectPart = components.first(where: { $0.contains("PRJ:") }) else {
            print("Data is not in the expected format")
            return nil
        }
        
        let projectID = String(projectPart.split(separator: ":")[1])
        
        
        return (self.getUsername(), projectID, workArea)
    }
    
    

    @objc func toggleDrawingMode() {
        isDrawingModeEnabled = !isDrawingModeEnabled
        
        if isDrawingModeEnabled {
            // Resetting for a new drawing session
            currentCoordinates.removeAll()
            currentWirePolyline?.removeFromMap(map)
            currentWirePolyline = nil
            
            // Immediately capture the initial center coordinate using the visual center of the mapView
            let initialCenterPoint = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
            let initialCenterCoordinate = map.convert(initialCenterPoint, toCoordinateFrom: map)
            currentCoordinates.append(initialCenterCoordinate)
        } else {
            // Create a polyline from accumulated coordinates and add it to the map
            if !currentCoordinates.isEmpty {
                currentWirePolyline = MKPolyline(coordinates: currentCoordinates, count: currentCoordinates.count)
                currentWirePolyline?.title = "UserSecondary"
                map.addOverlay(currentWirePolyline!)
            }
        }
        
    }
    
    
    
    private func updateWirePolyline() {
        if let polyline = currentWirePolyline {
            map.removeOverlay(polyline)
        }
        currentWirePolyline = MKPolyline(coordinates: currentCoordinates, count: currentCoordinates.count)
        currentWirePolyline?.title = "UserSecondary"
        map.addOverlay(currentWirePolyline!)
    }
    
    

    func saveImageToDocumentsFolder(_ image: UIImage, idString: String) {
        // Get the documents directory URL
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get documents directory")
            return
        }
        
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
        var fileURL = documentsDirectory.appendingPathComponent(filename)
        
        //Check if WA is loaded
//        if ((UserDefaults.standard.string(forKey: "WorkAreaName")?.isEmpty) != nil){
//            fileURL = documentsDirectory.appendingPathComponent("\(UserDefaults.standard.string(forKey: "WorkAreaName") ?? "")/\(idString)-\(currentDateString)-\(String(format: "%03d%", counter)).jpg")
//        }
        
        
        do {
            // Convert the image to JPEG data and write it to the file URL
            if let jpegData = image.jpegData(compressionQuality: 0.01) {
                try jpegData.write(to: fileURL)
                showMessage(message: "Save imaged.")
                if needPVPairPic{
                    uploadImageToFirebase(localFileURL: fileURL, imageName: filename)
                }
                
            } else {
                showMessage(message: "Unable to save image. Please try again.")
            }
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }
    }
    

    
    // Delegate method to handle the selected URL
    func fileListViewController(_ controller: FirebaseStorageWorkAreasVC, didSelectFileWithURL url: URL) {
        // Now you can open or use the selected URL, e.g., downloading a file or displaying it
        handleFileDownload(from: url)
    }
        
    
    
    func handleFileDownload(from url: URL) {
        
        self.writeToLogFile(message: "Attempting to load from URL: \(url)")

        // Sign in to Firebase if needed
        Auth.auth().signIn(withEmail: self.email, password: self.password) { authResult, error in
            if let error = error {
                print("Authentication error while attempting to load from URL: \(error.localizedDescription)")
                self.writeToLogFile(message: "Authentication error while attempting to load from URL: \(error.localizedDescription)")
                return
            }
            
            print("Firebase Login Successful...")
            self.writeToLogFile(message: "Logged in to Firebase...")
            
            // Extract the path relative to Firebase Storage from the full URL
            let fullURLString = url.absoluteString
            
            // Assuming the URL is something like 'https://firebasestorage.googleapis.com/v0/b/[bucket]/o/[path]'
            if let range = fullURLString.range(of: "/o/") {
                // Extract the Firebase Storage path from the URL (removing query parameters)
                        let filePath = url.pathComponents.dropFirst(3).joined(separator: "/") // Skip first 3 parts (scheme, host, bucket)
                        
                        // Remove any query parameters (like alt=media&token=...)
                        var cleanFilePath = filePath.components(separatedBy: "?").first ?? filePath
                        
                cleanFilePath = cleanFilePath.replacingOccurrences(of: "vsumtimesheet.appspot.com/o/", with: "")
                
                        // Create a reference to Firebase Storage using the correct path
                        let storageRef = Storage.storage().reference().child(cleanFilePath)
                        
                        let maxSize: Int64 = 10 * 1024 * 1024  // Max size: 10MB
                
                // Download the zip file data
                storageRef.getData(maxSize: maxSize) { data, error in
                    guard let data = data else {
                        print("Error downloading zip file: \(String(describing: error))")
                        return
                    }
                    
                    // Get the URL for the Documents directory in the app's sandbox
                    guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("Failed to locate the document directory")
                        return
                    }
                    
                    // Save original file name (used for export later)
                    self.storageFileName = url.deletingPathExtension().lastPathComponent
                    
                    // Figure out WA name from file path
                    let components = self.storageFileName.components(separatedBy: "-")
                    if components.count >= 3 {
                        self.waName = components[2] // This will include ".zip"
                        UserDefaults.standard.set(self.waName, forKey: "WorkAreaName") // Save WA Name to settings
                        let fileName: String = "\(components[0])\(components[1])\(components[2])"
                        UserDefaults.standard.set(fileName, forKey: "StorageFileName") // Save Original Zip File name to settings
                    }
                    
                    // Create a destination URL for the zip file and the folder to contain the unzipped files
                    let fileURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/downloadedFile.zip")
                    let folderURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/")
                    
                    // Ensure the folder exists before trying to write to it
                    if FileManager.default.fileExists(atPath: folderURL.path) {
                        // Present an alert to ask the user if they want to overwrite the existing files
                        let alertController = UIAlertController(title: "Overwrite Files?", message: "Data for \(self.waName) already exists. Do you want to overwrite the older data?", preferredStyle: .alert)
                        let overwriteAction = UIAlertAction(title: "Overwrite", style: .destructive) { _ in
                            self.handleFileOverwrite(folderURL: folderURL, fileURL: fileURL, data: data)
                        }
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                        
                        alertController.addAction(overwriteAction)
                        alertController.addAction(cancelAction)
                        
                        DispatchQueue.main.async {
                            self.present(alertController, animated: true)
                        }
                    } else {
                        do {
                            // Create the folder if it does not exist
                            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                            self.saveAndUnzipData(data: data, fileURL: fileURL, folderURL: folderURL)
                        } catch {
                            print("Error creating folder: \(error)")
                        }
                    }
                }
            } else {
                print("Invalid URL structure. Could not extract Firebase path.")
            }
        }
    }
    
    
    
    func downloadFileFromFB(location: String){
        self.writeToLogFile(message: "Attempting to load from URL: \(location)")

        // Sign in to Firebase if needed
        Auth.auth().signIn(withEmail: self.email, password: self.password) { authResult, error in
            if let error = error {
                print("Authentication error while attempting to load from URL: \(error.localizedDescription)")
                self.writeToLogFile(message: "Authentication error while attempting to load from URL: \(error.localizedDescription)")
                return
            }
            
            print("Firebase Login Successful...")
            self.writeToLogFile(message: "Logged in to Firebase...")
            
            


                        
        
                
                        // Create a reference to Firebase Storage using the correct path
                        let storageRef = Storage.storage().reference().child(location)
                        
                        let maxSize: Int64 = 10 * 1024 * 1024  // Max size: 10MB
                
                // Download the zip file data
                storageRef.getData(maxSize: maxSize) { data, error in
                    guard let data = data else {
                        print("Error downloading zip file: \(String(describing: error))")
                        return
                    }
                    
                    // Get the URL for the Documents directory in the app's sandbox
                    guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("Failed to locate the document directory")
                        return
                    }
                    
                    // Save original file name (used for export later)
                    self.storageFileName = location.replacingOccurrences(of: ".zip", with: "")
                    
                    // Figure out WA name from file path
                    let components = self.storageFileName.components(separatedBy: "-")
                    if components.count >= 3 {
                        self.waName = components[2] // This will include ".zip"
                        UserDefaults.standard.set(self.waName, forKey: "WorkAreaName") // Save WA Name to settings
                        let fileName: String = "\(components[0])\(components[1])\(components[2])"
                        UserDefaults.standard.set(fileName, forKey: "StorageFileName") // Save Original Zip File name to settings
                    }
                    
                    // Create a destination URL for the zip file and the folder to contain the unzipped files
                    let fileURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/downloadedFile.zip")
                    let folderURL = documentsDirectoryURL.appendingPathComponent("\(self.waName)/")
                    
                    // Ensure the folder exists before trying to write to it
                    if FileManager.default.fileExists(atPath: folderURL.path) {
                        // Present an alert to ask the user if they want to overwrite the existing files
                        let alertController = UIAlertController(title: "Overwrite Files?", message: "Data for \(self.waName) already exists. Do you want to overwrite the older data?", preferredStyle: .alert)
                        let overwriteAction = UIAlertAction(title: "Overwrite", style: .destructive) { _ in
                            self.handleFileOverwrite(folderURL: folderURL, fileURL: fileURL, data: data)
                        }
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                        
                        alertController.addAction(overwriteAction)
                        alertController.addAction(cancelAction)
                        
                        DispatchQueue.main.async {
                            self.present(alertController, animated: true)
                        }
                    } else {
                        do {
                            // Create the folder if it does not exist
                            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                            self.saveAndUnzipData(data: data, fileURL: fileURL, folderURL: folderURL)
                        } catch {
                            print("Error creating folder: \(error)")
                        }
                    }
                }
        }
    }

    
    
    //Launch Apple Maps with nav details to a passed coordinate
    func openInAppleMaps(coordinate: CLLocationCoordinate2D, placeName: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = placeName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    
    
    //Attempt to sign in to Firebase to allow for DB/Storage operations
    func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        self.writeToLogFile(message: "Attempting to sign in to Firebase...")
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.writeToLogFile(message: "Unable to log in to Firebase: Error: \(error.localizedDescription)")
                completion(false, error)
            } else {
                self.writeToLogFile(message: "Successfully signed in to Firebase.")
                completion(true, nil)
            }
        }
    }
    
    
    func calculateDistanceAndETA(to destinationCoordinate: CLLocationCoordinate2D) {
        guard let userLocation = currentLocation else {
            print("User location is not available.")
            return
        }
        
        // Create map items for source and destination
        let sourcePlacemark = MKPlacemark(coordinate: userLocation.coordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        // Create a directions request
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destinationMapItem
        directionsRequest.transportType = .automobile // You can choose .walking, .transit, etc.
        
        let directions = MKDirections(request: directionsRequest)
        
        directions.calculate { (response, error) in
            if let error = error {
                print("Error calculating directions: \(error.localizedDescription)")
                return
            }
            
            guard let response = response, let route = response.routes.first else {
                print("No routes found.")
                return
            }
            
            // Get distance in meters and ETA in seconds
            let distanceMeters = route.distance
            let etaSeconds = route.expectedTravelTime
            
            // Convert distance to miles
            let distanceMiles = distanceMeters / 1609.34 // 1 mile = 1609.34 meters
            
            // Format ETA into hours and minutes
            let etaFormatted = self.formatTimeInterval(etaSeconds)
            
            // Prepare the string to update the Return field
            let returnValue = "Distance: \(String(format: "%.2f", distanceMiles)) miles, ETA: \(etaFormatted)"
            print(returnValue)
            
            // Update the Return field
            self.updateReturnField(with: returnValue)
        }
    }
    
    func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let ti = NSInteger(timeInterval)
        let hours = ti / 3600
        let minutes = (ti % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    
    @IBAction func btnTestTap2(_ sender: Any) {
    }
    //MARK: END MISC FUNCTIONS
}



//Extension to allow coorindates for a polyline
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
    func removeFromMap(_ mapView: MKMapView) {
        mapView.removeOverlay(self)
    }
    
}

//Structure to store annotations and their MKMapPoints for quick lookup
struct AnnotationData {
    let annotation: MKAnnotation
    let mapPoint: MKMapPoint
}




//Code for reading .txt files:
//stringArr.removeFirst() // Remove X,Y column
//
////Test which file has been selected:
//if selectedFileURL.lastPathComponent == "Primary.txt"{
//    var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
//    
//    for line in stringArr {
//        if !line.isEmpty {
//            let components = line.components(separatedBy: ",")
//            if components.count == 4,
//               let objectID = Int(components[0]),
//               let index = Int(components[1]),
//               let x = Double(components[2]),
//               let y = Double(components[3]) {
//                
//                let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
//                if var coordinates = tempPolylineCoordinatesDict[objectID] {
//                    // Insert the coordinate at the correct index
//                    while coordinates.count <= index {
//                        coordinates.append(CLLocationCoordinate2D())
//                    }
//                    coordinates[index] = coordinate
//                    tempPolylineCoordinatesDict[objectID] = coordinates
//                } else {
//                    tempPolylineCoordinatesDict[objectID] = [coordinate]
//                }
//            }
//        }
//    }
//    
//    // Create MKPolyline objects for each set of coordinates and store them in the dictionary
//    for (objectID, coordinates) in tempPolylineCoordinatesDict {
//        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
//        polylineDict[objectID] = polyline
//        polylineDict[objectID]?.title = "Primary"
//    }
//    
//}else if selectedFileURL.lastPathComponent == "Secondary.txt"{
//    
//    
//    //ATTEMPTING MULTIPOLYLINE HERE
//    var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
//    
//    
//    for line in stringArr {
//        if !line.isEmpty {
//            let components = line.components(separatedBy: ",")
//            if components.count == 4,
//               let objectID = Int(components[0]),
//               let index = Int(components[1]),
//               let x = Double(components[2]),
//               let y = Double(components[3]) {
//                
//                let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
//                if var coordinates = tempPolylineCoordinatesDict[objectID] {
//                    // Insert the coordinate at the correct index
//                    coordinates.insert(coordinate, at: index)
//                    tempPolylineCoordinatesDict[objectID] = coordinates
//                } else {
//                    tempPolylineCoordinatesDict[objectID] = [coordinate]
//                }
//            }
//        }
//    }
//    
//    // Create MKPolyline objects for each set of coordinates and store them in the dictionary
//    for (objectID, coordinates) in tempPolylineCoordinatesDict {
//        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
//        polyline.title = "Secondary"
//        
//        if let existingMultiPolyline = multiPolylineDict[objectID] {
//            let updatedPolylines = existingMultiPolyline.polylines + [polyline]
//            multiPolylineDict[objectID] = MKMultiPolyline(updatedPolylines)
//        } else {
//            let multiPolyline = MKMultiPolyline([polyline])
//            multiPolylineDict[objectID] = multiPolyline
//        }
//    }
//    
//    
//    
//    
//    
//    
//}
//
//
//
//
//else if selectedFileURL.lastPathComponent == "WorkArea.txt"{
//    var tempPolylineCoordinatesDict: [Int: [CLLocationCoordinate2D]] = [:]
//    
//    for line in stringArr {
//        if !line.isEmpty {
//            let components = line.components(separatedBy: ",")
//            if components.count == 4,
//               let objectID = Int(components[0]),
//               let index = Int(components[1]),
//               let x = Double(components[2]),
//               let y = Double(components[3]) {
//                
//                let coordinate = CLLocationCoordinate2D(latitude: y, longitude: x)
//                if var coordinates = tempPolylineCoordinatesDict[objectID] {
//                    // Insert the coordinate at the correct index
//                    while coordinates.count <= index {
//                        coordinates.append(CLLocationCoordinate2D())
//                    }
//                    coordinates[index] = coordinate
//                    tempPolylineCoordinatesDict[objectID] = coordinates
//                } else {
//                    tempPolylineCoordinatesDict[objectID] = [coordinate]
//                }
//            }
//        }
//    }
//    
//    // Create MKPolyline objects for each set of coordinates and store them in the dictionary
//    for (objectID, coordinates) in tempPolylineCoordinatesDict {
//        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
//        polylineDict[objectID] = polyline
//        polylineDict[objectID]?.title = "WorkArea"
//    }
//    
//}
//
//
//
//
//
//else if selectedFileURL.lastPathComponent == "Reference.txt" || selectedFileURL.lastPathComponent == "Transformer.txt"{
//    for point in stringArr {
//        guard !point.isEmpty else { continue }
//        let tempData = splitCommaDelimitedString(point)
//        
//        if let lat = Double(tempData[1]), let long = Double(tempData[0]) {
//            
//            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
//            let annotation = CustomPointAnnotation()
//            annotation.coordinate = coordinate
//            annotation.title = "Other"
//            
//            switch selectedFileURL.lastPathComponent {
//            case "Reference.txt":
//                if tempData.count > 2 && tempData[2] == "Light" {
//                    annotation.subtitle = "Light"
//                } else {
//                    annotation.subtitle = "Reference"
//                }
//                
//            case "Transformer.txt":
//                annotation.subtitle = "Transformer"
//            default:
//                annotation.subtitle = "Other"
//            }
//            
//            otherAnnotations.append(annotation)
//        }
//        
//    }
//}
//
//lblInfo.text = "Object(s) mapped..."
