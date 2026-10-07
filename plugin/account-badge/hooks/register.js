// account-badge: show the Claude Code account this session uses above the prompt, and add /account.
// scripts/resolve decides everything; this module only shows its answer.

let account = null

function failure(reason) {
  return { text: '⚠ account unknown (' + reason + ')', level: 'warn', error: reason }
}

// Run the resolver in the session's directory and redraw the band
async function refresh($) {
  try {
    const { exitCode, stdout, stderr } = await $.process.run([$.plugin.root + '/scripts/resolve'])
    account = exitCode === 0 ? JSON.parse(stdout) : failure('resolver exited ' + exitCode + ': ' + stderr.trim())
  } catch (err) {
    account = failure(err && err.message ? err.message : String(err))
  }
  $.ui.invalidate('ui.render')
}

function describe(a) {
  const lines = [a.text]
  if (a.error) {
    lines.push('Error: ' + a.error)
    return lines.join('\n')
  }
  lines.push('Account:  ' + (a.account ?? 'not in the claude-accounts config') + ' (' + a.configDir + ')')
  lines.push('Expected: ' + (a.expected ?? '-') + ' for this directory')
  if (a.mismatch) lines.push('Fix: run `claude-accounts doctor` in this directory')
  else if (!a.loggedIn) lines.push('Fix: run `claude-accounts login ' + (a.account ?? '<name>') + '`')
  return lines.join('\n')
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'account', description: 'Show which Claude account this session uses' })
    await refresh($)
    return next(e)
  })

  // /clear, /resume and /branch don't fire session.start again
  on('classic.SessionStart', { source: ['clear', 'resume', 'fork'] }, async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const { Box, Text } = $.ui.resolve(e)
    const theirs = await next(e)
    const shown = account ?? { text: '… checking account', level: 'ok' }
    const style = shown.level === 'warn' ? { bold: true, color: 'yellow' } : { bold: true }
    return Box({ flexDirection: 'column', children: [Text({ ...style, children: [shown.text] }), theirs] })
  })

  on('command.run', { command: 'account' }, async ($) => {
    await refresh($)
    return { text: describe(account) }
  })
}
