package design

interface A {
    fun foo()
}

class B : A {
    override fun foo() {
        print("Hello")
    }
}

fun <T : A> T.extension(): T = this

fun main() {
    B()
        .extension()
        .extension()
        .foo()
}
