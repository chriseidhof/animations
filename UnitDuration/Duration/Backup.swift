////
////  ViewController.swift
////  AnimationTesting
////
////  Created by Chris Eidhof on 01.10.17.
////  Copyright © 2017 objc.io. All rights reserved.
////
//
//import UIKit
//
////: Playground - noun: a place where people can play
//
//import UIKit
//
//struct Animation<A> {
//    let value: (RelativeTime) -> A
//    
//    init(_ value: @escaping (RelativeTime) -> A) {
//        self.value = value
//    }
//    
//    init(constant: A) {
//        self.value = { _ in constant }
//    }
//    
//}
//
//extension Animation where A == () {
//    static let one = Animation<()>()
//    
//    init() {
//        self.value = { _ in () }
//    }
//    
//}
//
//typealias Progress = Double
//
//typealias AnimationCurve = (Progress) -> Progress
//
//extension Double {
//    func clamped(to: ClosedRange<Double>) -> Double {
//        if self < to.lowerBound { return to.lowerBound }
//        if self > to.upperBound { return to.upperBound }
//        return self
//    }
//}
//func linear(_ progress: Progress) -> Progress {
//    return progress
//}
//
//func quadratic(_ progress: Progress) -> Progress {
//    return Progress(progress * progress)
//}
//
//func cubic(_ progress: Progress) -> Progress {
//    return Progress(progress * progress * progress)
//}
//
//func spring(damping b: Double = 10, mass m: Double = 1, stiffness k: Double = 100, velocity v0: Double = 0) -> AnimationCurve {
//    let beta: Double = b / (2*m)
//    let omega0: Double = sqrt(k/m)
//    let omega1: Double = sqrt((omega0 * omega0) - (beta * beta))
//    let omega2: Double = sqrt((beta * beta) - (omega0 * omega0))
//    
//    let x0: Double = -1
//    //if (!self.allowsOverdamping && beta > omega0) beta = omega0;
//    if beta < omega0 {
//        return { t in
//            let envelope: Double = exp(-beta * t)
//            return -x0 + envelope * (x0 * cos(omega1 * t) + ((beta * x0 + v0) / omega1) * sin(omega1 * t))
//        }
//    } else if (beta == omega0) {
//        return { t in
//            let envelope = exp(-beta * t)
//            return -x0 + envelope * (x0 + (beta * x0 + v0) * t)
//        }
//    } else {
//        // Overdamped
//        return { t in
//            let envelope = exp(-beta * t);
//            return -x0 + envelope * (x0 * cosh(omega2 * t) + ((beta * x0 + v0) / omega2) * sinh(omega2 * t));
//        }
//    }
//}
//
//extension Animation where A == CGFloat {
//    init(from start: CGFloat, speed: CGFloat) {
//        value = { time in
//            return start + CGFloat(time)*speed
//        }
//    }
//    
//}
//
//extension Animation {
//    func parallel<B, C>(_ other: Animation<B>, _ transform: @escaping (A,B) -> C) -> Animation<C> {
//        return Animation<C>({ time in
//            let a = self.value(time)
//            let b = other.value(time)
//            return transform(a,b)
//        })
//    }
//}
//
//// RelativeTime is never less than zero
//typealias RelativeTime = CFAbsoluteTime
//
//// Parallel Composition
//func +<A,B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<(A,B)> {
//    return lhs.parallel(rhs) { ($0, $1) }
//}
//
//// Sequential Composition
////func *<A,B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<(A,B)> {
////    return Animation({ time in
////        let a = lhs.value(time)
////        let b = rhs.value(time-lhs.duration)
////        return (a,b)
////    })
////}
//
////extension Animation {
////    func delay(by: RelativeTime) -> Animation<A> {
////        return (Animation<()>(duration: by) * self).map { $0.1 }
////    }
////}
//
//extension Animation {
//    func map<B>(_ f: @escaping (A) -> B) -> Animation<B> {
//        return Animation<B>({ f(self.value($0))})
//    }
//    
//    func mapp<B>(_ f: @escaping (RelativeTime, A) -> B) -> Animation<B> {
//        return Animation<B> { time in
//            f(time, self.value(time))
//        }
//    }
//    
//}
//
//extension Animation where A == CGFloat {
//    func addSpeed(_ speed: A) -> Animation<A> {
//        return mapp { time, value in value + CGFloat(time)*speed }
//    }
//    
//    init(from: CGFloat, to: CGFloat, duration: TimeInterval, curve: @escaping AnimationCurve = linear) {
//        let speed = (to-from)/CGFloat(duration)
//        self = Animation(constant: from).addSpeed(speed).after(duration: duration, switchTo: { endValue in Animation(constant: endValue) }).map { $0.value }.augmentCurve(curve: { time in curve(time/duration)})
//    }
//}
//
//extension Animation {
//    //    func changeSpeed(factor: RelativeTime) -> Animation {
//    //        return Animation(duration: duration / factor, { time in
//    //            self.value(time * factor)
//    //        })
//    //    }
//    //
//    //    var halfSpeed: Animation {
//    //        return changeSpeed(factor: 0.5)
//    //    }
//    
//    fileprivate func augmentCurve(curve: @escaping AnimationCurve) -> Animation {
//        return Animation { time in
//            return self.value(curve(time))
//        }
//    }
//}
//
//enum Either<A,B> {
//    case left(A)
//    case right(B)
//}
//
//extension Animation {
//    func after<B>(duration: RelativeTime, switchTo other: Animation<B>) -> Animation<Either<A,B>> {
//        return Animation<Either<A,B>> { time in
//            if time < duration { return .left(self.value(time)) }
//            else { return .right(other.value(time)) }
//        }
//    }
//    
//    func after<B>(duration: RelativeTime, switchTo other: @escaping (A) -> Animation<B>) -> Animation<Either<A,B>> {
//        return Animation<Either<A,B>> { time in
//            if time < duration {
//                return .left(self.value(time))
//            }
//            else {
//                let otherValue = other(self.value(duration))
//                return .right(otherValue.value(time-duration))
//            }
//        }
//    }
//    
//}
//
//
//
//final class Driver: NSObject {
//    var displayLink: CADisplayLink!
//    var animate: ((CFAbsoluteTime) -> ())!
//    
//    init<A>(animation: Animation<A>, _ interpret: @escaping (A) -> ()) {
//        super.init()
//        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
//        displayLink.add(to: RunLoop.main, forMode: .commonModes)
//        var startTime: CFAbsoluteTime? = nil
//        self.animate = { [unowned self] nextTime in
//            if startTime == nil { startTime = nextTime }
//            let time = nextTime - startTime!
//            let value = animation.value(time)
//            interpret(value)
//            //            if time >= animation.duration {
//            ////                print((time, animation.duration))
//            ////                self.displayLink.isPaused = true
//            //            }
//        }
//    }
//    
//    
//    
//    @objc func step(_ displayLink: CADisplayLink) {
//        animate(displayLink.targetTimestamp)
//    }
//}
//
//extension Either where A == B {
//    var value: A {
//        switch self {
//        case .left(let x): return x
//        case .right(let y): return y
//        }
//    }
//}
//
//class ViewController: UIViewController {
//    var driver: Driver?
//    
//    @IBOutlet weak var redBox: UIView!
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        CATransaction.setDisableActions(true)
//        
//        redBox.frame.origin = .zero
//        let singlePoint = Animation<CGFloat>(from: 0, to: 100, duration: 2).after(duration: 4, switchTo: { end in Animation<CGFloat>(from: end, to: 0, duration: 2) }).map{ $0.value }
//        let other = singlePoint.augmentCurve(curve: { t in spring()(t / 4) } )
//        let point = (singlePoint + other).map { CGPoint(x: $0.0, y: $0.1 )}
//        let origin = point
//        let animation = (origin).map { result in
//            CGAffineTransform(translationX: result.x, y: result.y)
//        }
//        
//        driver = Driver(animation: animation, { [unowned self] transform in
//            self.redBox.transform = transform
//        })
//    }
//    
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
//    
//    
//}
//
//
