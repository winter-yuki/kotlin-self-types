protocol AOut {
    func f() -> Self
    func g() -> Self
}

class BOut: AOut {
    func f() -> Self { print("BOut.f"); return g() }
    func g() -> Self { print("BOut.g"); return self }
    // error: cannot convert return expression of type 'C' to return type 'Self'
    // func h(_ c: COut) -> Self { print("BOut.h"); return c.g() }
}

class COut: BOut {
    override func g() -> Self { print("COut"); return f() }
}

func testOut(c: COut) -> COut {
    return c.f().g()
}


// final class NewSelf {
//     // error: cannot convert return expression of type 'NewSelf' to return type 'Self'
//     func f() -> Self { return NewSelf() }
// }


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

// error: member 'g' cannot be used on value of type 'any AAssoc'; consider using a generic constraint instead
// func testAssocAny(_ x: any AAssoc, _ y: any AAssoc) {
//     x.g(x: x.f())
// }

func testSomeConsumeKek(x: some ConstraintOnly, y: some ConstraintOnly) {
    x.consume(y.produce())
}
