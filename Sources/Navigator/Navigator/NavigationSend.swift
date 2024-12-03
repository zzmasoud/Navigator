//
//  NavigationSend.swift
//  Navigator
//
//  Created by Michael Long on 11/14/24.
//

import Combine
import SwiftUI

extension Navigator {

    @MainActor
    public func send(_ value: any Hashable) {
        send(value, [])
    }

    @MainActor
    public func send(values: [any Hashable]) {
        guard let value: any Hashable = values.first else {
            return
        }
        send(value, Array(values.dropFirst()))
    }

    internal func send(_ value: any Hashable, _ values: [any Hashable]) {
        log("Navigator \(id) sending \(value)")
        publisher.send((value, values))
    }

}

extension View {

    public func navigationSend<T: Hashable & Equatable>(_ item: Binding<T?>) -> some View {
        self.modifier(NavigationSendValueModifier<T>(item: item))
    }

    public func navigationSend<T: Hashable & Equatable>(values: Binding<[T]?>) -> some View {
        self.modifier(NavigationSendValuesModifier<T>(values: values))
    }

}

public typealias NavigationReceiveResumeHandler<T> = (_ value: T, _ navigator: Navigator) -> NavigationReceiveResumeType
public typealias NavigationReceiveResumeValueOnlyHandler<T> = (_ value: T) -> NavigationReceiveResumeType

public enum NavigationReceiveResumeType {
    case auto
    case immediately
    case after(TimeInterval)
    case with([any Hashable])
    case checkpoint(NavigationCheckpoint)
    case cancel
}

extension View {

    public func onNavigationReceive<T: Hashable>(handler: @escaping NavigationReceiveResumeHandler<T>) -> some View {
        self.modifier(OnNavigationReceiveModifier(handler: handler))
    }

    public func onNavigationReceive<T: Hashable>(handler: @escaping NavigationReceiveResumeValueOnlyHandler<T>) -> some View {
        self.modifier(OnNavigationReceiveModifier(handler: { (value, _) in handler(value) }))
    }

    public func onNavigationReceive<T: NavigationDestination>(_ type: T.Type) -> some View {
        self.modifier(OnNavigationReceiveModifier<T> { (value, navigator) in
            navigator.navigate(to: value)
            return .auto
        })
    }

}

private struct NavigationSendValueModifier<T: Hashable & Equatable>: ViewModifier {
    @Binding internal var item: T?
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: item) { item in
                if let item {
                    navigator.send(item)
                    self.item = nil
                }
            }
    }
}

private struct NavigationSendValuesModifier<T: Hashable & Equatable>: ViewModifier {
    @Binding internal var values: [T]?
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: values) { values in
                if let values {
                    navigator.send(values: values)
                    self.values = nil
                }
            }
    }
}

private struct OnNavigationReceiveModifier<T: Hashable>: ViewModifier {

    private let handler: NavigationReceiveResumeHandler<T>

    @Environment(\.navigator) var navigator: Navigator

    init(handler: @escaping NavigationReceiveResumeHandler<T>) {
        self.handler = handler
    }

    func body(content: Content) -> some View {
        content
            .onReceive(publisher) { (value, values) in
                navigator.log("Navigator \(navigator.id) receiving \(value)")
                resume(handler(value, navigator), values: values)
            }
    }

    var publisher: AnyPublisher<(T, [any Hashable]), Never> {
        navigator.publisher
            .compactMap { $0 as? (T, [any Hashable]) }
            .eraseToAnyPublisher()
    }

    func resume(_ action: NavigationReceiveResumeType, values: [any Hashable], delay: TimeInterval = 0.7) {
        switch action {
        case .auto:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                navigator.send(values: values)
            }
         case .immediately:
            navigator.send(values: values)
        case .after(let interval):
            resume(.auto, values: values, delay: interval)
        case .with(let newValues):
            resume(.auto, values: newValues)
        case .checkpoint(let checkpoint):
            navigator.returnToCheckpoint(checkpoint)
        case .cancel:
            break
        }
    }

}
