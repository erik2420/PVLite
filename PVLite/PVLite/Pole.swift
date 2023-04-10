//
//  Pole.swift
//  PVLite
//
//  Created by Erik Taylor on 3/7/23.
//  Class will hold data for a pole including:
//  X,Y,comments,poledata,suppdata,VSUMInfo,SRCID,SRCOWN
//  This data is originally in the following format:
//  0 = Long | 1 = Lat | 2 = comments | 3 = poledata | 4 = suppdata | 5 = VSUMInfo | 6 = SRCID | 7 = SRCOWN
//


import Foundation

class Pole {
    //Defaults
    //Attribs
    var X: Double = 0.0
    var Y: Double = 0.0
    var comments: String = ""
    var poledata: String = ""
    var suppdata: String = ""
    var VSUMInfo: String = ""
    var SRCID: String = ""
    var SRCOWN: String = ""

    //View comments at top of code to see string array structure
    func setData(strArr: [String]){
        //Set all vars for the pole and remove any " in the string
        self.X = Double(strArr[0]) ?? -80.647998 //Set as office if error
        self.Y = Double(strArr[1]) ?? 35.326920 //Set as office if error
        self.comments = strArr[2].replacingOccurrences(of: "\"", with: "")
        self.poledata = strArr[3].replacingOccurrences(of: "\"", with: "")
        self.suppdata = strArr[4].replacingOccurrences(of: "\"", with: "")
        self.VSUMInfo = strArr[5].replacingOccurrences(of: "\"", with: "")
        self.SRCID = strArr[6].replacingOccurrences(of: "\"", with: "")  //Will be used as unique identifier
        self.SRCOWN = strArr[7].replacingOccurrences(of: "\"", with: "")
    }
    
    func toExportString() -> String{
        
        //Create the return string for the pole
        let poleStr = "\(self.X),\(self.Y),\"\(comments)\",\"\(poledata)\",\"\(suppdata)\",\"\(VSUMInfo)\",\"\(SRCID)\",\"\(SRCOWN)\""
        return poleStr
        
    }
    
    
}

