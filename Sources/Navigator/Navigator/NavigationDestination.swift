//
//  NavigationPage.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import SwiftUI

/// Provides enumerated navigation types than can be translated into Views.
///
/// NavigationDestination types can be used in order to push and present views as needed.
///
/// This can happen using...
///
/// * Standard SwiftUI modifiers like `NavigationLink(value:label:)`.
/// * Imperatively by asking a ``Navigator`` to perform the desired action.
/// * Or via a deep link action enabled by a ``NavigationURLHander``.
///
/// They're one of the core elements that make Navigator possible.
///
/// ### Defining Navigation Destinations
/// Destinations are typically just a simple list of enumerated values.
/// ```swift
/// public enum HomeDestinations {
///     case page2
///     case page3
///     case pageN(Int)
/// }
/// ```
/// Along with an extension that provides the correct view for a specific case.
/// ```swift
/// extension HomeDestinations: NavigationDestination {
///     public var body: some View {
///         switch self {
///         case .page2:
///             HomePage2View()
///         case .page3:
///             HomePage3View()
///         case .pageN(let value):
///             HomePageNView(number: value)
///         }
///     }
/// }
/// ```
/// Note how associated values can be used to pass paramters to views as needed.
///
/// ### Using Navigation Destinations
/// This can be done via using a standard SwiftUI `NavigationLink(value:label:)` view.
/// ```swift
/// NavigationLink(value: HomeDestinations.page3) {
///     Text("Link to Home Page 3!")
/// }
/// ```
/// Or imperatively by asking a Navigator to perform the desired action.
/// ```swift
/// Button("Button Navigate to Home Page 55") {
///     navigator.navigate(to: HomeDestinations.pageN(55))
/// }
/// ```
///
/// ### Registering Navigation Destinations
/// Like traditional `NavigationStack` destination types, `NavigationDestination` types need to be registered with the enclosing
/// navigation stack in order for standard `NavigationLink(value:label:)` transitions to work correctly.
///
/// But since each `NavigationDestination` already defines the view to be provided, registering destination types can be done
/// using a simple one-line view modifier.
/// ```swift
/// ManagedNavigationStack {
///     HomeView()
///         .navigationDestination(HomeDestinations.self)
/// }
/// ```
/// This also makes using the same destination type with more than one navigation stack a lot easier.
///
/// ### Navigation Methods
/// `NavigationDestination` can also be extended to provide a distinct ``NavigationMethod`` for each enumerated type.
/// ```swift
/// extension HomeDestinations: NavigationDestination {
///     public var method: NavigationMethod {
///         switch self {
///         case .page3:
///             .sheet
///         default:
///             .push
///         }
///     }
/// }
/// ```
/// In this case, should `navigator.navigate(to: HomeDestinations.page3)` be called, Navigator will automatically present that view in a
/// sheet. All other views will be pushed onto the navigation stack.
///
/// > Important: When using `NavigationLink(value:label:)` the method will be ignored and SwiftUI will push
/// the value onto the navigation stack as it would normally.
public protocol NavigationDestination: Hashable, Equatable, Identifiable {

    associatedtype Body: View

    /// Provides the correct view for a specific case.
    /// ```swift
    /// extension HomeDestinations: NavigationDestination {
    ///     public var body: some View {
    ///         switch self {
    ///         case .page2:
    ///             HomePage2View()
    ///         case .page3:
    ///             HomePage3View()
    ///         case .pageN(let value):
    ///             HomePageNView(number: value)
    ///         }
    ///     }
    /// }
    /// ```
    @MainActor @ViewBuilder var body: Self.Body { get }

    /// Can be overridden to define a specific presentation type for each destination.
    var method: NavigationMethod { get }

}

extension NavigationDestination {

    /// Default implementation of Identifiable id.
    public var id: Int {
        self.hashValue
    }

    /// Default navigation method.
    public var method: NavigationMethod {
        .push
    }

    /// Convenience function returns body.
    @MainActor public func callAsFunction() -> some View {
        body
    }

    /// Equatable conformance.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

}

/// Wrapper boxes a specific NavigationDestination.
public struct AnyNavigationDestination {
    public let wrapped: any NavigationDestination
}

extension AnyNavigationDestination: Identifiable {
    public var id: Int { wrapped.id }
}

extension AnyNavigationDestination {
    @MainActor public func callAsFunction() -> AnyView { AnyView(wrapped.body) }
}

extension View {
    /// Registers ``NavigationDestination`` types in order to enable `navigationLink(value:label)` behaviors.
    /// ```swift
    /// ManagedNavigationStack {
    ///     HomeView()
    ///         .navigationDestination(HomeDestinations.self)
    /// }
    /// ```
    /// This also makes using the same destination type with more than one navigation stack a lot easier.
    public func navigationDestination<T: NavigationDestination>(_ type: T.Type) -> some View {
        self.navigationDestination(for: type) { destination in
            destination()
        }
    }
}

extension View {
    public func navigate(to destination: Binding<(some NavigationDestination)?>) -> some View {
        self.modifier(NavigateToModifier(destination: destination))
    }
    public func navigate(trigger: Binding<Bool>, destination: some NavigationDestination) -> some View {
        self.modifier(NavigateTriggerModifier(trigger: trigger, destination: destination))
    }
}

private struct NavigateToModifier<T: NavigationDestination>: ViewModifier {
    @Binding internal var destination: T?
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: destination) { destination in
                if let destination {
                    navigator.navigate(to: destination)
                    self.destination = nil
                }
            }
    }
}

private struct NavigateTriggerModifier<T: NavigationDestination>: ViewModifier {
    @Binding internal var trigger: Bool
    let destination: T
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger {
                    navigator.navigate(to: destination)
                    self.trigger = false
                }
            }
    }
}
