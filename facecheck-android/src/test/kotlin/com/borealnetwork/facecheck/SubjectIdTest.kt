package com.borealnetwork.facecheck

import kotlin.test.Test
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class SubjectIdTest {

    @Test
    fun generate_produces_contract_format_and_fresh_randomness() {
        val first = SubjectId.generate("lk_test_example")
        val second = SubjectId.generate("lk_test_example")

        assertTrue(Regex("^sub_[A-Z2-7]{10}_[A-Za-z0-9_-]{22}$").matches(first))
        assertTrue(Regex("^sub_[A-Z2-7]{10}_[A-Za-z0-9_-]{22}$").matches(second))
        assertNotEquals(first, second)
    }

    @Test
    fun validation_matches_the_subject_id_contract() {
        assertTrue(isValidSubjectId("person_demo_01"))
        assertTrue(!isValidSubjectId("bad id"))
    }
}
