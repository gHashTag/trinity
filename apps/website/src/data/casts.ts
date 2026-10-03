// Recorded terminal sessions published under public/term/<id>/ with `tri cast publish`.
// Pages and posts that replay one take its text from here, so a caption is written once.

export interface Cast {
  src: string
  share: string
  title: string
  caption: { en: string; ru: string }
}

export const X7_BOARD: Cast = {
  src: 'term/x7-board/session.cast',
  share: 'https://t27.ai/term/x7-board/',
  title: 'tri x7-board · t27 back half on the AX7203',
  caption: {
    en: 'One recorded session on the AX7203, 2026-10-02: a bitstream built from t27 specs is compared byte for byte with openXC7\'s, loaded into SRAM, and checked with 51,840 of 51,840 tagged receipts from the board. Every byte printed is real; the prompt and the typing are staged, and silences over 2 s are shortened.',
    ru: 'Одна записанная сессия на AX7203, 2026-10-02: битстрим, собранный из t27-спеков, сравнивается байт в байт с битстримом openXC7, загружается в SRAM и проверяется 51 840 из 51 840 тегированных квитанций с платы. Каждый напечатанный байт настоящий; приглашение и набор команд постановочные, паузы длиннее 2 с сокращены. Сама запись на английском.',
  },
}

export const DEVKIT_FLOW: Cast = {
  src: 'term/devkit-flow/session.cast',
  share: 'https://t27.ai/term/devkit-flow/',
  title: 'tri devkit · the FPGA flow, layer by layer',
  caption: {
    en: 'The recorded run: `tri devkit flow --build` and `tri devkit impact` on one XC7A200T design, 2026-10-03. Every byte printed is real and arrives when it did; the prompt and the typing are staged, and silences over 2 s are shortened, with a note in the title bar while that happens.',
    ru: 'Записанный прогон: `tri devkit flow --build` и `tri devkit impact` на одном дизайне XC7A200T, 2026-10-03. Каждый напечатанный байт настоящий и появляется тогда, когда появился; приглашение и набор команд постановочные, паузы длиннее 2 с сокращены, и пока это происходит, в заголовке окна стоит пометка. Сама запись на английском.',
  },
}
