# Self-types design for Kotlin language

Links:
1. [YouTrack feature request](https://youtrack.jetbrains.com/issue/KT-6494)
2. [Discussion](https://discuss.kotlinlang.org/t/self-types/371) - java interoperability
3. [Discussion](https://discuss.kotlinlang.org/t/this-type/1421) - observer example
4. [Emulating self types in Kotlin](https://medium.com/@jerzy.chalupski/emulating-self-types-in-kotlin-d64fe8ea2e62)
5. [Self Types with Java’s Generics](https://www.sitepoint.com/self-types-with-javas-generics/) - good about self-types generic emulations drawbacks
6. [Self type in java plugin](https://github.com/manifold-systems/manifold)
7. [`Self` name resolve considerations (ru)](https://maximgran.notion.site/maximgran/Self-types-58e89d6dda374ba9abb4483b192a49c2)

## Definition

A **self-type** refers to the type on which a method is called (more formally called the receiver).

### Return position

```kotlin
abstract class A {
    // `this` of `A` should be assignable to `Self(A)`
    fun a(): Self = this // (this_is_self) - label to refer this example later
    fun b(): Self = apply {}

    abstract fun c(): Self
}

class B : A() {
    // `Self(B)` should be subtype of `Self(A)` to satisfy overriding conditions
    override fun c(): Self = null!!

    // `Self` of the same object should be assignable to `Self(B)`
    fun d(): Self = a()
}

fun test(a: A, b: B) {
    b.a()     // scope of type B
    b.a().b() // scope of type B
    a.a()     // scope of type A
}
```

The following example should not compile to avoid type system hole:

```kotlin
abstract class A {
    fun a(): Self = this

    // Should not be possible to return Self of other object
    fun f(x: B): Self = x.a()
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
    val b = a.copy() // has type of `A`
}
```

### Input position

Using `Self` in the input position for classes is not possible:

```kotlin
interface Comparable {
    operator fun compareTo(other: Self): Int
}

abstract class A(val a: Int) : Comparable {
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
}

abstract A : Item<A>

class B : A() {
    override fun fun compareTo(other: A): Int = x - other.x
}

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

### Return generic position

`Self` can only be used in `out` position:

```kotlin
interface In<in T> {
    fun accept(x: T)
}

interface Out<out T> {
    fun produce(): T
}

interface Inv<T> {
    fun id(x: T): T
}

abstract class A {
    abstract fun f(): In<Self>

    fun g(): Out<Self> = object : Out<Self> {
        override fun produce(): Self = this@A
    }
}

class B : A() {
    fun b() = Unit

    fun f(): In<Self> = object : In<Self> {
        override fun accept(x: Self) {
            // expect x to be of type B
            x.b()
        }
    }

    fun h(): Inv<Self> = object : Inv<Self> {
        fun id(x: Self): Self {
            // expect x to be of type B
            x.b()
        }
    }
}

fun test(a: A, b: B) {
    a.f() /* In<A> */ .accept(/* A is required instead of B */)
    b.g().produce() /* ok, common return position mechanics */
}
```

### Input generic position

`Self` can only be used in `in` position:

```kotlin
interface In<in T> {
    fun accept(x: T)
}

interface Out<out T> {
    fun produce(): T
}

// Similar to Out here
interface Inv<T> {
    fun id(x: T): T
}

abstract class A {
    // ok, common return position mechanics (accepting argument instead of return)
    fun f(x: In<Self>) = x.accept(this)
    abstract fun g(x: Out<Self>)
}

class B : A() {
    fun b() = Unit

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

## Motivation

Self-types can be emulated by weird boilerplate code with recursive generics and/or some additional casts.

### Transformation chains

The most common example of self-types application is abstract builder pattern. But in Kotlin builders are usually implemented via extension receivers or `apply` function (builder object should be mutable here). But if we want to construct a transformation chain of an immutable object (or use *prototype* architecture pattern with `clone()` method in class hierarchy), self-types are still useful:

```kotlin
open class Lazy<out T>(val computation: () -> T) {
    fun clone(): Self = Lazy { computation() }
}

open class LazyNumber<out T : Number>(computation: () -> T) : Lazy<T>(computation) {
    fun shortify(): Self = LazyNumber { computation().shortValue() }
}

class LazyInt(computation: () -> Int) : LazyNumber<Int>(computation) {
    fun add(n: Int): Self = LazyInt { computation() + n }
}

fun test() {
    LazyInt { 42 }
        .clone()
        .shortify()
        .add(13)
        .computation()
}
```

Fluent assertions api [this](https://github.com/google/truth/blob/master/core/src/main/java/com/google/common/truth/Subject.java) and [this](https://github.com/assertj/assertj/blob/main/assertj-core/src/main/java/org/assertj/core/api/AbstractAssert.java) are real-world examples of transformation chains.

### Observer pattern

```kotlin
abstract AbstractObservable {
    private val observers = mutableListOf<(Self) -> Unit>

    // Self in the input generic position - ok
    fun observe(observer: (Self) -> Unit) {
        observers += observer
    }

    protected fun notify() {
        observers.forEach { observer ->
            observer(this)
        }
    }
}

class Element : Observable {
    var color: Color = Color.Purple
        set(value: Color) {
            param = value
            notify()
        }
}

fun test() {
    val element = Element().apply {
        observe {
            printLn("New color = ${it.color}")
        }
    }
    element.color = Color.Blue
}
```

### Recursive containers

```kotlin
// Return out generic position - ok
open class Node(val children: List<Self>)

class BetterNode(children: List<BetterNode>) : Node(children) {
    fun doTheBest() = printLn(42)
}

fun test(betterTree: BetterNode) {
    betterTree.children
        .flatMap { it.children }
        .forEach { it.doTheBest() }
}
```

## Implementation

There are three approaches to implement self-type behavior:
1. Direct implementation - using recursive generics under the hood
2. Magic implementation - Self is a special type with it's own behavior
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

Looks like direct approach only creates problems but does not clearly solve any.

### Magic implementation

TODO

### Abstract type members

TODO

## Example implementations

### Swift

TODO

### Scala

TODO

### Dynamic languages

TODO

## Magic Kotlin prototype

https://github.com/winter-yuki/kotlin/pull/2

TODO

## Other design questions

TODO
