//
//  ViewController.swift
//  CardNavigationStack
//
//  Created by Stephen Silber on 5/19/17.
//  Copyright © 2017 calendre. All rights reserved.
//

import UIKit

// Allows child view controllers to pass their scroll delegates without setting UIScrollView.delegate (breaks tableView, etc)
protocol CardChildScrollDelegate: class {
    //func shouldAllowScrollingToBegin() -> Bool
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
}

class CardViewController: UIViewController {

    enum State {
        case minimized
        case stack
        case expanded
    }

    var state: State

    lazy var container: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        
        return view
    }()
    
    fileprivate(set) var snapshot: UIView? { // We store our snapshot and update it whenever our child tells us we need to
        didSet {
            snapshot?.layer.shadowOpacity = 0.25
            snapshot?.layer.shadowColor = UIColor.black.cgColor
            snapshot?.layer.shadowRadius = 5
            snapshot?.clipsToBounds = false
        }
    }
    
    // MARK: Scroll delegate helper flags
    fileprivate struct ScrollFlags {
        var isDragging: Bool = false
        var isTransitioning: Bool = false
    }
    
    let child: CardChild
    fileprivate var scrollFlags: ScrollFlags = ScrollFlags()

    // When passed a CardContainerChild, we need to wrap it in a view and position it
    init(child: CardChild, state: State) {
        self.state = state
        self.child = child
        super.init(nibName: nil, bundle: nil)
        
        view.addSubview(container)
        container.addSubview(child.scrollView)
        
        container.layer.shadowOpacity = 0.25
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowRadius = 5
        container.clipsToBounds = false
        
        child.scrollDelegate = self
        child.updateSnapshot = updateSnapshot
    }
    
    // TODO: Allow initializing without a CardContainerChild
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(toParentViewController parent: UIViewController?) {
        if parent != nil {
            updateSnapshot()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        container.frame = self.frame(for: state)
        child.scrollView.frame = container.bounds
    }
    
    func navigate(to state: State, animated: Bool, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.9, options: [], animations: {
                self.container.frame = self.frame(for: state)
            }, completion: { finished in
                self.state = state
            })
        } else {
            container.frame = self.frame(for: state)
            self.state = state
        }
    }
    
    fileprivate func frame(for state: State) -> CGRect {
        return CGRect(x: 10, y: self.origin(for: state), width: view.bounds.width - 20, height: view.bounds.height * 0.9)
    }
    
    fileprivate func origin(for state: State) -> CGFloat {
        switch state {
        case .minimized:
            return view.bounds.height - 110
        
        case .stack:
            return view.bounds.height * 0.4
        
        case .expanded:
            return view.bounds.height * 0.1
            
        }
    }
    
    func updateSnapshot() {
        container.frame = self.frame(for: state)
        
        var snapshotRect = container.bounds
        snapshotRect.size.width = container.bounds.width
        snapshotRect.size.height = view.bounds.height - origin(for: .stack)
        
        guard let snapshot = container.resizableSnapshotView(from: snapshotRect, afterScreenUpdates: true, withCapInsets: .zero) else {
            print("Unable to snapshot view: \(container)")
            return
        }
        
        self.snapshot = snapshot
    }
    
    func resetSnapshot() {
        snapshot?.removeFromSuperview()
        snapshot = nil
        // TODO: Maybe we should just reset animatable properties here instead of deleting it completely
    }
    
}

extension CardViewController: CardChildScrollDelegate {
   
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollFlags.isDragging = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else { return }
        
        if scrollView.contentOffset.y < 0 {
            container.frame.origin.y += fabs(scrollView.contentOffset.y)
            scrollView.contentOffset = .zero
        } else if container.frame.origin.y > self.origin(for: .expanded) {
            container.frame.origin.y -= scrollView.contentOffset.y
            scrollView.contentOffset = .zero
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollFlags.isDragging = false
        
        guard scrollView.contentOffset.y == 0 else {
            return
        }
        
        var nextState: State = state
        
        let buffer: CGFloat = 25
        
        targetContentOffset.pointee.y = 0
        
        switch self.state {
        case .minimized:
            if container.frame.origin.y >= self.origin(for: .stack) - buffer && velocity.y > 0 {
                nextState = .stack
            } else if velocity.y > 0 {
                nextState = .expanded
            }
        case .stack:
            if container.frame.origin.y >= self.origin(for: .expanded) - buffer && velocity.y > 0 {
                nextState = .expanded
            } else if container.frame.origin.y <= self.origin(for: .minimized) + buffer && velocity.y < 0 {
                nextState = .minimized
            }
        
        case .expanded:
            if container.frame.origin.y <= self.origin(for: .stack) + buffer && velocity.y < 0 {
                nextState = .stack
            } else if container.frame.origin.y >= self.origin(for: .stack) - buffer && velocity.y < 0 {
                nextState = .minimized
            }
        }
        
        navigate(to: nextState, animated: true)
    }
}
