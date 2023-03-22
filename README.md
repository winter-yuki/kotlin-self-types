# Self-types design for Kotlin language

Links:
1. [YouTrack feature request](https://youtrack.jetbrains.com/issue/KT-6494)
2. [Paper on topic of `ThisType` implementation in Java](https://dl.acm.org/doi/10.1145/2888392)
3. [Discussion](https://discuss.kotlinlang.org/t/self-types/371) - java interoperability
4. [Discussion](https://discuss.kotlinlang.org/t/this-type/1421) - observer example
5. [Emulating self types in Kotlin](https://medium.com/@jerzy.chalupski/emulating-self-types-in-kotlin-d64fe8ea2e62)
6. [Self Types with Java’s Generics](https://www.sitepoint.com/self-types-with-javas-generics/) - good about self-types generic emulations drawbacks
7. [Self types via java plugin](https://github.com/manifold-systems/manifold)
8. [`Self` name resolve considerations (ru)](https://maximgran.notion.site/maximgran/Self-types-58e89d6dda374ba9abb4483b192a49c2)

A **self-type** in method signature refers to the type on which a method is called (more formally called the *receiver*).

We will use `Self(C)` type notation denoting self-type that refers to the subtype of class `C` (called *origin*) and has scope of class `C`.


## Motivation

Self-types can be emulated with weird boilerplate code using recursive generics and/or some additional casts. But they are needed in some useful patterns, so there can be a reason to make them a language feature. Moreover, self-types bypasses are enough cumbersome to make programmer choose less suitable design choices in some cases.

Possibility to use `Self` in different positions will be discussed in the next section.

### Transformation chains

The most common example of self-types application is an [abstract builder pattern](https://medium.com/@hazraarka072/fluent-builder-and-powering-it-up-with-recursive-generics-in-java-483005a85fcd). But in Kotlin builders are usually implemented via extension receivers or `apply` function (builder object should be mutable here). But if we want to construct a transformation chain of an immutable object (or to use *prototype* architecture pattern with `clone()` method in class hierarchy), self-types are still useful.

#### Persistent data structures

Modification methods of a persistent data structure do not modify a collection itself but create a modified new one. To modify such collections in fluent style using methods of the base classes, [recursive generics](http://web.archive.org/web/20130721224442/http:/passion.forco.de/content/emulating-self-types-using-java-generics-simplify-fluent-api-implementation) should be used, alternatively derived class should declare [abstract overrides](https://github.com/Kotlin/kotlinx.collections.immutable/blob/d7b83a13fed459c032dab1b4665eda20a04c740f/core/commonMain/src/ImmutableList.kt#L66) for all modification methods with more specific return type.

However, recursive generics are cumbersome and infect code that uses them:

```kotlin
interface PersistentCollection<out E, out Self : PersistentCollection<E, Self>> : Collection<E> {
    fun add(value: @UnsafeVariance E): Self
    fun clear(): Self
}

fun <E, C : PersistentCollection<E, C>> C.addAll(xs: Iterable<E>): C =
    xs.fold(this) { acc, x -> acc.add(x) }

interface PersistentList<out E, out Self : PersistentList<E, Self>> : PersistentCollection<E, Self> {
    fun sublist(fromIndex: Int, toIndex: Int): Self
}
```

Having self-type feature this code looks much simpler:

```kotlin
interface PersistentCollection<out E> : Collection<E> {
    fun add(value: @UnsafeVariance E): Self
    fun clear(): Self
}

fun <E> PersistentCollection<E>.addAll(xs: Iterable<E>): Self =
    xs.fold(this) { acc, x -> acc.add(x) }

interface PersistentList<out E> : PersistentCollection<E> {
    fun sublist(fromIndex: Int, toIndex: Int): Self
}
```

Also, there is no compiler control over such abstract overrides, so developer can easily add new modification method in the base class and forget to add abstract overrides to all derived classes.

#### Immutable data structures

It is also useful to be able to create instances in the base class, e.g. to provide default implementation (example from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494)):

```kotlin
sealed interface Data {
    data class One(var a: Int) : Data
    data class Two(var a: Int, var b: Int) : Data

    fun copy(): Self = when (this) {
        is One -> One(a)
        is Two -> Two(a, b)
    }
}

fun test() {
    val a = Data.One(1)
    val b: Data.One = a.copy()
}
```

### Abstract observable

```kotlin
abstract class AbstractObservable<Self : AbstractObservable<Self>> {
    private val observers = mutableListOf<(Self) -> Unit>()

    fun observe(observer: (Self) -> Unit) {
        observers += observer
    }

    private fun notifyObservers() {
        observers.forEach { observer ->
            @Suppress("UNCHECKED_CAST")
            observer(this as Self)
        }
    }

    protected fun <V> observable(initialValue: V) =
        object : ObservableProperty<V>(initialValue) {
            override fun afterChange(property: KProperty<*>, oldValue: V, newValue: V) {
                notifyObservers()
            }
        }
}

enum class Color {
    Purple, Blue
}

class Element : AbstractObservable<Element>() {
    var color: Color by observable(Color.Purple)
}

fun main() {
    val element = Element().apply {
        observe { it: Element ->
            // Having `it: AbstractObservable` here forces to use another
            // reference to observable element. That is error-prone.
            println("New color = ${it.color}")
        }
    }
    element.color = Color.Blue // Observer prints new color here
}
```

### Recursive containers

https://micsymposium.org/mics_2009_proceedings/mics2009_submission_56.pdf

```kotlin
abstract class Node<out T, out Self : Node<T, Self>>(val value: T, val children: List<Self>)

class BetterNode<out T>(value: T, children: List<BetterNode<T>> = emptyList()) :
    Node<T, BetterNode<T>>(value, children) {
    fun doTheBest() = println(value)
}

fun main() {
    val betterTree = BetterNode(
        2, listOf(
            BetterNode(1),
            BetterNode(
                3, listOf(
                    BetterNode(4),
                    BetterNode(5, listOf(BetterNode(6)))
                )
            )
        )
    )
    betterTree.children
        .flatMap { it.children }
        .forEach { it.doTheBest() } // prints: 4 5
}
```

## Self-types specification

TODO


## Other languages experience

Languages without inheritance (and with type classes, e.g. Haskell and Rust) will not be discussed because self-types implementation is trivial for them. Methods on the call site just have signatures from the declaration site (in type class instance). No variance problems matter.
```haskell
class Incrementable a where
  increment :: a -> a

instance Incrementable Int where
  increment = (+ 1)

test = increment 42 :: Int
```

### Swift

* https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Self-Type
* https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types
* Protocols implementation report: https://youtu.be/ctS8FzqcRug
* Avoiding protocol problems with explicit witnesses: https://youtu.be/3BVkbWXcFS4
* Using `Self` to refer an extended type: https://www.swiftbysundell.com/tips/using-self-to-refer-to-enclosing-types/

Compile example by: `$ swiftc examples.swift`.

Swift protocols are like rust traits (limited type classes). Protocols can be conformed (implemented) by classes. A class can inherit one another.

Plain return positions behave as expected, self-type from the other object is prohibited (casts to the receiver):

```swift
protocol AOut {
    func f() -> Self
    func g() -> Self
}

class BOut: AOut {
    func f() -> Self { print("BOut.f"); return g() }
    func g() -> Self { print("BOut.g"); return self }
    // error: cannot convert return expression of type 'C' to return type 'Self'
    // func h(c: COut) -> Self { print("BOut.h"); return c.g() }
}

class COut: BOut {
    override func g() -> Self { print("COut"); return f() }
}

func test1(c: COut) -> COut {
    return c.f().g()
}
```

If a protocol declaration has `Self` in non-return position or an `associatedtype`, such protocol behaves specially (looks like `some` is Rust's `impl Trait` and `any` is `Box<dyn Trait>`):
```swift
protocol ConstraintOnly {
    func produce() -> Self
    func consume(_ x: Self)
}

// error: use of protocol 'ConstraintOnly' as a type must be written 'any ConstraintOnly'
// func testRawIn(x: ConstraintOnly) {}

// error: use of protocol 'ConstraintOnly' as a type must be written 'any ConstraintOnly'
// func testRawOut(x: any ConstraintOnly) -> ConstraintOnly {
//     return x.produce()
// }

func testAnyToAny(x: any ConstraintOnly) -> any ConstraintOnly {
    return x.produce()
}

// error: type 'any ConstraintOnly' cannot conform to 'ConstraintOnly'
// note: required by opaque return type of global function 'testAnyToSome(x:)'
// func testAnyToSome(x: any ConstraintOnly) -> some ConstraintOnly {
//     return x.produce()
// }

func testSomeToAny(x: some ConstraintOnly) -> any ConstraintOnly {
    return x.produce()
}

// error: member 'consume' cannot be used on value of type 'any ConstraintOnly'; consider using a generic constraint instead
// func testAnyConsume(x: any ConstraintOnly) {
//     x.consume(x.produce())
// }

func testSomeConsume(x: some ConstraintOnly) {
    x.consume(x.produce())
}

func testConstraint<T: ConstraintOnly>(x: T) -> T {
    x.consume(/* T is expected */ x.produce())
    return x.produce()
}
```

In non-return positions `Self` is available only in protocols and class declaration should use itself instead of `Self`:
```swift
// error: covariant 'Self' or 'Self?' can only appear as the type of a property, subscript or method result; did you mean 'D'?
// class D {
//     func id(x: Self) -> Self { return x }
// }

protocol E {
    func f(x: Self) -> Self
}

class F: E {
    func f(x: F) -> Self { return self }
}

class G: F {
    // x type is already fixed in F
    // override func f(x: H) -> Self { return self }
    override func f(x: F) -> Self { return self }
}

protocol H {
    func f() -> Array<Self>
    func g(xs: Array<Self>) -> Array<Self>
}

// class I: H {
    // error: covariant 'Self' or 'Self?' can only appear at the top level of method result type
    // func f() -> Array<Self> { return Array() }

    // error: method 'f()' in non-final class 'I' must return 'Self' to conform to protocol 'H'
    // func f() -> Array<I> { return Array() }

    // error: method 'g(xs:)' in non-final class 'I' must return 'Self' to conform to protocol 'H'
    // func g(xs: Array<I>) -> Array<I> { return Array() }
// }

final class J: H {
    func f() -> Array<J> { return Array() }
    func g(xs: Array<J>) -> Array<J> { return xs }
}
```

`Self` can also be used in any position of extension method declaration aliasing extended type:
```swift
extension PublishingStep {
    static func group(_ steps: [Self]) -> Self {
        Self(...)
    }
}
```

Also `Swift` supports associated types and they can be used to achieve similar behavior but one for one-level hierarchy:
```swift
protocol AAssoc {
    associatedtype S
    func f() -> S
    func g(x: S)
    func h() -> Array<S>
}

class BAssoc : AAssoc {
    typealias S = BAssoc
    func f() -> BAssoc { return self }
    func g(x: BAssoc) { x.specific() }
    func h() -> Array<BAssoc> { return [self] }

    func specific() {}
}

class CAssoc : BAssoc {
    override func f() -> CAssoc { return self }
    // error: method does not override any method from its superclass
    // override func g(x: CAssoc) {}
    // error: method does not override any method from its superclass
    // override func h() -> Array<CAssoc> { return [self, self] }
}

func testAssoc(_ x: some AAssoc, _ y: some AAssoc) {
    x.g(x: x.f())
    // cannot convert value of type '(some AAssoc).S' (associated type of protocol 'AAssoc') to expected argument type '(some AAssoc).S' (associated type of protocol 'AAssoc')
    // x.g(x: y.f())
}
```

### Scala

* https://docs.scala-lang.org/tour/abstract-type-members.html
* https://docs.scala-lang.org/tutorials/FAQ/index.html#how-can-a-method-in-a-superclass-return-a-value-of-the-current-type

Compile examples with: `$ scala3 examples.scala`.

Self-types [mean](https://docs.scala-lang.org/tour/self-types.html) something entirely different in Scala 2 (trait mixin requirement).
Also there is `this.type` but it refers to the singleton type of current value.

There is a [proposal](https://github.com/lampepfl/dotty/issues/7374) to introduce `ThisType` in Scala 3, however it is still raw enough.

Also there is a possibility to emulate self-types with an associated type but only for one layer of hierarchy:
```scala
trait A:
  type S
  def out(): S
  def inp(x: S): Unit
  def inv(x: S): S

class B extends A:
  override type S <: B
  override def out(): S = this.asInstanceOf[S] // Explicit cast
  override def inp(x: S): Unit = x.out()
  override def inv(x: S): S = x

class C extends B:
  override type S = C
  def f(): Unit = println("C.f")
  override def inp(x: C): Unit = x.f()

def test(): Unit = {
  val b = B()
  b.inp(b.out())

  // Found: B#S Required: ?1.S
  // B().inp(B().out())

  C().out().f()
}
```

### Python

* https://peps.python.org/pep-0673/

In Python `Self` type only in output position of methods is required.

### TypeScript

* https://www.typescriptlang.org/docs/handbook/2/classes.html#this-types

TS does not care:

```typescript
class Box {
  content: string = "";
  sameAs(other: this): boolean {
    return other.content === this.content;
  }
}

class DerivedBox extends Box {
  otherContent: string = "?";
  sameAs(other: this): boolean {
    if (other.otherContent === undefined) {
      console.log("TS type system is broken")
    }
    return other.otherContent === this.otherContent;
  }
}


const base = new Box();
const derived = new DerivedBox();

function test(x: Box): boolean {
    return x.sameAs(base)
}

test(derived) // prints: TS type system is broken
```
