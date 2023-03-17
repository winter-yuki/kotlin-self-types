protocol A {
    func f() -> Self
    func g() -> Self
}

class B: A {
    func f() -> Self { print("B.f"); return g() }
    func g() -> Self { print("B.g"); return self }
    // error: cannot convert return expression of type 'C' to return type 'Self'
    // func h(c: C) -> Self { print("B.h"); return c.g() }
}

class C: B {
    override func g() -> Self { print("C"); return f() }
}

func test1(c: C) {
    c.f().g()
}


// error: covariant 'Self' or 'Self?' can only appear as the type of a property, subscript or method result; did you mean 'D'?
// class D {
//     func id(x: Self) -> Self { return x }
// }

protocol E {
    func f(x: Self) -> Self
}

// error: use of protocol 'E' as a type must be written 'any E'
// func test2(x: E) {}

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

    // error: covariant 'Self' or 'Self?' can only appear at the top level of method result type
    // func f() -> Array<Self> { return Array() }

    // error: covariant 'Self' or 'Self?' can only appear at the top level of method result type
    // func g(xs: Array<I>) -> Array<Self> { return Array() }
// }

final class J: H {
    func f() -> Array<J> { return Array() }
    func g(xs: Array<J>) -> Array<J> { return xs }
}


protocol AA {
    associatedtype S
    func f() -> S
    func g(x: S)
    func h() -> Array<S>
}

class BB : AA {
    typealias S = BB
    func f() -> BB { return self }
    func g(x: BB) { x.specific() }
    func h() -> Array<BB> { return [self] }

    func specific() {}
}

class CC : BB {
    override func f() -> CC { return self }
    // error: method does not override any method from its superclass
    // override func g(x: CC) {}
    // error: method does not override any method from its superclass
    // override func h() -> Array<CC> { return [self, self] }
}

class DD : AA {
    typealias S = DD
    func f() -> DD { return self }
    func g(x: DD) {}
    func h() -> Array<DD> { return [self] }
}

// cannot convert value of type '(some AA).S' (associated type of protocol 'AA') to expected argument type '(some AA).S' (associated type of protocol 'AA')
func test2(_ x: some AA, _ y: some AA) {
    x.g(x: x.f())
    // x.g(x: y.f())
}

// func caller() {
//     test(BB(), DD())
// }
