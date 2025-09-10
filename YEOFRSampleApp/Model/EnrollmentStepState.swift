//
//  EnrollmentStepState.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 08/09/2025.
//


struct EnrollmentStepState {
    let step: Int
    let maxSteps: Int
    let recognised: Bool
    
    var progress: Double {
        Double(step) / Double(maxSteps)
    }
}
