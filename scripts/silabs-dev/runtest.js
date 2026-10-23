// This script is used to run test suites defined in tests/silabs_tests.json. It can be invoked with a specific suite name or with the --matrix flag to output a JSON configuration for GitHub Actions matrix strategy.

const fs = require('fs')
const path = require('path')
const os = require('os')
const { execFileSync } = require('child_process')
const renode = require('./renode')

let tests = require('../../tests/silabs_tests.json')

const SILABS_UNIT_TEST_PREFIX = 'unit-test-'

function availableSuiteNames() {
  return Object.keys(tests)
}

/** Leaf JSON keys, or every `unit-test-*` suite when the name is the `silabs` alias. */
function resolveSuiteNames(suiteName) {
  if (suiteName in tests) {
    return [suiteName]
  }
  if (suiteName === 'silabs') {
    return availableSuiteNames().filter((name) =>
      name.startsWith(SILABS_UNIT_TEST_PREFIX),
    )
  }
  return []
}

function printAvailableSuites() {
  console.error(
    'Available suites:',
    [...availableSuiteNames(), 'silabs'].join(', '),
  )
}

/** Prefer the venv from `./r testing-set-up` when it exists. */
function pythonExecutable() {
  let candidate = renode.venvPython()
  return fs.existsSync(candidate) ? candidate : 'python3'
}

/** Put the test venv on PATH so renode-test's python3 sees installed packages. */
function withVenv(env) {
  let binDir = renode.venvBinDir()
  if (!fs.existsSync(binDir)) {
    return env
  }
  return {
    ...env,
    VIRTUAL_ENV: renode.venvDir(),
    PATH: `${binDir}${path.delimiter}${env.PATH || ''}`,
  }
}

/** Quote one argv token for safe copy-paste into a POSIX shell. */
function shellQuote(arg) {
  let s = String(arg)
  if (s === '') {
    return "''"
  }
  if (/^[\w@%+=:,./-]+$/.test(s)) {
    return s
  }
  return `'${s.replace(/'/g, `'\\''`)}'`
}

/** Log the exact program + argv, plus env assignments this script adds for the child. */
function logInvokedCommand(program, argv, envAssignments) {
  let envPrefix = Object.entries(envAssignments)
    .filter(([, v]) => v != null && v !== '')
    .map(([k, v]) => `${k}=${shellQuote(v)}`)
    .join(' ')
  let tokens = [program, ...argv].map(shellQuote).join(' ')
  if (envPrefix) {
    console.log(`  ↳ Command: ${envPrefix} ${tokens}`)
  } else {
    console.log(`  ↳ Command: ${tokens}`)
  }
}

// The main function that runs a test suite based on the provided suite name.
function runTest(suiteName) {
  // You must pass in something.
  if (!suiteName) {
    console.error('Usage: ./r runtest [ --matrix | <suite-name> ]')
    printAvailableSuites()
    process.exit(1)
  }

  // If you pass the argument --matrix, the script will output a JSON configuration for GitHub Actions matrix strategy and exit.
  if (suiteName === '--matrix') {
    let testSuites = Object.keys(tests)
    let matrix = {
      include: testSuites.map((suite) => ({ test: suite })),
    }
    console.log(`matrix-config=${JSON.stringify(matrix)}`)
    process.exit(0)
  }

  let suiteNames = resolveSuiteNames(suiteName)
  if (suiteNames.length === 0) {
    console.error(`Unknown suite: ${suiteName}`)
    printAvailableSuites()
    process.exit(1)
  }

  // Print hardware information once, including when `silabs` expands to several groups.
  let cpus = os.cpus()
  let numCpus = cpus.length
  let cpuModel = numCpus > 0 ? cpus[0].model : 'unknown'
  let cpuSpeedMhz = numCpus > 0 ? cpus[0].speed : 0
  let totalMemMB = Math.round(os.totalmem() / (1024 * 1024))
  let freeMemMB = Math.round(os.freemem() / (1024 * 1024))
  console.log(
    `  ↳ Hardware: ${os.platform()} ${os.arch()}, ${numCpus} CPU(s) @ ${cpuSpeedMhz} MHz`,
  )
  console.log(`  ↳ CPU model: ${cpuModel}`)
  console.log(`  ↳ Memory: ${freeMemMB} MB free / ${totalMemMB} MB total`)
  console.log(`  ↳ Hostname: ${os.hostname()}`)

  for (let name of suiteNames) {
    runSuite(name)
  }
}

function runSuite(suiteName) {
  let suite = tests[suiteName].tests

  console.log(`🎁 Running test suite: ${tests[suiteName].title}`)

  let suiteStart = Date.now()

  for (let entry of suite) {
    let testPath

    if (typeof entry === 'string') {
      testPath = entry
    } else {
      testPath = entry.test
    }

    console.log(`🚀 Running test: ${testPath}`)
    if (typeof entry === 'object' && entry.params) {
      for (let [key, value] of Object.entries(entry.params)) {
        console.log(`    ${key}: ${value}`)
      }
    }

    let isPython = testPath.endsWith('.py')
    let testStart = Date.now()

    try {
      if (isPython) {
        let args = [testPath]
        if (typeof entry === 'object' && entry.params) {
          for (let [key, value] of Object.entries(entry.params)) {
            args.push(`--${key.toLowerCase()}`, value)
          }
        }
        let rootDir = path.join(__dirname, '..', '..')

        let theEnv = { ...process.env, PYRENODE_BUILD_DIR: rootDir }
        if (process.env.RENODE_PORTABLE_LOCATION) {
          let renodeFile = path.join(
            __dirname,
            '..',
            '..',
            process.env.RENODE_PORTABLE_LOCATION,
            'renode',
          )
          theEnv = {
            ...process.env,
            PYRENODE_BIN: renodeFile,
          }
        }
        theEnv = withVenv(theEnv)
        let python = pythonExecutable()
        let pythonEnvLog = process.env.RENODE_PORTABLE_LOCATION
          ? { PYRENODE_BIN: theEnv.PYRENODE_BIN }
          : { PYRENODE_BUILD_DIR: rootDir }
        logInvokedCommand(python, args, pythonEnvLog)
        execFileSync(python, args, {
          stdio: 'inherit',
          env: theEnv,
        })
      } else {
        let testRunner = path.join(__dirname, '..', '..', 'renode-test')

        if (process.env.RENODE_PORTABLE_LOCATION) {
          testRunner = path.join(
            __dirname,
            '..',
            '..',
            process.env.RENODE_PORTABLE_LOCATION,
            'renode-test',
          )
        }

        let args = []
        if (typeof entry === 'object' && entry.params) {
          for (let [key, value] of Object.entries(entry.params)) {
            args.push('--variable', `${key}:${value}`)
          }
        }
        args.push(testPath)
        let robotEnv = withVenv(process.env)
        logInvokedCommand(testRunner, args, {})
        execFileSync(testRunner, args, {
          stdio: 'inherit',
          env: robotEnv,
        })
      }
    } catch (err) {
      let elapsed = Date.now() - testStart
      console.error(`⛔ Test failed: ${testPath} (${elapsed} ms)`)
      process.exit(err.status || 1)
    }
    let elapsed = Date.now() - testStart
    console.log(`✅ Done: ${testPath} (${elapsed} ms)\n`)
  }

  let suiteElapsed = Date.now() - suiteStart
  console.log(
    `🏁 Suite "${tests[suiteName].title}" completed in ${suiteElapsed} ms`,
  )
}

exports.runTest = runTest
