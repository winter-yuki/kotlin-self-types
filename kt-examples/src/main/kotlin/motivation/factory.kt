package motivation

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
