import { expect, test } from 'claude-code/testing'

const WORK = {
  account: 'work', label: 'WORK', emoji: '🔴', email: 'me@acme.com', loggedIn: true,
  configDir: '/home/u/.claude-work', expected: 'work', expectedLabel: 'WORK',
  mismatch: false, error: null, level: 'ok', text: '🔴 WORK · me@acme.com',
}
const MISMATCH = {
  ...WORK, account: 'personal', label: 'PERSONAL', configDir: '/home/u/.claude',
  mismatch: true, level: 'warn', text: '⚠ PERSONAL, but this dir belongs to WORK',
}

// What Claude Code passes a ui.render hook for the band above the prompt
const BAND = {
  plugin: 'account-badge',
  component: 'AbovePrompt',
  surface: 'terminal',
  viewport: { columns: 100, rows: 30 },
  props: { hasSurvey: false, isWorking: false, maxRows: 5, bodyColumns: 100, scroll: { offset: 0, bodyRows: 5 }, view: {} },
} as const

// Stubs every test needs: session start, the /account registration, and other mods' band content
function stubSession(on, resolver) {
  on('session.start', () => ({ cwd: '/work' }))
  on('command.register', () => ({ value: undefined }))
  on('process.run', resolver)
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['drawn by others'] }))
}

const answer = (account) => () => ({ value: { exitCode: 0, stdout: JSON.stringify(account) + '\n', stderr: '' } })

test('the band shows the account', async ($, on) => {
  stubSession(on, answer(WORK))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: '🔴 WORK · me@acme.com' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'drawn by others' })).toBeDefined()
})

test('a mismatch is drawn in yellow', async ($, on) => {
  stubSession(on, answer(MISMATCH))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount(BAND)
  const badge = await ui.find({ type: 'Text', text: '⚠ PERSONAL, but this dir belongs to WORK' })
  expect(badge.props.color).toBe('yellow')
})

test('a failing resolver is shown, never guessed', async ($, on) => {
  stubSession(on, () => ({ value: { exitCode: 1, stdout: '', stderr: 'boom\n' } }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: '⚠ account unknown (resolver exited 1: boom)' })).toBeDefined()
})

test('/account explains a mismatch and how to fix it', async ($, on) => {
  stubSession(on, answer(MISMATCH))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const out = await $.command.run({ command: 'account', args: '' })
  expect(out.text).toContain('⚠ PERSONAL, but this dir belongs to WORK')
  expect(out.text).toContain('Expected: work')
  expect(out.text).toContain('claude-accounts doctor')
})

test('the badge is refreshed after /clear', async ($, on) => {
  stubSession(on, answer(WORK))
  on('classic.SessionStart', () => ({}))
  await $.classic.SessionStart({ source: 'clear' })
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: '🔴 WORK · me@acme.com' })).toBeDefined()
})
