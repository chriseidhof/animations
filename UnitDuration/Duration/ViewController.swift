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

struct Animation<A> {
    let value: (RelativeTime) -> A
    
    init(_ value: @escaping (RelativeTime) -> A) {
        self.value = value
    }
    
    init(constant: A) {
        self.value = { _ in constant }
    }
}

extension Animation {
    func parallel<B, C>(_ other: Animation<B>, _ transform: @escaping (A,B) -> C) -> Animation<C> {
        return Animation<C> { time in
            let a = self.value(time)
            let b = other.value(time)
            return transform(a,b)
        }
    }
    
    // ratio is the duration of self, other.duration is 1-ratio
    func sequential<B>(ratio: RelativeTime = 0.5, _ other: Animation<B>) -> Animation<Either<A,B>> {
        return Animation<Either<A,B>> { time in
            return time <= ratio ? .left(self.value(time/ratio)) : .right(other.value((time-ratio)/(1-ratio)))
        }
    }
    
    func sequential<B>(ratio: RelativeTime = 0.5, _ other: @escaping (A) -> Animation<B>) -> Animation<Either<A,B>> {
        let endValue = self.value(1)
        return Animation<Either<A,B>> { time in
            return time <= ratio ? .left(self.value(time/ratio)) : .right(other(endValue).value((time-ratio)/(1-ratio)))
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
        return Animation<B> { f(self.value($0)) }
    }
    
    func mapWithTime<B>(_ f: @escaping (RelativeTime, A) -> B) -> Animation<B> {
        return Animation<B> { time in
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
    
    init(from: CGFloat, to: CGFloat, curve: @escaping AnimationCurve = linear) {
        // todo curve
        let diff = to-from
        self = Animation {
            return $0 >= 1 ? to : from + diff*CGFloat($0)
        }.augmentCurve(curve: curve)
    }
}

extension Animation {
    func delay(by: RelativeTime, initialValue: A) -> Animation {
        precondition((0.0...1.0).contains(by))
        return Animation(constant: initialValue).sequential(ratio: by, self).map { $0.value }
    }

    fileprivate func augmentCurve(curve: @escaping AnimationCurve) -> Animation {
        return Animation { time in
            self.value(curve(time))
        }
    }
}

struct InterpretedAnimation {
    enum State { case running, done }
    let run: (RelativeTime) -> State
    
    init<A>(animation: Animation<A>, duration: RelativeTime, interpret: @escaping (A) -> ()) {
        run = {
            let result = animation.value($0 / duration)
            interpret(result)
            return $0 >= duration ? .done : .running
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
            return Animation(from: from,
                             to: from + (to-from)*1.2,
                             curve: builtin(.easeIn)).sequential(ratio: 0.37, { t in
                                Animation(from: t, to: to, curve: builtin(.easeOut))                                
                             }).map { $0.value }
        }
        
        for (index, dot) in dots.enumerated() {
            view.addSubview(dot)
            let animation = makeAnimation(from: 0, to: 30).delay(by: Double(index) * 0.1, initialValue: 0)
            
            driver.pendingAnimations.append(InterpretedAnimation(animation: animation, duration: 3, interpret: { value in
                dot.transform = CGAffineTransform(translationX: value, y: 0)
            }))
        }
        

        for (index, dot) in rightDots.enumerated() {
            view.addSubview(dot)
            let animation = makeAnimation(from: 0, to: -30)
            driver.add(InterpretedAnimation(animation: animation, duration: 1 + 0.1*Double(index), interpret: { x in
                dot.transform = CGAffineTransform(translationX: x, y: 0)
            }))
        }

    }
}
