#!/usr/bin/env node

// This file is the main entry point for the silabs-dev CLI tool.It dispatches commands to the appropriate modules.
const fs = require('fs')
const os = require('os')
const path = require('path')
const { execFileSync, spawnSync } = require('child_process')
const runtest = require('./runtest')
const renode = require('./renode')
const publish = require('./publish')
const { pathToFileURL } = require('url')

function printRenodeVersion() {
  console.log('🔴  Silabs:', renode.silabsVersion())
  console.log('🟦  Renode:', JSON.stringify(renode.renodeVersion(), null, 2))
  console.log(
    '🔺 Silabs renode semantic version:',
    renode.silabsRenodeVersion(),
  )
}

function runRenodeCli() {
  const renodeScript = path.join(__dirname, '..', '..', 'renode')
  const args = process.argv.slice(3)
  const result = spawnSync(renodeScript, args, {
    stdio: 'inherit',
    env: process.env,
  })
  if (result.error) {
    console.error(result.error.message)
    process.exit(1)
  }
  if (result.signal) {
    process.exit(1)
  }
  process.exit(result.status ?? 1)
}

function osVersion() {
  const kernel = `${os.type()} ${os.release()} ${os.arch()}`
  try {
    const text = fs.readFileSync('/etc/os-release', 'utf8')
    const match = text.match(/^PRETTY_NAME="?([^"\n]+)"?/m)
    if (match) {
      return `${match[1]} (${kernel})`
    }
  } catch {
    // Fall through to kernel-only description on non-Linux hosts.
  }
  return kernel
}

function printVersions() {
  console.log(
    '🦄 Node version: ' +
      execFileSync('node', ['--version'], { encoding: 'utf8' }).trim(),
  )
  console.log(
    '🦂 Dotnet version: ' +
      execFileSync('dotnet', ['--version'], { encoding: 'utf8' }).trim(),
  )
  console.log(
    '🐍 Python version: ' +
      execFileSync('python3', ['--version'], { encoding: 'utf8' }).trim(),
  )
  console.log(
    '🛠️ GCC version: ' +
      execFileSync('gcc', ['--version'], { encoding: 'utf8' })
        .trim()
        .split('\n')[0],
  )
  console.log('🐧 OS version: ' + osVersion())
}

// Define available commands and their corresponding functions.
let commands = {
  run: () => runRenodeCli(),
  runtest: () => runtest.runTest(process.argv[3]),
  fetchlib: () => renode.fetchLibraries(),
  'build-host-library': () => renode.buildHostLibrary(),
  'testing-set-up': () => renode.testingSetUp(),
  build: () => renode.buildRenode(),
  'build-win': () => renode.buildWinRenode(),
  'build-mac': () => renode.buildMacRenode(),
  clean: () => renode.cleanRenode(),
  versions: () => printVersions(),
  dist: () => publish.createDist(),
  'dist-prep': () => publish.prepDist(),
  'dist-zip': () => publish.zipDist(),
  'dist-unzip': () => publish.unzipDist(),
  'upload-dist': (argv) => {
    let branch = argv[0]
    if (!branch) {
      console.error('Usage: ./r upload-dist <branch>')
      process.exit(1)
    }
    let pathToPublish = `/${branch}/latest/`
    publish.uploadDist(pathToPublish)
  },
  'renode-version': () => printRenodeVersion(),
}

let cmd = process.argv[2]
let action = commands[cmd]

if (!action) {
  console.error('Usage: main.js <command> [args]')
  console.error('Available commands:', Object.keys(commands).join(', '))
  process.exit(1)
}

action(process.argv.slice(3))
