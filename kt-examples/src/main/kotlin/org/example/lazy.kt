package org.example

abstract class Lazy<T, Self : Lazy<T, Self>>(val computation: () -> T) {
    protected abstract fun create(computation: () -> T): Self
    fun compute(): T = computation()
    fun bind(kleisli: (T) -> Self): Self = create { kleisli(compute()).compute() }
}

class LazyImpl<T>(computation: () -> T) : Lazy<T, LazyImpl<T>>(computation) {
    override fun create(computation: () -> T): LazyImpl<T> = LazyImpl(computation)
}

class LazyCollection<T>(computation: () -> T) :
    Lazy<T, LazyCollection<T>>(computation), PersistentCollection<T, LazyCollection<T>>
        where T : PersistentCollection<T, *> {

    private val computed by lazy { compute() }

    override fun add(value: T): LazyCollection<T> = create {
        @Suppress("UNCHECKED_CAST")
        computed.add(value) as T
    }

    override fun clear(): LazyCollection<T> = create {
        @Suppress("UNCHECKED_CAST")
        computed.clear() as T
    }

    override val size: Int
        get() = compute().size

    override fun isEmpty(): Boolean = computed.isEmpty()

    override fun iterator(): Iterator<T> = computed.iterator()

    override fun containsAll(elements: Collection<T>): Boolean = computed.containsAll(elements)

    override fun contains(element: T): Boolean = computed.contains(element)

    override fun create(computation: () -> T): LazyCollection<T> = LazyCollection(computation)
}

fun main() {
    TODO()
//    LazyCollection<PersistentList<Int, *>> {  }
}
