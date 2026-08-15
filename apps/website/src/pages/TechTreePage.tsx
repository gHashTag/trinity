"use client";

import { useI18n } from '../i18n/context'
import TechTree from '../components/TechTree/TechTree'

export default function TechTreePage() {
  const { lang } = useI18n()

  // Пересоздаём дерево при смене языка: дочерние карточки и панель
  // подробностей получают новый словарь без изменения порядка узлов.
  return <TechTree key={lang} />
}
