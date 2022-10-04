# Self-types design for Kotlin language

Links:
1. [YouTrack feature request](https://youtrack.jetbrains.com/issue/KT-6494)
2. [Discussion](https://discuss.kotlinlang.org/t/self-types/371) - java interoperability
3. [Discussion](https://discuss.kotlinlang.org/t/this-type/1421) - observer example
4. [Emulating self types in Kotlin](https://medium.com/@jerzy.chalupski/emulating-self-types-in-kotlin-d64fe8ea2e62)
5. [Self Types with Java’s Generics](https://www.sitepoint.com/self-types-with-javas-generics/) - good about self-types generic emulations drawbacks
6. [Self type in java plugin](https://github.com/manifold-systems/manifold)
7. [`Self` name resolve considerations (ru)](https://maximgran.notion.site/maximgran/Self-types-58e89d6dda374ba9abb4483b192a49c2)

A **self-type** refers to the type on which a method is called (more formally called the *receiver*).

We will use `Self(C)` type notation denoting self-type that is declared in class `C` (called *origin*) and has scope of class `C`.


## Motivation

Self-types can be emulated with weird boilerplate code using recursive generics and/or some additional casts. But they are needed in some useful patterns, so there can be a reason to make them a language feature. Moreover, self-types bypasses are enough cumbersome to make less suitable design choices in some cases.

Possibility to use `Self` in different positions will be discussed in the next section.

### Transformation chains

The most common example of self-types application is an abstract builder pattern. But in Kotlin builders are usually implemented via extension receivers or `apply` function (builder object should be mutable here). But if we want to construct a (monadic) transformation chain of an immutable object (or to use *prototype* architecture pattern with `clone()` method in class hierarchy), self-types are still useful:

```kotlin
abstract class Lazy<T>(val computation: () -> T) {
    abstract protected fun create(computation: () -> T): Self
    fun copy(): Self = create { computation() }
}

abstract class LazyNumber<T : Number>(computation: () -> T) : Lazy<T>(computation) {
    fun shortify(): Self = create { computation().toShort() }
}

class LazyInt(computation: () -> Int) : LazyNumber<Int>(computation) {
    // Create final class from `this` type intersection - ok (safe_create)
    override fun create(computation: () -> Int): Self = LazyInt(computation)
    fun add(n: Int): Self = create { computation() + n }
}

fun test() {
    LazyInt { 42 }
        .copy()
        .shortify()
        .add(13)
        .computation()
}
```

Sealed class implementation from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494):
```kotlin
sealed interface Data {
    data class One(var a: Int) : Data
    data class Two(var a: Int, var b: Int) : Data

    // Create final class from `this` type intersection - ok (safe_create)
    fun copy(): Self = when (this) {
        is One -> One(a)
        is Two -> Two(a, b)
    }
}

fun test() {
    val a = Data.One(1)
    val b: Data.One = a.copy() // (self_to_receiver)
}
```

Fluent assertions api [this](https://github.com/google/truth/blob/master/core/src/main/java/com/google/common/truth/Subject.java) and [this](https://github.com/assertj/assertj/blob/main/assertj-core/src/main/java/org/assertj/core/api/AbstractAssert.java) are real-world examples of transformation chains.

### Observer pattern

```kotlin
abstract class AbstractObservable {
    private val observers = mutableListOf<(Self) -> Unit>

    // Self in the input `in` generic position - ok (input_in_generic)
    fun observe(observer: (Self) -> Unit) {
        observers += observer
    }

    protected fun notify() {
        observers.forEach { observer ->
            observer(this)
        }
    }
}

class Element : AbstractObservable() {
    var color: Color = Color.Purple
        set(value: Color) {
            param = value
            notify()
        }
}

fun test() {
    val element = Element().apply {
        observe {
            println("New color = ${it.color}")
        }
    }
    element.color = Color.Blue // Observer prints new color here
    element.observe {
        // Using other Element is mistake here,
        // `it` should have `Element` type to avoid this
        println("New color with mistake = ${otherElement.color})
    }
}
```

### Recursive containers

```kotlin
// Constructor position - ok
abstract class Node(val children: List<Self>)

// Constructor position - ok
class BetterNode(children: List<Self> = emptyList()) : Node(children /* ok - covariant */) {
    fun doTheBest() = printLn(42)
}

fun test() {
    val betterTree = BetterNode(/* expected List<BetterNode> */ listOf(
        BetterNode(),
        BetterNode(listOf(BetterNode()))
    ))
    betterTree.children
        .flatMap { it.children }
        .forEach { it.doTheBest() }
}
```


## Self-type usage

Let
```kotlin
fun interface In<in T> {
    fun accept(x: T)
}

fun interface Out<out T> {
    fun produce(): T
}

fun interface Inv<T> {
    fun id(x: T): T
}
```

### Return position

```kotlin
abstract class A {
    // `this` of `A` should be assignable to `Self(A)`
    fun a(): Self = this // (this_is_self) - label to refer this example later
    fun b(): Self = apply {} // (class_is_self)

    abstract fun c(): Self
}

class B : A() {
    // `Self(B)` should be subtype of `Self(A)` to satisfy overriding conditions
    override fun c(): Self = null!! // (self_return_override)

    // `Self` of the same object should be assignable to `Self(B)`
    fun d(): Self = a() // (self_a_assign_self_b)

    fun e(): Self {
        // It is natural behavior because `Self(C)` has scope of `C`
        val b: B = a() // (self_assign_origin)

        val self: Self = b() // (denotable_self)
        return self
    }
}

fun test(a: A, b: B) {
    b.a()     // scope of type B (self_to_receiver)
    b.a().b() // scope of type B
    a.a()     // scope of type A
}
```

The following example should not compile to avoid type system hole:

```kotlin
abstract class A {
    fun a(): Self = this

    // Should not be possible to return Self of an other object
    fun f(x: B): Self = x.a() // (foreign_self)
}

abstract class B : A()

class C : B() {
    fun g() = null!!
}

fun test(b: B, c: C) {
    c.f(b) /* scope of type C */ .g() // ERROR: No g() in B
}
```

Also it may be unsafe to create new objects:

```kotlin
// (unsafe_create)
open class A {
    // 1) Creating instances OF the opened class cause problems
    fun f(): Self = A()
    // 2) Creating instances IN the opened class cause problems
    fun g(): Self = Q()
}

class Q : A() {
    fun q() = Unit
}

class P : A() {
    fun p() = Unit
}

fun test(q: Q, p: P) {
    // 1)
    q.f() /* scope of type Q */ .q() // ERROR: no q() in A
    // 2)
    p.g() /* scope of type P */ .p() // ERROR: no p() in Q
}
```

It is possible to create object of final class if it exists in the intersection type of `this`. Sealed class example from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494):

```kotlin
// (safe_create)
sealed interface Data {
    data class One(var a: Int) : Data

    data class Two(var a: Int, var b: Int) : Data {
        fun clone(): Self = Two(a, b) // create self in the final class - ok
    }

    fun copy(): Self = when (this) {
        is One -> One(a) // no cast needed here, because of smart-cast on `this`
        is Two -> Two(a, b)
    }
}

fun test() {
    val a = Data.One(1)
    val b = a.copy() // has type of `A` (self_to_receiver)
}
```

### Input position

Using `Self` in the input position for classes is not possible:

```kotlin
interface Comparable {
    operator fun compareTo(other: Self): Int
}

abstract class A(val a: Int) : Comparable {
    // The only possible bound for Self is useless Comparable
    override fun compareTo(other: Self): Int = a.compareTo(other.a)
}

class B(a: Int, val b: Int) : A(a) {
    override fun compareTo(other: Self): Int = b.compareTo(other.b)
}

fun test(c: Comparable, a: A, b: B) {
    c.compareTo(a) // Compiles
    a.compareTo(c) // Not compiles
    (b as A).compareTo(a) // ERROR: dispatches to B.compareTo, no A.b field exists
}
```

So it is principal thing that derived class should tell base, what type is needed to be implemented. Example from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494):

```kotlin
interface Comparable<in T> {
    fun compareTo(other: T): Int
}

interface Item<T : Item<T>> : Comparable<T> {
    val x: Int

    // Need to have explicitly declared bound (in generic parameter)
    override fun compareTo(other: A): Int = x - other.x
}

class A : Item<A>

fun <T : Item<T>> sortItems(items: List<Item<T>>)
```

And `Self` can be only a shortcut for a generic parameter with recursive constraint under the hood:

```kotlin
interface Item : Comparable {
   fun compareTo(other: Self): Int
   fun doSomethingElseWith(other: Self)
   ...
}

fun <T : Item> sortItems(items: List<Item<T>>)
```

So the only possibility is to hide recursive generic parameter in some positions. But generic parameter that occasionally appears is too much.

### Return generic position

```kotlin
abstract class A {
    fun a(): Self = null!!

    abstract fun f(): In<Self>

    // Safe to create object with `Self` in generic position
    fun g(): Out<Self> = object : Out<Self> {
        // Self here relates to A, not to Out. Mb write Self@A?
        override fun produce(): Self = this@A // or this@A.a()
    }

    abstract fun h3(): In<Self>
}

class B(...) : A() {
    fun b() = Unit

    fun f(): In<Self> = object : In<Self> {
        // Foreign `Self` in the input position also should be prohibited
        override fun accept(x: Self) {
            // expect x to be of type B
            x.b()
        }
    }

    // Ok to return existing object that relies on B (see `Constructor position` section)
    fun h1(): In<Self> = inInstance
    fun h2(): Inv<Self> = invInstance

    // Overriding is not possible (variance subtyping) without contravariant rule
    // B <: A => Self(A) <: Self(B).
    // But it is good, because inInstance relies on B and overriding is unsafe
    override fun h3(): In<Self> = inInstance

    fun h4(): MutableList<Self> = mutableListOf(this, this)
}

fun test(a: A, b: B) {
    a.f() /* In<A> */ .accept(/* A is required instead of B */)
    b.g().produce() /* ok, common return position mechanics */

    b.h1().accept(b /* B is expected - ok */)
    val bb: B = b.h2().id(b)

    a.h3().accept(a /* ERROR: B is expected */)

    val bs: MutableList<B> = b.h4()
    bs.add(b)
    bs.first().b()
}
```

### Input generic position

No overriding here is possible by default, if we consider that `Self(A) != Self(B)`. And it makes `out` and `inv` positions safe.

But for `in` position this restriction does not make sense in terms of safety and it is valid to resolve `Self(B)` in the input `in` generic position as `Self(A)`.

```kotlin
abstract class A {
    // ok, common return position mechanics (accepting argument instead of return)
    fun f(x: In<Self>) = x.accept(this) // (input_in_generic)
    abstract fun g(x: Out<Self>)
}

class B : A() {
    fun b() = Unit

    // Override prohibited: Self(B) != Self(A)
    override fun g(x: Out<Self>) {
        // expect x to be of type B
        x.produce().b()
    }
}

fun test(a: A, b: B) {
    b.f { b.b() }
    a.g { a /* ERROR: A has no B.b */ }
}
```

### Constructor position

Only `out` generic position is allowed.

```kotlin
open class A(val x: Self?)
class B(x: Self?) : A(x /* subtyping - ok */)

fun test() {
    val a = A(/* requires `A?` */ A(null))
    val b = B(/* requires `B?` */ B(null))
}
```

```kotlin
abstract class A {
    abstract val x: Out<Self>?
}

class B(override val x: Out<Self>?)
```

Other projections are unsafe in open classes and prohibited by subtyping:

```kotlin
open class A(val x: In<Self>)
class B(x: In<Self>) : A(x /* error - contravariant */)
// or
abstract class A {
    abstract val x: In<Self>
}
class B(override val x: In<Self> /* error - contravariant */)

fun test() {
    val a: A = B { it as B }
    a.x.accept(a /* ERROR: b expected */)
}
```


## Implementation

There are three approaches to implement self-types:
1. Direct implementation - using recursive generics under the hood
2. Magic implementation - `Self` is a special type with it's own behavior
3. Implementation via *abstract type members* (*associated types*)

### Direct implementation

Direct self-types implementation adds recursive generic parameter implicitly and substitutes it instead of `Self` type marker.

Let's consider translated code, let `I` be generated type parameter:

```kotlin
open class A<I : A<I>> {
    fun f(): I = this /* add cast to I */
}

// Need to generate no-generic class to use A as usual
// and substitute it instead of `A` automatically.
// `A` should be open.
class A_ : A<A_>

class B<I : B<I>> : A<I>

// Should make B open
class B_ : B<B_>

fun test(b: B /* automatically add <B_> */) {
    val a_ = A() // Need to substitute <A_>
    (b as A /* add <A_> */).f() as B /* substitute <B_> */
}
```

Or approach of using generic methods:

```kotlin
open class A {
    // Source
    fun f(): Self = this

    // Generated instead
    fun <I : A> f(): I = this /* as I */
}

class B : A() {
    fun <I : B> g(b: B): I = b.f() /* need to prohibit it somehow */
}

fun test(b: B) {
    b.f() /* substitute <B> */
}
```

Looks like direct approach only creates problems but does not clearly solve any (except Java interoperability).

### Magic implementation

Another approach is to introduce special `Self` type and write down rules of its behavior. General idea is to substitute receiver type instead of `Self` on function call resolve.

It looks like using implicit generic parameters for methods and receiver type substitution similar to direct approach. However, magic `Self` type gives much more control to permit or prohibit different behaviors. This analogy is not an implementation guide, but an idea that self-types from this point of view do not bring us out from existing type system kind.

#### (self_return_override)

To support override for methods with self-type in the return position the following rule should be used:
```
B <: A => Self(B) <: Self(A)
```

#### (this_is_self)

We should change type of `this` (e.g. from `A` class) from `A` to `Self(A)`. We are not allowed to use rule `A <: Self(A)` instead because of reasons that will be discussed in the **(foreign_self)** section.

#### (self_assign_origin)

It should be possible to assign `Self(A)` to its origin (`A`). So we add rule:
```
B <: A => Self(B) <: A
```

#### (class_is_self)

Dispatch receiver in class (`C`) should have `Self(C)` type.

#### (self_to_receiver)

When method from class `A` (`B <: A`) that returns self-type is called on `b: B`, `Self(A)` should be replaced with `B` at the resolve phase.

Note that we do not replace `Self(A)` with `Self(B)` here. There are important reasons for it that will be discussed in the **(foreign_self)** section.

#### (self_a_assign_self_b)

Let `b: () -> Self` be a method of class `B`, `B <: A`. Let `a: () -> Self` be a method of class `A`. When `a` is called inside declaration of `B` on the current object, `Self(A)` should be replaced with `Self(B)` (note: not `B`).

#### (foreign_self), (unsafe_create)

Remember that it is mistake to allow `Self` from other object be assignable to `Self` of the currently declared one. Note that rules described above do not allow this:
* Rule `B <: A => B <: Self(A)` does not exist
* All self-types turn into self-types only if method was called on `this` of current class declaration
* Any other self-types turn into the type of a receiver
* Self-type is not denotable outside the class declaration

#### (safe_create)

This usecase can be solved by its own rule:
```
is_final A, A \in intersection this => A <: Self(A)
```

#### Generic positions

For generic positions everything is the same.

#### JVM interoperability

Self-type in byte code should be represented as it's origin type plus kotlin metadata.

Overriding methods with self-types in java should be prohibited:
```kotlin
// Kotlin
open class A {
    open fun f(): Self = this
}
class B : A()

// Java
class C : A {
    @Override
    B f() { return B() }
    void g() {}
}

// Kotlin
fun test(c: C) {
    c.f() /* scope of C */ .g() // ERROR: expected C, got B
}
```

It could be done in several ways:
* Make ctors of class with self-types synthetic
   * Adding self-type breaks source compatibility
* Make methods with self-types synthetic
   * Refactoring A -> Self breaks source compatibility

### Abstract type members

TODO

## Other languages experience

### Swift

* https://docs.swift.org/swift-book/ReferenceManual/Types.html#grammar_self-type
* https://www.swiftbysundell.com/tips/using-self-to-refer-to-enclosing-types/
* https://docs.swift.org/swift-book/LanguageGuide/Generics.html

Plain return positions behave as expected. Self-type from the other object is prohibited:
`cannot convert return expression of type 'C' to return type 'Self'`.

```swift
protocol A {
    func f() -> Self
    func g() -> Self
}

class B: A {
    func f() -> Self { print("B.f"); return h() }
    func g() -> Self { print("B.g"); return self }
    func h() -> Self { print("B.h"); return self }
}

class C: B {
    override func g() -> Self { print("C"); return f() }
}

let c = C()
c.f().h().g()
// (B.f, B.h), (B.h), (C.g, B.f, B.h)
```

But in other positions `Self` is available only in protocols and class declaration should use itself instead of `Self`:

```swift
// Self is not available as a input parameter in the class
// class D {
//     func id(x: Self) -> Self { return x }
// }

protocol E {
    func f(x: Self) -> Self
}

// error: protocol 'E' can only be used as a generic constraint because it has Self or associated type requirements
// func test(x: E) {}

class F: E {
    // x is not Self anymore
    // func f(x: F) -> Self { return x }

    func f(x: F) -> Self { return self }
}

class G: F {
    // x type is already fixed in F
    // override func f(x: H) -> Self { return self }
    override func f(x: F) -> Self { return self }
}

protocol H {
    func g(xs: Array<Self>) -> Array<Self>
}

// class I: H {
//     // protocol 'H' requirement 'g(xs:)' cannot be satisfied by a non-final class
//     // ('I') because it uses 'Self' in a non-parameter, non-result type position
//     func g(xs: Array<I>) -> Array<I> { return xs }
// }

final class J: H {
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

Also `Swift` supports associated types and they can be used to achieve similar behavior:
```swift
protocol A {
    associatedtype S
    func f() -> S
    func g(x: S)
    func h() -> Array<S>
}

class B : A {
    func f() -> B { return self }
    func g(x: B) {}
    func h() -> Array<B> { return [self] }
}

class C : B {
    override func f() -> C { return self }
    // error: method does not override any method from its superclass
    // override func g(x: C) {}
    // error: method does not override any method from its superclass
    // override func h() -> Array<C> { return [self, self] }
}
```

### Scala

* https://docs.scala-lang.org/tour/abstract-type-members.html
* https://github.com/lampepfl/dotty/issues/7374

TODO

### Dynamic languages

TODO

## Magic Kotlin prototype

https://github.com/winter-yuki/kotlin/pull/2

TODO

## Other design questions

TODO
