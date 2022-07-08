# kotlin-self-types

Self types design for Kotlin language

> A self type refers to the type on which a method is called (more formally called the receiver).

Links:
1. [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494)
2. [Discussion](https://discuss.kotlinlang.org/t/self-types/371)
3. [Discussion](https://discuss.kotlinlang.org/t/this-type/1421)
4. [Emulating self types in Kotlin](https://medium.com/@jerzy.chalupski/emulating-self-types-in-kotlin-d64fe8ea2e62)
5. [Self Types with Java’s Generics](https://www.sitepoint.com/self-types-with-javas-generics/) - good about self-types generic emulations drawbacks
6. [Self type in java plugin](https://github.com/manifold-systems/manifold)

## Motivation

There are cases when derived type should be available in the declaration of the base. It can be solved with weird boilerplate code with recursive generics and/or some additional casts.
The solution can be to provide some type identifier for the user in the base class (such as `Self` or `This`) that refers to the derived one.

Here are possible positions for the `Self` type:
1. Input position: `fun f(x: Self)`
2. Input generic position as `in`/`out`/`invariant` parameter: `fun f(xs: C<Self>)`
3. Output position: `fun f(): Self`
4. Output generic position as `in`/`out`/`invariant` parameter: `fun f(): C<Self>`
5. Inside method: `val x: Self`, `val xs: C<Self>`
6. In declaration of abstract property/function (can be additional possibilities in first implementation)
7. Extension methods

TODO motivation for each position

TODO Stream API examples

TODO a lot of recursive generics [assertj-core](https://github.com/assertj/assertj-core/tree/2c5f011d3c99d86f5d42a743a28238440729ae7f/src/main/java/org/assertj/core/api)

TODO [example interpreter](https://youtrack.jetbrains.com/issue/KT-49752/Regression-in-method-return-type-inference-IllegalStateException-Expected-some-types)

### Input position

```kotlin
interface Comparable<in T> {
    fun compareTo(other: T): Int
}
```

```kotlin
class MyClass : Comparable<MyClass> { ... }
```

```kotlin
interface Item<T : Item<T>> : Comparable<T> {
   fun compareTo(other: T): Int
   fun doSomethingElseWith(other: T)
   ...
}
```

And this pattern spread all over the code:
```kotlin
fun <T : Item<T>> sortItems(items: List<Item<T>>)
```

Proper solution can be the following:
```kotlin
interface Item : Comparable {
   fun compareTo(other: Self): Int
   fun doSomethingElseWith(other: Self)
   ...
}

fun <T : Item> sortItems(items: List<Item<T>>)
```

### Out position

```kotlin
sealed class Data {
    data class One(var a: Int) : Data()
    data class Two(var a: Int, var b: Int) : Data()

    // this shall typecheck
    fun copy(): Self = when(this) {
        is One -> One(a) // no cast needed here, because of smart-cast on `this`
        is Two -> Two(a, b)
    }
}

fun test() {
    val a = One(1)
    val b = a.copy() // has type of `A`
}
```

<!-- ### Handy architectural patterns

TODO builder, prototype, etc

## Implementation variants and questions

TODO -->

<!--
1. Interop with Java
2. `Self` as a generic parameter
3. To which type exactly `Self` should be resolved (in long inheritance hierarchy)
4. What if java will support self-types itself?

TODO

### Handle java `Comparable` automatically

TODO

### Handle java `Cloneable`

TODO

### Is additional modifier (annotation) for class needed?

> For backwards compatibility, JVM-interoperability, and ABI-stability purposes, the final design might call for marking any open class or interface that uses Self types with some new modifier. This is perfectly fine. It still makes the resulting code more readable than with recursive generics.

TODO

### Is it possible to provide `Self` manually?

TODO

### Should `this` have `Self` type?

TODO

### `Self` or `This`?

TODO

### `Self` identifier priority and visibility

TODO

### Jvm, java interoperability

TODO -->

## Other languages experience

### Swift

* https://docs.swift.org/swift-book/ReferenceManual/Types.html#grammar_self-type
* https://www.swiftbysundell.com/tips/using-self-to-refer-to-enclosing-types/

Note: Protocols in Swift are not ordinary types as interfaces in Kotlin (this can matter).

`Self` is always available as an output parameter with obvious behavior:

```swift
protocol A {
    func f() -> Self
    func g() -> Self
}

class B: A {
    func f() -> Self { print("B"); return self }
    func g() -> Self { print("B"); return self }
    func h() -> Self { print("B"); return self }
}

class C: B {
    override func g() -> Self { print("C"); return self }
}

print("- ba")
let ba: A = B()
// let _: ba.f()

print("- bb")
let bb: B = B()
let _: B = bb.f()
let _: B = bb.g()

print("- ca")
let ca: A = C()
let _: A = ca.f()
let _: A = ca.g()
// let _: B = ca.f()

print("- cb")
let cb: B = C()
let _: B = cb.f()
let _: B = cb.g()

print("- cc")
let cc: C = C()
let _: C = cc.f()
let _: C = cc.g()
let _: C = cc.h()
```

But in other positions `Self` is available only in protocols and class implementation should use this class itself instead of `Self`:

```swift
// Self is not available as a input parameter in the class
// class D {
//     func id(x: Self) -> Self { return x }
// }

protocol E {
    func f(x: Self) -> Self
}

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
//     // protocol 'G' requirement 'g(xs:)' cannot be satisfied by a non-final class
//     // ('H') because it uses 'Self' in a non-parameter, non-result type position
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

### Python

https://peps.python.org/pep-0673/

```python
from typing import Self

class Shape:
    def set_scale(self, scale: float) -> Self:
        self.scale = scale
        return self
```

is treated equivalently to:
```python
from typing import TypeVar

SelfShape = TypeVar("SelfShape", bound="Shape")

class Shape:
    def set_scale(self: SelfShape, scale: float) -> SelfShape:
        self.scale = scale
        return self
```

Same for the subclass:
```python
class Circle(Shape):
    def set_radius(self, radius: float) -> Self:
        self.radius = radius
        return self
```

which is treated equivalently to:
```python
SelfCircle = TypeVar("SelfCircle", bound="Circle")

class Circle(Shape):
    def set_radius(self: SelfCircle, radius: float) -> SelfCircle:
        self.radius = radius
        return self
```

### Typescript

https://www.typescriptlang.org/docs/handbook/2/classes.html#this-types

TODO

### OCaml

https://v2.ocaml.org/manual/objectexamples.html#s%3Areference-to-self

TODO

### Scala

* https://docs.scala-lang.org/tour/self-types.html
* https://github.com/lampepfl/dotty/issues/7374

TODO

## Out position implementation roadmap

### 1. Resolve `Self` as a return user type

TODO

### 2. Infer `this` type as `Self`

TODO

### 3. Infer `Self` as an implicit return type

TODO

### 4. Resolve `Self` in method bodies

TODO

### 5. Smartcast `Self` at call site

TODO

### 6. Provide necessary info to backend

TODO

### 7. Enhance error messages

TODO

### 8. Java compatibility

TODO

### 9. Js compatibility

TODO

### 10. Native compatibility

TODO
