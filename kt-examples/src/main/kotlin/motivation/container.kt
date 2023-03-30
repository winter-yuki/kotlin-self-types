package motivation

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
        .forEach { it.doTheBest() }
}
