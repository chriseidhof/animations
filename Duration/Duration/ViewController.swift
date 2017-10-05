//
//  ViewController.swift
//  AnimationTesting
//
//  Created by Chris Eidhof on 01.10.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

enum Either<A,B> {
    case left(A)
    case right(B)
}

extension Either where A == B {
    var value: A {
        switch self {
        case .left(let x): return x
        case .right(let y): return y
        }
    }
}

//enum AnimationResult<A> {
//    case done(A, at: RelativeTime)
//    case inProgress(A)
//
//    var value: A {
//        switch self {
//        case let .done(x,_): return x
//        case .inProgress(let x): return x
//        }
//    }
//
//    func zip<B, C>(_ other: AnimationResult<B>, with: (A,B) -> C) -> AnimationResult<C> {
//        switch (self,other) {
//        case let (.done(x, t1), .done(y, t2)): return .done(with(x,y), at: max(t1, t2))
//        default: return .inProgress(with(self.value, other.value))
//        }
//    }
//
//    func map<B>(_ transform: (A) -> B) -> AnimationResult<B> {
//        switch self {
//        case let .done(x, at: time): return .done(transform(x), at: time)
//        case .inProgress(let x): return .inProgress(transform(x))
//        }
//    }
//}

struct Animation<A> {
    let value: (RelativeTime) -> A
    let duration: RelativeTime
    
    init(duration: RelativeTime, _ value: @escaping (RelativeTime) -> A) {
        self.duration = duration
        self.value = value
    }
    
    init(duration: RelativeTime, constant: A) {
        self.duration = duration
        self.value = { _ in constant }
    }
//
//    init(inProgress constant: A) {
//        self.value = { _ in .inProgress(constant) }
//    }

}

//extension Animation where A == () {
////    static let one = Animation<()>(.done(()))
//
//    init() {
//        self.init(constant: ())
//    }
//
//}

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

extension Animation {
    func parallel<B, C>(_ other: Animation<B>, _ transform: @escaping (A,B) -> C) -> Animation<C> {
        return Animation<C>(duration: max(self.duration, other.duration)) { time in
            let a = self.value(time)
            let b = other.value(time)
            return transform(a,b)
        }
    }
    
    func sequential<B>(_ other: Animation<B>) -> Animation<Either<A,B>> {
        return Animation<Either<A,B>>(duration: self.duration + other.duration) { time in
            return time <= self.duration ? .left(self.value(time)) : .right(other.value(time-self.duration))
        }

    }
}

// RelativeTime is never less than zero
typealias RelativeTime = CFAbsoluteTime

// Parallel Composition
func +<A,B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<(A,B)> {
    return lhs.parallel(rhs) { ($0, $1) }
}

// Sequential Composition
func *<A,B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<Either<A,B>> {
    return lhs.sequential(rhs)
}

func *<A>(lhs: Animation<A>, rhs: Animation<A>) -> Animation<A> {
    return (lhs * rhs).map { $0.value }
}

extension Animation {
    func map<B>(_ f: @escaping (A) -> B) -> Animation<B> {
        return Animation<B>(duration: duration) { f(self.value($0)) }
    }
    
    func mapWithTime<B>(_ f: @escaping (RelativeTime, A) -> B) -> Animation<B> {
        return Animation<B>(duration: duration) { time in
            return f(time, self.value(time))
        }
    }
}

extension Animation where A == CGFloat {
    func addSpeed(_ speed: A) -> Animation<A> {
        return mapWithTime { time, value in
            return value + CGFloat(time)*speed
        }
    }
    
    init(from: CGFloat, to: CGFloat, duration: TimeInterval, curve: @escaping AnimationCurve = linear) {
        // todo curve
        let diff = to-from
        self = Animation(duration: duration) {
            let unitTime = $0 / duration
            return unitTime >= 1 ? to : from + diff*CGFloat(unitTime)
        }.augmentCurve(curve: curve)
    }
}

extension Animation {
    func changeSpeed(factor: RelativeTime) -> Animation {
        return Animation(duration: duration / factor) { time in
            self.value(time * factor)
        }
    }

    var halfSpeed: Animation {
        return changeSpeed(factor: 0.5)
    }
    
    var doubleSpeed: Animation {
        return changeSpeed(factor: 2)
    }
    
    func delay(by: RelativeTime, initialValue: A) -> Animation {
        return Animation(duration: by, constant: initialValue) * self
    }

    fileprivate func augmentCurve(curve: @escaping AnimationCurve) -> Animation {
        return Animation(duration: self.duration) { time in
            self.value(curve(time/self.duration))
        }
    }
}

struct InterpretedAnimation {
    enum State { case running, done }
    let run: (RelativeTime) -> State
    
    init<A>(animation: Animation<A>, interpret: @escaping (A) -> ()) {
        run = {
            let result = animation.value($0)
            interpret(result)
            return $0 >= animation.duration ? .done : .running
        }
    }
}

final class Driver: NSObject {
    var displayLink: CADisplayLink!
    var animations: [(startTime: CFAbsoluteTime, InterpretedAnimation)] = []
    var pendingAnimations: [InterpretedAnimation] = []
    
    override init() {
        super.init()
        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink.add(to: RunLoop.main, forMode: .commonModes)
    }

    func add(_ animation: InterpretedAnimation) {
        pendingAnimations.append(animation)
        displayLink.isPaused = false
    }
    
    @objc func step(_ displayLink: CADisplayLink) {
        let time = displayLink.targetTimestamp
        for p in pendingAnimations {
            animations.append((startTime: time, p))
        }
        pendingAnimations = []
        var toBeRemoved: [Int] = []
        for ((startTime: startTime, animation), index) in zip(animations, animations.indices) {
            let animationTime = time - startTime
            let result = animation.run(animationTime)
            if result == .done {
                toBeRemoved.append(index)
            }
        }
        for i in toBeRemoved.reversed() {
            animations.remove(at: i)
        }
        if animations.isEmpty {
            displayLink.isPaused = true
        }
    }
    
    deinit {
        displayLink.remove(from: .main, forMode: .commonModes)
    }
}

func dot(origin: CGPoint, size: CGSize = CGSize(width: 30, height: 30), backgroundColor: UIColor = .orange) -> UIView {
    let result = UIView(frame: CGRect(origin: origin, size: size))
    result.backgroundColor = backgroundColor
    result.layer.cornerRadius = size.width/2
    result.layer.masksToBounds = true
    return result
}

class ViewController: UIViewController {
    var driver: Driver = Driver()
    
    @IBOutlet weak var redBox: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        CATransaction.setDisableActions(true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let dots = (0..<5).map {
            dot(origin: CGPoint(x: -15, y: 40 * (1 + $0)))
        }
        
        let rightDots = (0..<5).map {
            dot(origin: CGPoint(x: view.bounds.width-15, y: 40 * (1 + CGFloat($0))))
        }
        
        func makeAnimation(from: CGFloat, to: CGFloat) -> Animation<CGFloat> {
            let target = from + (to-from)*1.2
            return Animation(from: from,
                             to: target,
                             duration: 0.37,
                             curve: linear) *
                Animation(from: target, to: to, duration: 0.63, curve: builtin(.easeOut))
        }
        
        for (index, dot) in dots.enumerated() {
            view.addSubview(dot)
            let animation = makeAnimation(from: 0, to: 30).delay(by: Double(index) * 0.1, initialValue: 0)
            
            driver.pendingAnimations.append(InterpretedAnimation(animation: animation, interpret: { value in
                dot.transform = CGAffineTransform(translationX: value, y: 0)
            }))
        }
        

        for (index, dot) in rightDots.enumerated() {
            view.addSubview(dot)
            let animation = makeAnimation(from: 0, to: -30).changeSpeed(factor: 1-(0.1*Double(index)))
            driver.add(InterpretedAnimation(animation: animation, interpret: { x in
                dot.transform = CGAffineTransform(translationX: x, y: 0)
            }))
        }

    }
}
