package org.example

import motivation.PersistentListImpl
import motivation.addAll
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertIterableEquals
import org.junit.jupiter.api.Test

class PersistentListImplTest {
    @Test
    fun `functionality test`() {
        val xs = PersistentListImpl(1, 2, 3, 4)
        val ys = listOf(1, 2, 3, 4)
        assertIterableEquals(ys, xs)
        assertEquals(ys.size, xs.size)
        assertIterableEquals(ys.subList(1, 3), xs.sublist(1, 3))
        assertIterableEquals(ys + listOf(5, 6, 7), xs.addAll(listOf(5, 6)).addAll(listOf(7)))
    }
}
