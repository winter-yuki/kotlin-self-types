@file:Suppress("SameParameterValue")

package org.example

import kotlin.properties.ObservableProperty
import kotlin.reflect.KProperty

abstract class AbstractObservable<Self : AbstractObservable<Self>> {
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

class Element : AbstractObservable<Element>() {
    var color: Color by observable(Color.Purple)
}

fun main() {
    val element = Element().apply {
        observe { // Convenient to have `it: Element` here
            println("New color = ${it.color}")
        }
    }
    element.color = Color.Blue // Observer prints new color here
}
