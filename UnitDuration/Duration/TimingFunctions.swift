//
//  TimingFunctions.swift
//  Duration
//
//  Created by Chris Eidhof on 05.10.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

typealias Progress = Double

typealias AnimationCurve = (Progress) -> Progress

extension Double {
    func clamped(to: ClosedRange<Double>) -> Double {
        if self < to.lowerBound { return to.lowerBound }
        if self > to.upperBound { return to.upperBound }
        return self
    }
}

struct TimingFunction {
    enum Builtin {
        case linear
        case easeIn
        case easeOut
        case easeInEaseOut
        case `default`
        
        var controlPoints: (Double,Double,Double,Double) {
            switch self {
            case .linear:
                return (0, 0, 1, 1)
            case .easeIn:
                return (0.42, 0, 1, 1)
            case .easeOut:
                return (0, 0, 0.58, 1)
            case .easeInEaseOut:
                return (0.42, 0, 0.58, 1)
            case .`default`:
                return (0.25, 0.1, 0.25, 1)
            }
        }
    }
    
    
    // Taken from https://gist.github.com/raphaelschaad/6739676
    
    private var ax,bx,cx,ay,by,cy: Double
    init(controlPoints p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double) {
        cx = 3.0 * p1x
        bx = 3.0 * (p2x - p1x) - cx
        ax = 1.0 - cx - bx
        
        cy = 3.0 * p1y
        by = 3.0 * (p2y - p1y) - cy
        ay = 1.0 - cy - by
    }
    
    init(type: Builtin = .`default`) {
        let (p1, p2, p3, p4) = type.controlPoints
        self.init(controlPoints: p1, p2, p3, p4)
    }
    
    func value(x: Double) -> Double {
        let xSolved = solve(curveX: x, epsilon: epsilon)
        return sampleCurveY(t: xSolved)
    }
    
    let duration: Double = 1
    
    private var epsilon: Double {
        return 1 / (200*duration)
    }
    
    
    private func sampleCurveX(t: Double) -> Double {
        return ((ax * t + bx) * t + cx) * t
    }
    
    private func sampleCurveY(t: Double) -> Double {
        return ((ay * t + by) * t + cy) * t;
    }
    
    private func sampleCurveDerivativeX(t: Double) -> Double {
        return (3.0 * ax * t + 2.0 * bx) * t + cx
    }
    
    private func solve(curveX x: Double, epsilon: Double) -> Double {
        var t2, x2, d2: Double
        
        // First try a few iterations of Newton's method -- normally very fast.
        t2 = x
        for _ in 0..<8 {
            x2 = sampleCurveX(t: t2) - x
            if (fabs(x2) < epsilon) {
                return t2
            }
            d2 = sampleCurveDerivativeX(t: t2)
            if (fabs(d2) < 1e-6) {
                break
            }
            t2 = t2 - x2 / d2;
        }
        
        // Fall back to the bisection method for reliability.
        var t0: Double = 0.0
        var t1: Double = 1.0
        t2 = x
        
        if (t2 < t0) {
            return t0
        }
        if (t2 > t1) {
            return t1
        }
        
        while (t0 < t1) {
            x2 = sampleCurveX(t: t2)
            if (fabs(x2 - x) < epsilon) {
                return t2
            }
            if (x > x2) {
                t0 = t2
            } else {
                t1 = t2
            }
            t2 = (t1 - t0) * 0.5 + t0
        }
        
        // Failure.
        return t2
    }
}

func linear(_ progress: Progress) -> Progress {
    return progress
}

func quadratic(_ progress: Progress) -> Progress {
    return Progress(progress * progress)
}

func cubic(_ progress: Progress) -> Progress {
    return Progress(progress * progress * progress)
}

func builtin(_ b: TimingFunction.Builtin) -> AnimationCurve {
    let tf = TimingFunction(type: b)
    return tf.value
}

func spring(damping b: Double = 10, mass m: Double = 1, stiffness k: Double = 100, velocity v0: Double = 0) -> AnimationCurve {
    let beta: Double = b / (2*m)
    let omega0: Double = sqrt(k/m)
    let omega1: Double = sqrt((omega0 * omega0) - (beta * beta))
    let omega2: Double = sqrt((beta * beta) - (omega0 * omega0))
    
    let x0: Double = -1
    //if (!self.allowsOverdamping && beta > omega0) beta = omega0;
    if beta < omega0 {
        return { t in
            let envelope: Double = exp(-beta * t)
            return -x0 + envelope * (x0 * cos(omega1 * t) + ((beta * x0 + v0) / omega1) * sin(omega1 * t))
        }
    } else if (beta == omega0) {
        return { t in
            let envelope = exp(-beta * t)
            return -x0 + envelope * (x0 + (beta * x0 + v0) * t)
        }
    } else {
        // Overdamped
        return { t in
            let envelope = exp(-beta * t);
            return -x0 + envelope * (x0 * cosh(omega2 * t) + ((beta * x0 + v0) / omega2) * sinh(omega2 * t));
        }
    }
}
