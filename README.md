# Self-types design for Kotlin language

Links:
1. [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494)
2. [Discussion](https://discuss.kotlinlang.org/t/self-types/371)
3. [Discussion](https://discuss.kotlinlang.org/t/this-type/1421)
4. [Emulating self types in Kotlin](https://medium.com/@jerzy.chalupski/emulating-self-types-in-kotlin-d64fe8ea2e62)
5. [Self Types with Java’s Generics](https://www.sitepoint.com/self-types-with-javas-generics/) - good about self-types generic emulations drawbacks
6. [Self type in java plugin](https://github.com/manifold-systems/manifold)

## Definition

A **self-type** refers to the type on which a method is called (more formally called the receiver).

### Return position

```kotlin
abstract class A {
    // `this` of `A` should be assignable to `Self(A)`
    fun a(): Self = this
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
        else -> null!!
    }
}

fun test() {
    val a = Data.One(1)
    val b = a.copy() // has type of `A`
}
```

### Input position

Using `Self` in the input position looks meaningless:

```kotlin
interface Comparable {
    operator fun compareTo(other: Self): Int
}

open class A(val a: Int) : Comparable {
    override fun compareTo(other: Self): Int = a.compareTo(other.a)
}

class B(a: Int, val b: Int) : A(a) : Comparable {
    override fun compareTo(other: Self): Int = b.compareTo(other.b)
}

fun test(a: A, b: B, c: Comparable) {
    c.compareTo(a) // Compiles
    a.compareTo(c) // Not compiles

    (b as A).compareTo(a) // ERROR: dispatches to B.compareTo, no A.b field exists
}
```

The only way to use `Self` in the input position is to use it as a placeholder for the first instance type:

```kotlin
interface A {
    fun f(x: Self)
}

abstract class B : A {
    override fun f(x: B /* use concrete type */) = Unit
}

class C : B() {
    override fun f(x: B /* no freedom here */) = Unit
}
```
