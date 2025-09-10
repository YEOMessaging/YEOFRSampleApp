//
//  VideoScreenState.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 08/09/2025.
//


enum VideoScreenState {
        case recognising
        case registering(EnrollmentStepState)
        case registered
        
        var isRecognising: Bool {
            switch self {
            case .recognising:
                return true
            default:
                return false
            }
        }
        
        var isRegistering: Bool {
            switch self {
            case .registering:
                return true
            default:
                return false
            }
        }
        
        var isRegistered: Bool {
            switch self {
            case .registered:
                return true
            default:
                return false
            }
        }
        
        var enrollmentStepState: EnrollmentStepState? {
            switch self {
            case .registering(let enrolState):
                return enrolState
            default:
                return nil
            }
        }
    }
