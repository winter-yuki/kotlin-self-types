package org.example

interface PersistentCollection<out E, out Self : PersistentCollection<E, Self>> : Collection<E> {
    fun add(value: @UnsafeVariance E): Self
    fun clear(): Self
}

fun <E, C : PersistentCollection<E, C>> C.addAll(xs: Iterable<E>): C =
    xs.fold(this) { acc, x -> acc.add(x) }

interface PersistentList<out E, out Self : PersistentList<E, Self>> : PersistentCollection<E, Self> {
    fun sublist(fromIndex: Int, toIndex: Int): Self
}

@JvmInline
value class PersistentListImpl<out E> private constructor(private val head: Node<E>) :
    PersistentList<E, PersistentListImpl<E>> {

    private sealed interface Node<out E> {
        fun wrap() = PersistentListImpl(this)
    }

    private object Nil : Node<Nothing>
    private data class Cons<out E>(val value: E, val tail: PersistentListImpl<E>) : Node<E>

    override val size: Int
        get() = when (head) {
            Nil -> 0
            is Cons -> 1 + head.tail.size
        }

    override fun contains(element: @UnsafeVariance E): Boolean =
        when (head) {
            Nil -> false
            is Cons -> head.value == element || head.tail.contains(element)
        }

    override fun containsAll(elements: Collection<@UnsafeVariance E>): Boolean =
        elements.all { contains(it) }

    override fun isEmpty(): Boolean =
        when (head) {
            Nil -> true
            is Cons -> false
        }

    override fun iterator(): Iterator<E> = toList().iterator()

    private fun toList(): List<E> = buildList {
        var head = this@PersistentListImpl.head
        while (head is Cons) {
            add(head.value)
            head = head.tail.head
        }
    }.reversed()

    override fun add(value: @UnsafeVariance E): PersistentListImpl<E> =
        Cons(value, head.wrap()).wrap()

    override fun clear(): PersistentListImpl<E> = Nil.wrap()

    override fun sublist(fromIndex: Int, toIndex: Int): PersistentListImpl<E> {
        require(fromIndex >= 0)
        require(toIndex > fromIndex)
        return sublistHelper(fromIndex, toIndex)
    }

    private fun sublistHelper(fromIndex: Int, toIndex: Int): PersistentListImpl<E> =
        when (head) {
            Nil -> this
            is Cons -> if (fromIndex > 0) {
                head.tail.sublistHelper(fromIndex - 1, toIndex - 1)
            } else {
                if (toIndex == 0) Nil.wrap() else {
                    Cons(head.value, head.tail.sublistHelper(fromIndex, toIndex - 1)).wrap()
                }
            }
        }

    companion object {
        val empty: PersistentListImpl<Nothing> = PersistentListImpl(Nil)
        operator fun <E> invoke(vararg xs: E): PersistentListImpl<E> =
            xs.fold<E, PersistentListImpl<E>>(empty) { acc, x -> Cons(x, acc).wrap() }
    }
}
