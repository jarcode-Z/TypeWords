<script setup lang="ts">
import { onMounted } from 'vue'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'
import { useInit } from '@typewords/core/composables/useInit.ts'

const init = useInit()

onMounted(() => {
  init()
  document.documentElement.className = 'dark'
})
</script>

<template>
  <router-view></router-view>
</template>

<style scoped lang="scss"></style>
