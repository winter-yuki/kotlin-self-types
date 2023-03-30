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

A **self-type** in method signature refers to the type on which the method is called (more formally called the *receiver*).

We will use `Self(C)` type notation denoting self-type that corresponds to a declaration receiver type `C` (called *origin*). `Self(C)` has user scope of class `C`. Replacement of self-type with exact receiver type on method call-site is called *landing*.

```kotlin
abstract class A
class B : A()

fun A.foo(): Self /* Self(A) */ = this

fun test(b1: B) {
    // `Self(A)` lands to `B`
    val b2: B = b1.foo()
}
```


## Motivation

Self-types can be emulated with weird boilerplate code using recursive generics and/or some additional casts. However, they are needed in some useful patterns, so there can be a reason to make them a language feature. Moreover, self-types bypasses are enough cumbersome to make programmer choose less suitable design choices in some cases.

### Transformation chains

The most common example of self-types application is an [abstract builder pattern](https://medium.com/@hazraarka072/fluent-builder-and-powering-it-up-with-recursive-generics-in-java-483005a85fcd). Nevertheless, in Kotlin builders are usually implemented via extension receivers or `apply` function (builder object should be mutable here). Although, if we want to construct a transformation chain of an immutable object (or to use *prototype* architecture pattern with `clone()` method in class hierarchy), self-types are still useful.

#### Persistent collections

Modification methods of a persistent data structure do not modify a collection itself but create a modified new one. To modify such collections in fluent style using methods of the base classes, [recursive generics](http://web.archive.org/web/20130721224442/http:/passion.forco.de/content/emulating-self-types-using-java-generics-simplify-fluent-api-implementation) should be used, alternatively derived class should declare abstract overrides ([kotlinx.immutable](https://github.com/Kotlin/kotlinx.collections.immutable/blob/d7b83a13fed459c032dab1b4665eda20a04c740f/core/commonMain/src/ImmutableList.kt#L66)) for all modification methods with more specific return types.

However, recursive generics are cumbersome and they infect the code that uses them:

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

Having a self-type feature, this code looks much simpler:

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

Also, there is no compiler control over such abstract overrides, so developer can easily add new modification methods in the base class and may forget to add abstract overrides to all the derived classes.

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

### Abstract factory

```kotlin
abstract class Element<out Factory>(val factory: Factory)

interface Factory<out Self : Factory<Self>> {
    fun create(): Element<Self>
}

abstract class SpecificFactory<out Self : SpecificFactory<Self>> : Factory<Self> {
    abstract fun doSpecific()
}

class ConcreteFactory : SpecificFactory<ConcreteFactory>() {
    override fun create(): Element<ConcreteFactory> = object : Element<ConcreteFactory>(this) {}
    override fun doSpecific() = println("Soo concrete!")
}

fun <Factory : SpecificFactory<Factory>> test(entity: Element<Factory>) {
    entity.factory.doSpecific()
}
```

### Abstract observable

```kotlin
abstract class AbstractObservable<out Self : AbstractObservable<Self>> {
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

class Entity : AbstractObservable<Entity>() {
    var color: Color by observable(Color.Purple)
}

fun main() {
    val entity = Entity().apply {
        observe { // Convenient to have `it: Element` here
            println("New color = ${it.color}")
        }
    }
    entity.color = Color.Blue // Observer prints new color here
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


## Design

Self-type behaves similar to the corresponding covariant recursive generic parameter that is bounded with origin. The only advantage of the explicit generic parameter is the possibility of using it with `@UnsafeVariance` in contravariant and invariant positions. But there are no safe useful applications known.

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

### `Self` origin and labels

`Self` origin is the nearest declaration receiver (excluding context receivers):
```kotlin
class C {
    fun foo(): Self /* (C) */ = this
    fun B.bar(): Self /* (B) */ = this
}

fun B.baz(): Self /* (B) */ = this
```

Labeled self-type could be problematic in designing and implementing them because it is not obvious when to land `Self` to an actual receiver type:
```kotlin
class C {
    fun A.foo(): Self@C       /* (C) */ {
        fun B.bar(): Self@C   /* (C) */ = this@C
        fun B.baz(): Self@foo /* (A) */ = this@foo
        return B().bar() /* C or Self(C)? */
    }

    fun foo(c: C): Self {
        with(c) {
            return A().foo() /* C or Self(C)? */
        }
    }
}
```

Labels can be used to refer to the outer class:
```kotlin
class Outer {
    inner class Inner {
        // There are no use cases known yet
        fun getOuter(): Self@Outer = this@Outer
    }

    fun out(): Out<Self> = object : Out<Self> {
        override fun produce(): Self@Outer = this@Outer
    }
}
```

### Assignability issue

Only `this` that refers to the function receiver should be assignable to the self-type with the corresponding origin, otherwise self-type landing makes type system unsound:
```kotlin
abstract class A {
    fun self(): Self = this // This is assignable to Self

    // Should not be possible to return Self of an other object
    fun unsafe(a: A): Self = a.self()
}

class B : A() {
    fun bOnly() = null!!
}

fun test(a: A, b: B) {
    b.unsafe(a) /* scope of type B */ .bOnly() // ERROR
}
```

### New instances

Also it may be unsafe to create new objects:
```kotlin
open class A {
    // 1) Creating instances OF the opened class cause problems
    fun newA(): Self = A()
    // 2) Creating instances IN the opened class cause problems
    fun newQ(): Self = Q()
}

class Q : A() {
    fun qOnly() = Unit
}

class P : A() {
    fun pOnly() = Unit
}

fun test(q: Q, p: P) {
    // 1)
    q.newA() /* scope of type Q */ .qOnly() // ERROR: having A
    // 2)
    p.newQ() /* scope of type P */ .pOnly() // ERROR: having Q
}
```

It is only possible to assign new object of class `C` to self-type `Self(C)` instead of `this@decl` (relating to the declaration receiver) if the following restrictions satisfied:
1. `C` is final;
2. Type of `this@decl` w.r.t. flow typing equals to `C` or it is an intersection type with `C`;
3. `C` is declared in the same module with call-site.

Sealed class example from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494):

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
    val b = a.copy() // has type of `A` (self_to_receiver)
}
```

Third restriction is needed to avoid source compatibility break making class open. Assume that we have same `Data` interface in a library except that a `copy` is an client's extension method. Then a new library version makes class `Two` open. Because of that client is no longer able to return `Two(a, b)` as a self-type.

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

    fun e(): Self {
        // It is natural behavior because `Self(B)` has scope of `B`
        val b: B = a()
        // `Self` should be denotable in bodies also
        val self: Self = b()
        return self
    }
}

fun A.topLevel(): Self = this

fun test(a: A, b: B) {
    b.a()        // scope of type B
    b.a().b()    // scope of type B
    a.a()        // scope of type A
    b.topLevel() // scope of type B
}
```

### Input position

Having self-types available in the input positions is desired (e.g. to abstractly express algebras with binary operations) but complicated.

Strait forward design is not possible with type system soundness preservation:
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
    c.compareTo(a)        // Compiles
    a.compareTo(c)        // Not compiles due to self-type landing
    (b as A).compareTo(a) // ERROR: dispatches to B.compareTo, no A.b field exists
}
```

So it is principal thing that derived class should tell base, what type bound should input parameter have. Example from [YouTrack](https://youtrack.jetbrains.com/issue/KT-6494):
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

fun <T : Item<T>> sortItems(items: List<Item<T>>): List<Item<T>> = null!!
```

Swift language introduces some additional restrictions that make it possible to use self-type in the non-return positions (and in other non-return positions as well) in protocols (Swift review is below):
* No default implementation in interfaces (protocols in terms of Swift);
* Its implementation in class `C` should replace `Self` with `C` in the definition;
* Methods with `Self` type in the input position can be called only on non-abstract classes, the abstract ones can only be used as generic constraints.

```kotlin
interface Semigroup {
    fun add(other: Self): Self
}

value class Add(val value: Int) : Monoid {
    override fun add(other: Add): Self = Add(value + other.value)
}

fun addMany(ini: Semigroup, vararg xs: Semigroup): Semigroup =
    xs.fold(ini) { acc, x -> acc.add(x) /* Cannot be called on interface */ }

fun <T: Semigroup> addMany(ini: T, vararg xs: T): T =
    xs.fold(ini) { acc: T, x: T -> acc.add(/* T expected */ x) }
```

However, interfaces are not able to express zero-arity functional symbols (constants). Traits suit better for this purpose. There hopefully will be a possibility to use them via context receivers.

### Return generic position

#### Covariant

It is safe to use `Self` in return covariant position as it is safe for covariant class type parameter.

```kotlin
class Entity<out F : Factory>(val factory: F)

interface Factory {
    fun create(): Entity<Self>
}

class ConcreteFactory : Factory<ConcreteFactory> {
    // Overriding ok: ConcreteFactory <: Factory => Self(ConcreteFactory) <: Self(Factory)
    override fun create(): Entity<Self> = Entity(this)

    fun doConcrete() = println("So concrete")
}

fun test(factory: ConcreteFactory) {
    val entity: Entity<ConcreteFactory> = factory.create()
    entity.factory.doConcrete()
}
```

#### Contravariant & invariant

There are same problems as for input position:
```kotlin
abstract class Base {
    abstract fun createConsumer(): In<Self>

    abstract val invariant: MutableList<Self>
    abstract fun touchAll()
}

class Derived {
    fun derivedOnly() = null!!

    // Overriding fails without type equality Self(Base) ~ Self(Deriving)
    override fun createConsumer(): In<Self> = object : In<Self> {
        // Foreign `Self` in the input position also should be prohibited
        override fun accept(x: Self@Derived) {
            x.derivedOnly()
        }
    }

    override val invariant = mutableListOf(this, this)
    override fun touchAll() = invariant.forEach { it.derivedOnly() }
}

fun test() {
    val b: Base = Derived()
    b.createConsumer().accept(Base()) // ERROR

    b.invariant.add(Base())
    b.touchAll() // ERROR
}
```

There is also the Swift approach with aforementioned restrictions. It is still rather complicated and have no reasonable use-cases.

### Input generic position

No overriding here is possible by default, if we consider that `Self(A) != Self(B)`. But this restriction does not make sense for contravariant input generic self-type position.

```kotlin
abstract class Base {
    // Ok, common return position mechanics (accepting argument instead of return)
    fun poll(consumer: In<Self>) = consumer.accept(this)

    abstract fun acceptProducer(producer: Out<Self>)
}

class Derived : Base() {
    fun derivedOnly() = null!!

    // Override prohibited: Self(B) != Self(A)
    override fun acceptProducer(producer: Out<Self>) {
        producer.produce().derivedOnly()
    }
}

fun test() {
    val d = Derived()
    d.poll { it.derivedOnly() }

    val b: Base = d
    b.acceptProducer { b } // ERROR
}
```

### Constructor position

```kotlin
open class A(val x: Self?)
class B(x: Self?) : A(x)

fun test() {
    val a = A(/* requires `A?` */ A(null))
    val b = B(/* requires `B?` */ B(null))
}
```

#### Generic covariant position

```kotlin
abstract class A {
    abstract val x: Out<Self>?
}

class B(override val x: Out<Self>?)
```

#### Generic contravariant & invariant

Contravariant and invariant self-type positions are the same as if `Self` was a generic parameter:
```kotlin
class A(/* mb private val */ x: In<Self>)
```

### Extension function position

Self-type behaves as generic with receiver constraint:
```kotlin
fun A.f(x: Self, producer: Out<Self>, consumer: In<Self>): Self = null!!
// same as
fun <T : A> T.f(x: T, producer: Out<T>, consumer: In<T>): T = null!!
```

Origin can also be generic type or an instantiated type ctor:
```kotlin
fun <T> T.f(x: T, y: Self): Pair<Self, Self> = x /* error: T !<: Self(T) */ to this
fun <T> List<T>.shuffle(): Self = null!!
```

Self-type's origin is always not-nullable:
```kotlin
fun A?.f(x: Self): Self? = this?.doSomething(x)
// same as
fun <T : A> T?.f(x: T): T? = this?.doSomething(x)
```


## Self-types specification

The main danger with self-types is that its landing to a receiver type could be able to make type system unsound (like TypeScript's described below). To achieve safety three things should be properly defined: *safe-values*, *safe-positions* and *safe-calls*. First two represent safety induction base and the last one - induction step.

Let `this@decl` relate to the declaration receiver and has type `D` w.r.t. flow typing.

Self-type's origin is a non-nullable declaration receiver.

### Safe-values

It is needed to emphasize values that should be typed as `Self(C)`. They are:
1. `this@decl`;
2. `C` constructor call in case of rules being conformed (described in design section):
  2.1 `C` is final;
  2.2 `C ~ D` or `C in D` if `D` is an intersection type;
  2.3 `C` is declared in the same module with call-site.

Subtyping rules are (self-type nullability handling is obvious):
1. `B <: A <=> Self(B) <: Self(A)` to support override for methods with self-type in the return position;
2. `B <: A <=> Self(B) <: A` to be able to assign value to its self-type origin (`val a: A = this`);
3. `Nothing <: Self(A)` and `Self(A) <: Any`;
4. `B !<: Self(A)` if `B` does not fit rules (1) and (3).

Rule (4) guarantees that only values considered safe may have self-type.

TODO

<!-- Having subtyping rules we can deduce following:
* `superTypeOf(Self(A)) ~ A`;
* `LUB(Self(A), Self(A)) ~ Self(A)`
* `B <: A => LUB(Self(B), Self)

(Common) Super type (C)ST:
* `ST(Self(A)) ~ A`
* `CST(Self(A), Self(A)) ~ Self(A)`

TODO CST(Self(A), Self(B)) ~ ???, используя определение CST и моего `<:` понять что за `???`. Разные варианты подтипизации `A` и `B` (подтип и нет). -->

<!-- ### Safe-positions

Self-type [positions](https://kotlinlang.org/spec/declarations.html#type-parameter-variance):
* If `C` is a dispatch receiver then `Self(C)` can be used only in covariant positions.
* If `C` is a extension receiver then `Self(C)` can be used in all positions.

Self-type [capturing](https://kotlinlang.org/spec/type-system.html#type-capturing) :
* If `C` is a dispatch receiver then `Self(C)` behaves as a covariant type argument:
  * For a covariant type parameter `out F` captured type `K <: Self(C)`;
  * For invariant or contravariant type parameter `K` is ill-formed type.
* If `C` is a extension receiver then `Self(C)` behaves as invariant type argument.
 -->

<!-- TODO

### Safe-calls

TODO

### Java interoperability

TODO

### Js interoperability

TODO

with self-type evaluates to the valid safe-value:
* **Safe values** that are typed as `Self(C)` (induction base):
  * `this` that refers to the declaration receiver;
  * New object with type `C`: `C` is final && (`C == typeOf(this)` || `C in typeOf(this)`) where `in` is presence in type intersection (TODO same module);
* **Safe calls** (induction step): self-type always lands to the type of the receiver. And it lands to other self-type if and only if type of the receiver is self-type. By induction hypothesis we know that receiver is safe and such a call can return only a safe value.

TODO примеры с intersection и flexible для <: и CST. -->


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
    func h(c: COut) -> Self { print("BOut.h"); return c.g() }
}

class COut: BOut {
    override func g() -> Self { print("COut"); return f() }
}

func test1(c: COut) -> COut {
    return c.f().g()
}
```

Swift prohibits using new object where `self` is expected:
```swift
final class NewSelf {
    // error: cannot convert return expression of type 'NewSelf' to return type 'Self'
    func f() -> Self { return NewSelf() }
}
```

If a protocol declaration has `Self` in non-return position or an `associatedtype`, such protocol behaves specially (looks like `some` is Rust's `impl Trait` and `any` is `Box<dyn Trait>`):
```swift
protocol ConstraintOnly {
    func produce() -> Self
    func consume(_ x: Self)
}

// error: use of protocol 'ConstraintOnly' as a type must be written 'any ConstraintOnly'
func testRawIn(x: ConstraintOnly) {}

// error: use of protocol 'ConstraintOnly' as a type must be written 'any ConstraintOnly'
func testRawOut(x: any ConstraintOnly) -> ConstraintOnly {
    return x.produce()
}

func testAnyToAny(x: any ConstraintOnly) -> any ConstraintOnly {
    return x.produce()
}

// error: type 'any ConstraintOnly' cannot conform to 'ConstraintOnly'
// note: required by opaque return type of global function 'testAnyToSome(x:)'
func testAnyToSome(x: any ConstraintOnly) -> some ConstraintOnly {
    return x.produce()
}

func testSomeToAny(x: some ConstraintOnly) -> any ConstraintOnly {
    return x.produce()
}

// error: member 'consume' cannot be used on value of type 'any ConstraintOnly'; consider using a generic constraint instead
func testAnyConsume(x: any ConstraintOnly) {
    x.consume(x.produce())
}

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
class D {
    func id(x: Self) -> Self { return x }
}

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

class I: H {
    // error: covariant 'Self' or 'Self?' can only appear in the top level of method result type
    func f() -> Array<Self> { return Array() }

    // error: method 'f()' in non-final class 'I' must return 'Self' to conform to protocol 'H'
    func f() -> Array<I> { return Array() }

    // error: method 'g(xs:)' in non-final class 'I' must return 'Self' to conform to protocol 'H'
    func g(xs: Array<I>) -> Array<I> { return Array() }
}

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
    override func g(x: CAssoc) {}
    // error: method does not override any method from its superclass
    override func h() -> Array<CAssoc> { return [self, self] }
}

func testAssoc(_ x: some AAssoc, _ y: some AAssoc) {
    x.g(x: x.f())
    // cannot convert value of type '(some AAssoc).S' (associated type of protocol 'AAssoc') to expected argument type '(some AAssoc).S' (associated type of protocol 'AAssoc')
    x.g(x: y.f())
}
```

### Scala

* https://docs.scala-lang.org/tour/abstract-type-members.html
* https://docs.scala-lang.org/tutorials/FAQ/index.html#how-can-a-method-in-a-superclass-return-a-value-of-the-current-type

Compile examples with: `$ scala3 examples.scala`.

Self-types [mean](https://docs.scala-lang.org/tour/self-types.html) something entirely different in Scala 2 (trait mixin requirement).
Also there is `this.type` but it refers to the singleton type of current value.

There is a [proposal](https://github.com/lampepfl/dotty/issues/7374) to introduce `ThisType` in Scala 3, however it is still raw enough.

Also there is a possibility to emulate self-types with an associated type but only for one layer of hierarchy and with some explicit casts:
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
