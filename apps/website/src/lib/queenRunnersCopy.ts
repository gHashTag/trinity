// MY RUNNERS, in words: what a runner is and how far it goes today. The cabinet
// (components/QueenRunners.tsx) draws it, and the homepage's GET STARTED quotes
// its lead and its next stage rather than describing runners a second time, so
// the day taking tasks ships, one edit here moves both.
export interface RunnersCopy {
  title: string
  lead: string
  keyStays: string
  signin: string
  elsewhere: string
  unavailable: string
  /** The Queen answered, and the cabinet is not on her yet (a 404 on its path). */
  pending: string
  loading: string
  none: string
  namePlaceholder: string
  create: string
  revoke: string
  revokeConfirm: (label: string) => string
  lane: string
  state: Record<'never-seen' | 'online' | 'offline', string>
  limit: (n: number) => string
  refusedLabel: string
  mintedTitle: string
  mintedOnce: string
  copy: string
  copied: string
  done: string
  nextStage: string
}

export const RUNNERS_COPY: Record<'en' | 'ru', RunnersCopy> = {
  en: {
    title: 'MY RUNNERS',
    lead: 'A runner is a lane that runs on your own machine, under your own provider account. The Queen hands it a task; the work comes back; the XP lands here, on your name.',
    keyStays: 'Your provider key never leaves your machine. This page has no field for it and the Queen never sees it — the token below only lets a process speak as your runner.',
    signin: 'Sign in to app.t27.ai to manage your runners.',
    elsewhere: 'Runners are managed on the app’s board, where your session lives:',
    unavailable: 'The Queen did not answer. Try again in a minute.',
    pending: 'Runners are on their way: the Queen does not offer them yet. This panel switches on by itself the day she does.',
    loading: 'Reading your runners…',
    none: 'No runners yet.',
    namePlaceholder: 'Name, e.g. my laptop',
    create: 'Create runner',
    revoke: 'Revoke',
    revokeConfirm: (label) => `Revoke “${label}”? A process using its token stops at once.`,
    lane: 'lane',
    state: { 'never-seen': 'never connected', online: 'online', offline: 'offline' },
    limit: (n) => `Up to ${n} runners.`,
    refusedLabel: 'Give the runner a name.',
    mintedTitle: 'Runner token',
    mintedOnce: 'Shown once. Copy it now — afterwards only its last four characters are kept.',
    copy: 'Copy',
    copied: 'Copied',
    done: 'I saved it',
    nextStage: 'Today a runner can connect and show up online. Taking tasks and handing work back is the next stage of the Queen; until it ships there is nothing to take.',
  },
  ru: {
    title: 'МОИ РАННЕРЫ',
    lead: 'Раннер — это полоса, которая работает на вашей машине, под вашим аккаунтом провайдера. Королева даёт ему задачу, работа возвращается, а XP начисляется здесь, на ваше имя.',
    keyStays: 'Ваш ключ провайдера не покидает вашу машину. На этой странице нет поля для него, и Королева его не видит — токен ниже лишь позволяет процессу говорить от имени вашего раннера.',
    signin: 'Войдите в app.t27.ai, чтобы управлять раннерами.',
    elsewhere: 'Раннеры управляются на доске приложения, где живёт ваша сессия:',
    unavailable: 'Королева не ответила. Попробуйте через минуту.',
    pending: 'Раннеры скоро появятся: Королева их пока не выдаёт. Панель включится сама, как только это изменится.',
    loading: 'Читаю ваших раннеров…',
    none: 'Раннеров пока нет.',
    namePlaceholder: 'Имя, например «мой ноутбук»',
    create: 'Создать раннер',
    revoke: 'Отозвать',
    revokeConfirm: (label) => `Отозвать «${label}»? Процесс с его токеном сразу перестанет работать.`,
    lane: 'полоса',
    state: { 'never-seen': 'ещё не подключался', online: 'на связи', offline: 'не на связи' },
    limit: (n) => `Не больше ${n} раннеров.`,
    refusedLabel: 'Дайте раннеру имя.',
    mintedTitle: 'Токен раннера',
    mintedOnce: 'Показывается один раз. Скопируйте сейчас — потом хранятся только его последние четыре символа.',
    copy: 'Скопировать',
    copied: 'Скопировано',
    done: 'Сохранено',
    nextStage: 'Сейчас раннер может подключиться и отображаться «на связи». Выдача задач и приём работы — следующий этап Королевы; пока его нет, брать нечего.',
  },
}
