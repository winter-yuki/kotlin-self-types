package org.example

abstract class Lazy<out T, out Self : Lazy<T, Self>>(val computation: () -> T) {
    protected val computed by lazy { computation() }

    protected abstract fun create(computation: () -> @UnsafeVariance T): Self
    fun compute(): T = computed
    fun then(f: (T) -> @UnsafeVariance T): Self = create { f(compute()) }
}

class LazyImpl<out T>(computation: () -> T) : Lazy<T, LazyImpl<T>>(computation) {
    override fun create(computation: () -> @UnsafeVariance T): LazyImpl<T> = LazyImpl(computation)
}

class LazyCollection<out T, out C : PersistentCollection<T, C>>(computation: () -> C) :
    Lazy<C, LazyCollection<T, C>>(computation), PersistentCollection<T, LazyCollection<T, C>> {

    override fun add(value: @UnsafeVariance T): LazyCollection<T, C> = create { computed.add(value) }

    override fun clear(): LazyCollection<T, C> = create { computed.clear() }

    override val size: Int
        get() = compute().size

    override fun isEmpty(): Boolean = computed.isEmpty()

    override fun iterator(): Iterator<T> = computed.iterator()

    override fun containsAll(elements: Collection<@UnsafeVariance T>): Boolean = computed.containsAll(elements)

    override fun contains(element: @UnsafeVariance T): Boolean = computed.contains(element)

    override fun create(computation: () -> @UnsafeVariance C): LazyCollection<T, C> = LazyCollection(computation)
}

fun main() {
    val xs = LazyCollection { PersistentListImpl(1, 2, 3) }
        .clear()
        .add(1).addAll(listOf(2, 3)).add(4)
        .then { xs -> xs.forEach { x -> println(x) }; xs }
    println("Hello world")
    xs.compute()
}
