//
//  UIViewController.swift
//  MyStats
//
//  Created by Amrinder Gill on 6/28/20.
//  Copyright © 2020 Amrinder Gill. All rights reserved.
//

import Foundation
class ViewController: UIViewController {
var employeeArray:[Dictionary<String, AnyObject>] =  Array()
   
   override func viewDidLoad() {
       super.viewDidLoad()
        for i in 1...10 {
                  var dct = Dictionary<String, AnyObject>()
                  dct.updateValue(i as AnyObject, forKey: "EmpID")
                  dct.updateValue("NameForEmplyee id = \(i)" as AnyObject, forKey: "EmpName")
                  employeeArray.append(dct)
              }

              createCSV(from: employeeArray)

   }

func createCSV(from recArray:[Dictionary<String, AnyObject>]) {
       var csvString = "\("Employee ID"),\("Employee Name")\n\n"
       for dct in recArray {
           csvString = csvString.appending("\(String(describing: dct["EmpID"]!)) ,\(String(describing: dct["EmpName"]!))\n")
       }
       
       let fileManager = FileManager.default
       do {
           let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
           let fileURL = path.appendingPathComponent("CSVRec.csv")
           try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
       } catch {
           print("error creating file")
       }

   }
}
