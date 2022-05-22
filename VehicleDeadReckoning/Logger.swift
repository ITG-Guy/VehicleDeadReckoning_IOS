//
//  Logger.swift
//  VehicleDeadReckoning
//
//  Created by Jason Kim on 2022/05/22.
//

import Foundation

class Logger {
    
    // For looging variable
    let fileManager = FileManager.default
    var fileURL: URL? = nil
    var logContents : String?
    var loggingFile: String?
    var loggingUTC: String?
    var logpath : String?
    var outputStream : OutputStream?
    
    func startLog(){
        // For logging
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy,MM,dd,HH,mm,ss"
        
        let hourMinSecond = dateFormatter.string(from: Date())
        let hourMinSecondList = hourMinSecond.components(separatedBy: ",")
        loggingUTC = "\(hourMinSecondList[0])_\(hourMinSecondList[1])_\(hourMinSecondList[2])_\(hourMinSecondList[3])_\(hourMinSecondList[4])_\(hourMinSecondList[5])"
        logContents = ""
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in : .userDomainMask)[0]
        fileURL = documentsURL.appendingPathComponent("\(loggingUTC!).txt")
        logpath = fileURL?.path
        outputStream = OutputStream(toFileAtPath: logpath!, append: true)
        outputStream?.open()
    }
    
    func log_print(log:String){
        self.outputStream!.write(log, maxLength: log.count)
    }
    
    func closeLog(){
        outputStream?.close()
    }
    
    //    func loggingAccGyro(){
    //        //lock.lock(); defer {lock.unlock()}
    //        let accCnt = memsState.accArray.count
    //        let gyroCnt = memsState.gyroArray.count
    //
    //        for i in 0...accCnt-1{
    //            let timeStamp = memsState?.accArray[4 * i]
    //            let accX = memsState?.accArray[4 * i + 1]
    //            let accY = memsState?.accArray[4 * i + 2]
    //            let accZ = memsState?.accArray[4 * i + 3]
    //            //let accLog = String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000)
    //            //logContents = logContents! + "27,0," +  accLog + "\n"
    //
    ////            outputStream!.write(accLog,maxLength: accLog.count)
    //
    ////            log_print(log: String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000))
    //        }
    //
    //        for i in 0...gyroCnt-1{
    //            let timeStamp = memsState?.gyroArray[ 4 * i]
    //            let gyroX = memsState?.gyroArray[ 4 * i + 1]
    //            let gyroY = memsState?.gyroArray[ 4 * i + 2]
    //            let gyroZ = memsState?.gyroArray[ 4 * i + 3]
    //            //let gyroLog = String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ)
    //            //logContents = logContents! + "27,1," +  gyroLog + "\n"
    //            //outputStream!.write(gyroLog,maxLength: gyroLog.count)
    ////            log_print(log: String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ))
    //        }
    //    }
}
