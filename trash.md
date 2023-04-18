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


### Is additional modifier (annotation) for class needed?

> For backwards compatibility, JVM-interoperability, and ABI-stability purposes, the final design might call for marking any open class or interface that uses Self types with some new modifier. This is perfectly fine. It still makes the resulting code more readable than with recursive generics.
