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

// RelativeTime is never less than zero
typealias RelativeTime = CFAbsoluteTime

struct Animation<State, A> {
    let next: (inout State, inout A, _ delta: RelativeTime) -> ()
}

extension Animation {
    init(constant: A) {
        self.next = { _, result, _ in result = constant }
    }
    
}

extension Animation where A == CGFloat {
    init(velocity: CGFloat) {
        next = { _, result, dt in
            result += CGFloat(dt) * velocity
        }
    }
}

extension Animation where State == CGFloat, A == CGFloat {
    init(force: CGFloat) {
        next = { velocity, result, dt in
            velocity += CGFloat(dt) * force
            result += CGFloat(dt) * velocity
        }
    }
    
}

extension Animation {
    func parallel<State2, B>(_ other: Animation<State2,B>) -> Animation<(State, State2), (A,B)> {
        return Animation<(State, State2), (A,B)> { s, result, dt in
            self.next(&s.0, &result.0, dt)
            other.next(&s.1, &result.1, dt)
        }
    }
    
    func sequence(_ other: Animation<State,A>, after: (RelativeTime)) -> Animation<State,A> {
        var time: RelativeTime = 0
        return Animation<State, A> { s, result, dt in
            time += dt
            if time < after {
                self.next(&s, &result, dt)
            } else {
                other.next(&s, &result, dt)
            }
        }
    }
}

class InterpretedAnimation {
    func run(_ timeDiff: RelativeTime) {
        fatalError()
    }
}

final class _InterpretedAnimation<S, A>: InterpretedAnimation {
    enum State { case done, running }
    var current: A
    var state: S
    var animation: Animation<S,A>
    var interpret: (A) -> ()
    
    init(initial: A, state: S, animation: Animation<S,A>, interpret: @escaping (A) -> ()) {
        self.state = state
        self.current = initial
        self.animation = animation
        self.interpret = interpret
    }
    
    override func run(_ timeDiff: RelativeTime) {
        animation.next(&state, &current, timeDiff)
        interpret(current)
    }
}

final class Driver: NSObject {
    var displayLink: CADisplayLink!
    var animations: [InterpretedAnimation] = []
    var previousTime: CFAbsoluteTime!
    
    override init() {
        super.init()
        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink.add(to: RunLoop.main, forMode: .commonModes)
    }
    
    func add(_ animation: InterpretedAnimation) {
        animations.append(animation)
        displayLink.isPaused = false
    }
    
    @objc func step(_ displayLink: CADisplayLink) {
        let time = displayLink.targetTimestamp
        defer { previousTime = time }
        if previousTime == nil { return }
        let diff = time - previousTime
        
        for animation in animations {
            animation.run(diff)
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
        let x = dot(origin: CGPoint(x: 10, y: 10))
        view.addSubview(x)
        let anim = Animation(force: 75).sequence(Animation(force: -100), after: 2)
        let i: InterpretedAnimation = _InterpretedAnimation(initial: 0, state: 0, animation: anim, interpret: {
            x.transform = CGAffineTransform(translationX: $0, y: 0)
        })
        driver.add(i)
        //        let dots = (0..<5).map {
        //            dot(origin: CGPoint(x: -15, y: 40 * (1 + $0)))
        //        }
        //
        //        Animation(constant: 0)
        //
        //        for (index, dot) in dots.enumerated() {
        //            view.addSubview(dot)
        //        }
    }
}


