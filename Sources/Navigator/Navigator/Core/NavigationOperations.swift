//
//  NavigationOperations.swift
//  Navigator
//
//  Created by Michael Long on 1/18/25.
//

import SwiftUI

extension Navigator {

    /// Navigates to a specific ``NavigationDestination`` using the destination's ``NavigationMethod``.
    ///
    /// This may push an item onto the stacks navigation path, or present a sheet or fullscreen cover view.
    /// ```swift
    /// Button("Button Navigate to Home Page 55") {
    ///     navigator.navigate(to: HomeDestinations.pageN(55))
    /// }
    /// ```
    @MainActor
    public func navigate<D: NavigationDestination>(to destination: D) {
        navigate(to: destination, method: destination.method)
    }

    /// Navigates to a specific NavigationDestination overriding the destination's specified navigation method.
    ///
    /// This may push an item onto the stacks navigation path, or present a sheet or fullscreen cover view.
    @MainActor
    public func navigate<D: NavigationDestination>(to destination: D, method: NavigationMethod) {
        log("Navigator navigating to: \(destination), via: \(method)")
        switch method {
        case .push:
            push(destination)

        case .send:
            send(value: destination)

        case .sheet:
            guard state.sheet?.id != destination.id else { return }
            state.sheet = AnyNavigationDestination(wrapped: destination)

        case .cover:
            guard state.cover?.id != destination.id else { return }
            #if os(iOS)
            state.cover = AnyNavigationDestination(wrapped: destination)
            #else
            state.sheet = AnyNavigationDestination(wrapped: destination)
            #endif
        }
    }

}

extension Navigator {

    /// Pushes a new ``NavigationDestination`` onto the stack's navigation path.
    /// ```swift
    /// Button("Button Push Home Page 55") {
    ///     navigator.push(HomeDestinations.pageN(55))
    /// }
    /// ```
    @MainActor
    public func push(_ destination: any NavigationDestination) {
        if let destination = destination as? any Hashable & Codable {
            state.path.append(destination) // ensures NavigationPath knows type is Codable
        } else {
            state.path.append(destination)
        }
    }

    /// Pops to a specific position on stack's navigation path.
    @MainActor
    @discardableResult
    public func pop(to position: Int)  -> Bool {
        state.pop(to: position)
    }

    /// Pops the specified number of the items from the end of a stack's navigation path.
    ///
    /// Defaults to one if not specified.
    /// ```swift
    /// Button("Go Back") {
    ///     navigator.pop()
    /// }
    /// ```
    @MainActor
    @discardableResult
    public func pop(last k: Int = 1) -> Bool {
        if state.path.count >= k {
            state.path.removeLast(k)
        }
        return false
    }

    /// Pops all items from the navigation path, returning to the root view.
    /// ```swift
    /// Button("Go Back") {
    ///     navigator.popAll()
    /// }
    /// ```
    @MainActor
    @discardableResult
    public func popAll() -> Bool {
        if !state.path.isEmpty {
            state.path.removeLast(state.path.count)
            return true
        }
        return false
    }

    /// Indicates whether or not the navigation path is empty.
    public nonisolated var isEmpty: Bool {
        state.path.isEmpty
    }

    /// Number of items in the navigation path.
    public nonisolated var count: Int {
        state.path.count
    }

}

extension NavigationState {

    /// Pops to a specific position on stack's navigation path.
    internal func pop(to position: Int)  -> Bool {
        if position <= path.count {
            path.removeLast(path.count - position)
            return true
        }
        return false
    }

}
