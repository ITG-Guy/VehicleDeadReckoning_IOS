//
//  memsState.swift
//  VehicleDeadReckoning
//
//  Created by Jason Kim on 2022/05/21.
//

import Foundation


let r2d = 180 / Double.pi
let d2r = Double.pi / 180


class MemsState{
    
 
    enum STATIC_STATUS: Int {
        case INIT = 0
        case STATIC = 1
        case DYNAMIC = 2
        case DYNAMIC_AFTER_STATIC = 3
    }
    
    struct accXYZ{
        var xyz : [Double] = [0,0,0]
        var timeStamp : Double
    }
    
    struct gyroXYZ{
        var xyz : [Double] = [0,0,0]
        var timeStamp : Double
    }
    
    // 1) Sensor Data
    let lock = NSLock() // when access to accArray and gyroArray, Locked is needed.
    var accArray : Array<accXYZ> = []
    var accCnt : Int = 0
    var accAvgDouble : [Double] = [0,0,0]
    var accVarDouble : [Double] = [0,0,0]
    var accBiasDouble: [Double] = [0,0,0]
    
    var gyroArray : Array<gyroXYZ> = []
    var gyroCnt : Int = 0
    var gyroAvgDouble : [Double] = [0,0,0]
    var gyroVarDouble : [Double] = [0,0,0]
    var gyroBiasDouble : [Double] = [0,0,0]
    
    // 2) Attitude Data
    
    // Attitude
    var roll : Double = 0.0
    var pitch: Double = 0.0
    var yaw : Double = 0.0
    var yawSetCnt : Int = 0
    var yawMisAlignMent : Double = 0.0
    
    // 3) Navigation Data
    
    var speed : Double = 0.0
    var heading : Double = 0.0
    var headingRate : Double = 0.0
    
    var staticDetectionStatus : STATIC_STATUS = STATIC_STATUS.INIT
    var staticCnt :Int  = 0
    var staticFlag : Int = 0 // 0: Dynamic, 1 : Static
    
    // Acceleration array
    var accXYZ_1meas : [Double] = [0,0,0]
    var accXYZ_1s : [Double] = [0,0,0]
    var accSumXY : [Double] = [0,0,0]
    var accNED : [Double] = [0,0,0]

    
    init(){
        
    }
    
    // Compute Attitude on static status
    func computeAttitude () {
        // Compute roll and pitch value on the static status
        var acc :[Double] = [0,0,0]
        var Roll:Double = 0.0
        var Pitch:Double = 0.0
        
        for i in 0...2{
            acc[i] = self.accAvgDouble[i] //-accBiasDouble[i]
        }
        
        let Gravity = sqrt(acc[0]*acc[0]+acc[1]*acc[1]+acc[2]*acc[2])
        
        Pitch = asin(-acc[1]/Gravity)
        Roll = asin(acc[0]/(Gravity*cos(Pitch)))

        
        if(self.staticCnt == 1){
            self.roll = Roll
            self.pitch = Pitch
        }
        else{
            self.roll = 0.8 * Roll + 0.2 * self.roll
            self.pitch = 0.8 * Pitch + 0.2 * self.pitch
        }
    }
    
    func updateAttitude(){
        var gyro :[Double] = [0,0,0]
        for i in 0...2{
            gyro[i] = self.gyroAvgDouble[i] - self.gyroBiasDouble[i]
        }
    }
    
    func computeAccXYZ(){
        var acc :[Double] = [0,0,0]
        for i in 0...2{
            acc[i] = self.accAvgDouble[i]-self.accBiasDouble[i]
            //print("i: \(acc[i]), \(accAvgDouble[i]) , \(accBiasDouble[i])")
        }
        
        let cosPitch = cos(pitch)
        let sinPitch = sin(pitch)
        let cosRoll = cos(roll)
        let sinRoll = sin(roll)
        
        self.accXYZ_1meas[0] = cosRoll * acc[0] + sinRoll * acc[2]
        self.accXYZ_1meas[1] = cosPitch * acc[1] + sinPitch * (-sinRoll * acc[0] + sinRoll * acc[2])
        self.accXYZ_1meas[2] = sinPitch * acc[1] + cosPitch * (-sinRoll * acc[0] + cosRoll * acc[2])
        
//        print("roll: \(round(roll * r2d * 10)/10)")
//        print("pitch: \(round(pitch * r2d * 10)/10)")
//        print("accXYZ:   \(accXYZ[0])  ,  \(accXYZ[1])  ,  \(accXYZ[2])")
//
        if(abs(self.headingRate * r2d)<0.3   && self.yawSetCnt < 10){
            if(self.accXYZ_1meas[0]>0){
                self.accSumXY[0] += self.accXYZ_1meas[0]
                self.accSumXY[1] += self.accXYZ_1meas[1]
            }
            else{
                self.accSumXY[0] += -self.accXYZ_1meas[0]
                self.accSumXY[1] += -self.accXYZ_1meas[1]
            }
        }
        
        if(accSumXY[0] > 15.0 || accSumXY[1] > 15.0){
            let tmp = atan2(accSumXY[0],accSumXY[1]) - Double.pi/2
            if(yawSetCnt == 0){
                // Initial value
                yaw = tmp
            }
            else{
                // Update weighted average
                yaw = yaw * 0.8 + tmp * 0.2
            }
            yawSetCnt += 1
        }
        
//        log_print(log: "accSumXY,\(accSumXY[0]),\(accSumXY[1]),yaw,\(yaw),yawSetCnt,\(yawSetCnt),hdgRate,\(headingRate * r2d)\n")
        
        
    }
    
    func computeHdgRate(){
        let cosRoll = cos(self.roll)
        let sinRoll = sin(self.roll)
        let cosPitch = cos(self.pitch)
        let sinPitch = sin(self.pitch)
        
        
        
        var gyro :[Double] = [0,0,0]
        for i in 0...2{
            gyro[i] = self.gyroAvgDouble[i] - self.gyroBiasDouble[i]
        }
        // if headingRate < threshold
        // Take ratio to yaw
        // and count the yawCnt
        
        self.headingRate = -sinPitch * gyro[1] + cosPitch * (sinRoll * gyro[0] - cosRoll * gyro[2])
        
    }
    
    func checkStaticDetection(accThreshold : Double , gyroThreshold : Double){
       
//        let accResetThreshold = 0.15
//        let gyroResetThreshold = 0.15
        
        if(
            (self.accVarDouble[0] < accThreshold
             && self.accVarDouble[1] < accThreshold
             && self.accVarDouble[2] < accThreshold )
            &&
            (self.gyroVarDouble[0] < gyroThreshold
             && self.gyroVarDouble[1] < gyroThreshold
             && self.gyroVarDouble[2] < gyroThreshold)
        ){
//            staticDetectionStatus = 1
            if (self.speed < 0.5 && self.speed >= 0){
                self.staticDetectionStatus = STATIC_STATUS.STATIC
            }
        }
        else{
            if(self.staticDetectionStatus == STATIC_STATUS.INIT){
                self.staticDetectionStatus = STATIC_STATUS.DYNAMIC
            }
            else if (
                (self.staticDetectionStatus == STATIC_STATUS.DYNAMIC)
//                ||
//                (
//                    (accVarDouble[0] > accResetThreshold
//                     || accVarDouble[1] > accResetThreshold
//                     || accVarDouble[2] > accResetThreshold )
//                    &&
//                    (gyroVarDouble[0] > gyroResetThreshold
//                     || gyroVarDouble[1] > gyroResetThreshold
//                     || gyroVarDouble[2] > gyroResetThreshold)
//                )
            ) // start Dynamic.
            {
                self.staticDetectionStatus = STATIC_STATUS.DYNAMIC
            }else if (self.staticDetectionStatus == STATIC_STATUS.STATIC) // After static Detection
            {
                self.staticDetectionStatus = STATIC_STATUS.DYNAMIC_AFTER_STATIC
            }
            
        }
        
    }
    
    func storeSensorBias(){
        
        for i in 0...2{
            if(self.staticCnt == 0 ){
                self.accBiasDouble[i] = self.accAvgDouble[i]
                self.gyroBiasDouble[i] = self.gyroAvgDouble[i]
            }
            else{
                self.accBiasDouble[i] = 0.8 * self.accBiasDouble[i] + 0.2 * self.accAvgDouble[i]
                self.gyroBiasDouble[i] = 0.8 * self.gyroAvgDouble[i] + 0.2 * self.gyroAvgDouble[i]
            }
        }
        self.staticCnt += 1
        self.computeAttitude()
        
    }
    
    func accAvgVarCalulate(){
        let cnt = accCnt
        var accSum : accXYZ = accXYZ(xyz: [0,0,0], timeStamp: 0)
        var accSqSum : accXYZ = accXYZ(xyz: [0,0,0], timeStamp: 0)
        if(cnt != 0 ) {
            for i in 0...(cnt-1){
                for j in 0...2{
                    accSum.xyz[j] += accArray[i].xyz[j]
                    accSqSum.xyz[j] += pow(accArray[i].xyz[j], 2)
                }
            }
            for j in 0...2{
                self.accAvgDouble[j] = accSum.xyz[j]/Double(cnt)
                self.accVarDouble[j] = accSqSum.xyz[j]/Double(cnt) - self.accAvgDouble[j] * self.accAvgDouble[j]
            }
        }
        return
    }
    
    func gyroAvgVarCaluate(){
        let cnt = gyroCnt
        var gyroSum : gyroXYZ = gyroXYZ(xyz: [0,0,0], timeStamp: 0)
        var gyroSqSum : gyroXYZ = gyroXYZ(xyz: [0,0,0], timeStamp: 0)
        if(cnt != 0 ) {
            for i in 0...(cnt-1){
                for j in 0...2{
                    gyroSum.xyz[j] += self.gyroArray[i].xyz[j]
                    gyroSqSum.xyz[j] += pow(self.gyroArray[i].xyz[j],2)
                }
            }
            for j in 0...2{
                self.gyroAvgDouble[j] = gyroSum.xyz[j]/Double(cnt)
                self.gyroVarDouble[j] = gyroSqSum.xyz[j]/Double(cnt) - self.gyroAvgDouble[j] * self.gyroAvgDouble[j]
            }
        }
        return
    }
    
    func initializeSensorBuffer(){
        //Initialize acc,gyro Buffer
        self.accArray  = []
        self.accAvgDouble = [0,0,0]
        self.accVarDouble = [0,0,0]
        self.accCnt = 0
        
        self.gyroArray = []
        self.gyroAvgDouble = [0,0,0]
        self.gyroVarDouble = [0,0,0]
        self.gyroCnt = 0
    }
    
    func initializeAttitude(){
        self.roll = 0
        self.pitch = 0
    }
    
    func initializeStaticStatus(){
        self.staticDetectionStatus = STATIC_STATUS.INIT
        self.staticCnt = 0
    }
    
    func initializePVDate(){
        self.accSumXY = [0,0,0]
    }
    
    
}
