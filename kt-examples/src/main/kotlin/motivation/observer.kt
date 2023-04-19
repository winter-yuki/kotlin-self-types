package motivation

import kotlin.properties.ObservableProperty
import kotlin.reflect.KProperty

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

fun observer(entity: Entity) {
    println("New color = ${entity.color}")
}

fun main() {
    val entity = Entity().apply {
        observe(::observer)
    }
    entity.color = Color.Blue // Observer prints new color here
}
